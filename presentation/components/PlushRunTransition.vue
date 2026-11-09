<!-- Slide transitions starring the Godot plush. Enable one on the slide you
     leave (Slidev reads the transition from there):
       transition: plush-run | slide-right    runs across, uncovering the next slide
       transition: plush-pill | slide-right   same, but stops mid-way to swallow a MEDS pill -->
<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useNav } from '@slidev/client'
import * as THREE from 'three'
import { addPlushLights, createPlush, PLUSH_BLUE, plushMaterial, type PlushInstance } from '../composables/plush'

type Variant = 'plush-run' | 'plush-pill'

const RUN_DURATION = 1300
// plush-pill: run to the centre, stop to swallow the pill, run off.
const PILL_RUN_IN = 700
const PILL_STOP = 1700
const PILL_RUN_OUT = 650
const DURATIONS: Record<Variant, number> = {
  'plush-run': RUN_DURATION,
  'plush-pill': PILL_RUN_IN + PILL_STOP + PILL_RUN_OUT,
}
// The runner (and the wipe edge it carries) starts and ends this far outside
// the slide, as a fraction of its width, so it enters and leaves fully.
const OVERSHOOT = 0.08
// Facing right but turned slightly towards the audience, or facing them.
const RUN_ANGLE = Math.PI / 2 - 0.35
const FRONT_ANGLE = 0.15

const { currentSlideNo, currentTransition, isPrintMode } = useNav()
const layer = ref<HTMLDivElement>()
const container = ref<HTMLDivElement>()
const shadow = ref<HTMLDivElement>()
const running = ref(false)
const reducedMotion = typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches

let renderer: THREE.WebGLRenderer | null = null
let plush: PlushInstance | null = null
let mixer: THREE.AnimationMixer | null = null
let runAction: THREE.AnimationAction | null = null
let idleAction: THREE.AnimationAction | null = null
let pill: THREE.Group | null = null
let variant: Variant = 'plush-run'
let stopped = false
let modelSize = new THREE.Vector3(1, 1, 1)
let mouth = new THREE.Vector3()
let baseScale = 1
let frame = 0
let startedAt = 0
let lastTime = 0
let lastSize = ''
let target: HTMLElement | null = null
let outgoing: HTMLElement | null = null
let targetNo = 0
const scene = new THREE.Scene()
const camera = new THREE.OrthographicCamera(0, 1, 1, 0, -100, 100)

const clamp01 = (v: number) => Math.min(Math.max(v, 0), 1)
const lerp = THREE.MathUtils.lerp
const smooth = (v: number) => v * v * (3 - 2 * v)
// 0→1 over [start, start + length] of `t`.
const phase = (t: number, start: number, length: number) => clamp01((t - start) / length)

function layout() {
  const el = container.value
  if (!el || !renderer || !plush)
    return { w: 0, h: 0 }
  const w = el.clientWidth
  const h = el.clientHeight
  // The slide is CSS-scaled to fit the screen; render at the on-screen resolution.
  const ratio = Math.min(devicePixelRatio * el.getBoundingClientRect().width / (w || 1), 3)
  const size = `${w}x${h}@${ratio}`
  if (size !== lastSize) {
    lastSize = size
    renderer.setPixelRatio(ratio)
    renderer.setSize(w, h, false)
    camera.right = w
    camera.top = h
    camera.updateProjectionMatrix()
    baseScale = (h * 0.4) / modelSize.y
  }
  return { w, h }
}

// The incoming slide, in the same slideshow as this layer (the presenter view has its own).
function findTarget() {
  return layer.value?.parentElement?.querySelector<HTMLElement>(`#slideshow > .slidev-page-${targetNo}`) ?? null
}

// The wipe is driven from here, not by a CSS transition, so it can't drift
// from the runner, and Vue re-running the slide's enter transition can't reset it.
function clip(progress: number) {
  target ??= findTarget()
  if (!target)
    return
  const right = (1 + OVERSHOOT - progress * (1 + 2 * OVERSHOOT)) * 100
  target.style.clipPath = `inset(0 ${right}% 0 0)`
  target.style.zIndex = '1'
}

function release() {
  if (target) {
    target.style.clipPath = ''
    target.style.zIndex = ''
  }
  if (outgoing)
    outgoing.style.opacity = ''
  target = null
  outgoing = null
}

// plush-pill: the outgoing slide fades out as the plush runs in, so the swallow
// plays on a clean background instead of over its text.
function fadeOutgoing(t: number) {
  if (variant !== 'plush-pill')
    return
  outgoing ??= layer.value?.parentElement?.querySelector<HTMLElement>('#slideshow > .plush-pill-leave-active') ?? null
  if (outgoing)
    outgoing.style.opacity = `${1 - smooth(phase(t, 150, 450))}`
}

function setStopped(value: boolean) {
  if (stopped === value || !runAction || !idleAction)
    return
  stopped = value
  const [from, to] = value ? [runAction, idleAction] : [idleAction, runAction]
  to.reset().play()
  from.crossFadeTo(to, 0.2, false)
}

interface Pose {
  progress: number
  angle: number
  hop: number
  squash: number
}

// The swallow, `t` ms into the stop: the pill pops up above the head, drops
// into the mouth, the plush gulps (squash and stretch) and hops with joy.
function pillPose(t: number): Pose {
  const turn = smooth(phase(t, 0, 250)) * (1 - smooth(phase(t, PILL_STOP - 300, 300)))
  const gulp = phase(t, 1000, 350)
  const hop = phase(t, 1250, 350)

  if (pill) {
    const pop = phase(t, 150, 200)
    const fall = phase(t, 450, 450)
    const swallow = phase(t, 850, 150)
    pill.visible = pop > 0 && swallow < 1
    const above = new THREE.Vector3(mouth.x, modelSize.y * 1.2, mouth.z + modelSize.z * 0.25)
    pill.position.lerpVectors(above, mouth, fall * fall)
    pill.position.y += Math.sin(Math.PI * fall) * modelSize.y * 0.12
    // Overshooting pop-in, then shrinks as it goes in.
    const popScale = pop < 1 ? Math.sin(pop * Math.PI * 0.75) / Math.sin(Math.PI * 0.75) : 1
    pill.scale.setScalar(Math.max(popScale * (1 - swallow), 0.0001))
    pill.rotation.z = Math.PI / 2 + fall * Math.PI * 1.5
  }

  return {
    progress: 0.5,
    angle: lerp(RUN_ANGLE, FRONT_ANGLE, turn),
    hop: Math.sin(Math.PI * hop),
    squash: Math.sin(gulp * Math.PI * 2) * (1 - gulp) * 0.18,
  }
}

function poseAt(t: number): Pose {
  const still = { angle: RUN_ANGLE, hop: 0, squash: 0 }
  if (variant === 'plush-run')
    return { ...still, progress: clamp01(t / RUN_DURATION) }
  if (t < PILL_RUN_IN) {
    const k = t / PILL_RUN_IN
    return { ...still, progress: 0.5 * (1 - (1 - k) ** 2) }
  }
  if (t < PILL_RUN_IN + PILL_STOP) {
    setStopped(t < PILL_RUN_IN + PILL_STOP - 250)
    return pillPose(t - PILL_RUN_IN)
  }
  setStopped(false)
  const k = clamp01((t - PILL_RUN_IN - PILL_STOP) / PILL_RUN_OUT)
  return { ...still, progress: 0.5 + 0.5 * k * k }
}

function draw(pose: Pose, now: number) {
  if (!renderer || !plush)
    return
  const { w, h } = layout()
  const x = (-OVERSHOOT + pose.progress * (1 + 2 * OVERSHOOT)) * w
  const model = plush.model
  model.position.set(x, h * 0.1 + pose.hop * h * 0.06, 0)
  model.rotation.y = pose.angle
  const stretch = 1 + pose.squash
  model.scale.set(baseScale / Math.sqrt(stretch), baseScale * stretch, baseScale / Math.sqrt(stretch))
  if (shadow.value) {
    shadow.value.style.transform = `translateX(${x}px) scale(${1 - pose.hop * 0.3})`
    shadow.value.style.opacity = `${1 - pose.hop * 0.4}`
  }
  mixer?.update((now - lastTime) / 1000)
  lastTime = now
  renderer.render(scene, camera)
}

function tick(now: number) {
  const t = now - startedAt
  const pose = poseAt(t)
  clip(pose.progress)
  fadeOutgoing(t)
  draw(pose, now)
  if (t < DURATIONS[variant]) {
    frame = requestAnimationFrame(tick)
    return
  }
  finish()
}

function finish() {
  cancelAnimationFrame(frame)
  frame = 0
  release()
  if (pill)
    pill.visible = false
  running.value = false
}

function run(name: Variant) {
  if (!renderer || !plush || reducedMotion)
    return
  finish()
  variant = name
  targetNo = currentSlideNo.value
  stopped = false
  idleAction?.stop()
  runAction?.reset().setEffectiveWeight(1).play()
  running.value = true
  startedAt = lastTime = performance.now()
  // Hide the incoming slide right away, before the browser paints it.
  clip(0)
  frame = requestAnimationFrame(tick)
}

// The MEDS logo pill, in the plush's blue and material: capsule with a white band.
function createPill(size: THREE.Vector3) {
  const radius = size.y * 0.075
  const length = size.y * 0.17
  const group = new THREE.Group()
  const body = new THREE.Mesh(
    new THREE.CapsuleGeometry(radius, length, 8, 24),
    plushMaterial({ color: PLUSH_BLUE }),
  )
  const band = new THREE.Mesh(
    new THREE.CylinderGeometry(radius * 1.03, radius * 1.03, radius * 0.22, 24),
    plushMaterial({ color: 0xFFFFFF }),
  )
  group.add(body, band)
  group.visible = false
  return group
}

onMounted(async () => {
  for (const [name, ms] of Object.entries(DURATIONS))
    document.documentElement.style.setProperty(`--${name}-duration`, `${ms}ms`)
  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
  renderer.outputColorSpace = THREE.SRGBColorSpace
  container.value!.appendChild(renderer.domElement)
  addPlushLights(scene)
  camera.position.z = 50

  const instance = await createPlush()
  if (!renderer) {
    instance.dispose()
    return
  }
  plush = instance
  const model = instance.model
  const box = new THREE.Box3().setFromObject(model)
  modelSize = box.getSize(new THREE.Vector3())
  // Mouth: the line across the lower half of the face, on its front.
  mouth = new THREE.Vector3((box.min.x + box.max.x) / 2, box.min.y + modelSize.y * 0.5, box.max.z)
  model.rotation.y = RUN_ANGLE
  scene.add(model)

  // Child of the model, so it follows the plush and the mouth position is in model space.
  pill = createPill(modelSize)
  model.add(pill)

  mixer = new THREE.AnimationMixer(model)
  const clip = (name: string) => THREE.AnimationClip.findByName(instance.animations, name)
  runAction = mixer.clipAction(clip('run'))
  idleAction = mixer.clipAction(clip('idle'))
  runAction.play()
  // Compile shaders now rather than on the first frame of the first run.
  pill.visible = true
  renderer.compile(scene, camera)
  pill.visible = false
})

// Post-flush: the new slide is in the DOM and `currentTransition` reflects the move.
watch(currentSlideNo, () => {
  const name = currentTransition.value?.name
  if (!isPrintMode.value && (name === 'plush-run' || name === 'plush-pill'))
    run(name)
  else if (running.value)
    finish()
}, { flush: 'post' })

onBeforeUnmount(() => {
  finish()
  mixer?.stopAllAction()
  pill?.traverse((o) => {
    const mesh = o as THREE.Mesh
    if (mesh.isMesh) {
      mesh.geometry.dispose()
      ;(mesh.material as THREE.Material).dispose()
    }
  })
  plush?.dispose()
  renderer?.dispose()
  renderer = null
})
</script>

<template>
  <div v-show="running" ref="layer" class="plush-run-layer" aria-hidden="true">
    <div ref="shadow" class="plush-run-shadow" />
    <div ref="container" class="plush-run-canvas" />
  </div>
</template>

<style scoped>
.plush-run-layer {
  position: absolute;
  inset: 0;
  z-index: 50;
  pointer-events: none;
  overflow: hidden;
}
.plush-run-canvas,
.plush-run-canvas :deep(canvas) {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}
.plush-run-shadow {
  position: absolute;
  left: -4.5rem;
  bottom: 8.5%;
  width: 9rem;
  height: 1.6rem;
  border-radius: 50%;
  background: radial-gradient(closest-side, rgba(0, 0, 0, 0.4), transparent);
}
</style>

<style>
/* Keeps the outgoing slide in place underneath while the plush uncovers the new one. */
.plush-run-leave-active {
  transition: visibility 0s linear var(--plush-run-duration, 1.3s);
}
.plush-pill-leave-active {
  transition: visibility 0s linear var(--plush-pill-duration, 3.05s);
}
.plush-run-leave-to,
.plush-pill-leave-to {
  visibility: hidden;
}
@media (prefers-reduced-motion: reduce) {
  .plush-run-leave-active,
  .plush-pill-leave-active {
    transition: none;
  }
}
</style>

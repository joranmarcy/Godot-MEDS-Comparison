<!-- `plush-run` slide transition: the Godot plush runs across the slide and
     uncovers the incoming slide behind it.
     Enable it on the slide you leave (Slidev reads the transition from there):
       transition: plush-run | slide-right -->
<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useNav } from '@slidev/client'
import * as THREE from 'three'
import { addPlushLights, createPlush, type PlushInstance } from '../composables/plush'

const PLUSH_RUN_NAME = 'plush-run'
const DURATION = 1300
// The runner (and the wipe edge it carries) starts and ends this far outside
// the slide, as a fraction of its width, so it enters and leaves fully.
const OVERSHOOT = 0.08

const { currentSlideNo, currentTransition, isPrintMode } = useNav()
const layer = ref<HTMLDivElement>()
const container = ref<HTMLDivElement>()
const shadow = ref<HTMLDivElement>()
const running = ref(false)
const reducedMotion = typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches

let renderer: THREE.WebGLRenderer | null = null
let plush: PlushInstance | null = null
let mixer: THREE.AnimationMixer | null = null
let modelHeight = 1
let frame = 0
let startedAt = 0
let lastTime = 0
let lastSize = ''
let target: HTMLElement | null = null
let targetNo = 0
const scene = new THREE.Scene()
const camera = new THREE.OrthographicCamera(0, 1, 1, 0, -100, 100)

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
    plush.model.scale.setScalar((h * 0.4) / modelHeight)
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
  target = null
}

function draw(progress: number, now: number) {
  if (!renderer || !plush)
    return
  const { w, h } = layout()
  const x = (-OVERSHOOT + progress * (1 + 2 * OVERSHOOT)) * w
  plush.model.position.set(x, h * 0.1, 0)
  if (shadow.value)
    shadow.value.style.transform = `translateX(${x}px)`
  mixer?.update((now - lastTime) / 1000)
  lastTime = now
  renderer.render(scene, camera)
}

function tick(now: number) {
  const progress = Math.min((now - startedAt) / DURATION, 1)
  clip(progress)
  draw(progress, now)
  if (progress < 1) {
    frame = requestAnimationFrame(tick)
    return
  }
  frame = 0
  release()
  running.value = false
}

function run() {
  if (!renderer || !plush || reducedMotion)
    return
  cancelAnimationFrame(frame)
  release()
  targetNo = currentSlideNo.value
  running.value = true
  startedAt = lastTime = performance.now()
  // Hide the incoming slide right away, before the browser paints it.
  clip(0)
  frame = requestAnimationFrame(tick)
}

onMounted(async () => {
  document.documentElement.style.setProperty('--plush-run-duration', `${DURATION}ms`)
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
  // Face right, turned slightly towards the audience.
  instance.model.rotation.y = Math.PI / 2 - 0.35
  scene.add(instance.model)
  modelHeight = new THREE.Box3().setFromObject(instance.model).getSize(new THREE.Vector3()).y || 1

  mixer = new THREE.AnimationMixer(instance.model)
  mixer.clipAction(THREE.AnimationClip.findByName(instance.animations, 'run')).play()
  // Compile shaders now rather than on the first frame of the first run.
  renderer.compile(scene, camera)
})

// Post-flush: the new slide is in the DOM and `currentTransition` reflects the move.
watch(currentSlideNo, () => {
  if (!isPrintMode.value && currentTransition.value?.name === PLUSH_RUN_NAME) {
    run()
  }
  else if (running.value) {
    // Navigated again mid-run: stop cleanly.
    cancelAnimationFrame(frame)
    frame = 0
    release()
    running.value = false
  }
}, { flush: 'post' })

onBeforeUnmount(() => {
  cancelAnimationFrame(frame)
  release()
  mixer?.stopAllAction()
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
/* Keeps the outgoing slide in place underneath while the runner uncovers the new one. */
.plush-run-leave-active {
  transition: visibility 0s linear var(--plush-run-duration, 1.3s);
}
.plush-run-leave-to {
  visibility: hidden;
}
@media (prefers-reduced-motion: reduce) {
  .plush-run-leave-active {
    transition: none;
  }
}
</style>

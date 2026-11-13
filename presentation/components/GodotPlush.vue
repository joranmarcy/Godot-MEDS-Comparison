<!-- Godot plush character by Tibo (MIT): https://github.com/gtibo/Godot-Plush-Character -->
<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useIsSlideActive } from '@slidev/client'
import * as THREE from 'three'
import { addPlushLights, blinkOffset, createPlush, type PlushInstance } from '../composables/plush'

const props = withDefaults(defineProps<{
  // wave: idle, waving every few seconds. jump: hops for joy.
  mood?: 'wave' | 'jump'
}>(), { mood: 'wave' })

const container = ref<HTMLDivElement>()
const active = useIsSlideActive()
const reducedMotion = typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches

let renderer: THREE.WebGLRenderer | null = null
let plush: PlushInstance | null = null
let mixer: THREE.AnimationMixer | null = null
let idle: THREE.AnimationAction | null = null
let wave: THREE.AnimationAction | null = null
let up: THREE.AnimationAction | null = null
let fall: THREE.AnimationAction | null = null
let pose: THREE.AnimationAction | null = null
let hopHeight = 0
let baseY = 0
const baseScale = new THREE.Vector3(1, 1, 1)
let frame = 0
let resizeObserver: ResizeObserver | null = null
let waveTimer: ReturnType<typeof setTimeout> | undefined
const scene = new THREE.Scene()
const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 50)
const timer = new THREE.Timer()

// Jump mood: a few quick hops, then a short breather.
const HOP_AIR = 0.5
const HOP_GROUND = 0.18
const HOPS = 3
const HOP_REST = 0.9
const HOP_CYCLE = HOPS * (HOP_AIR + HOP_GROUND) + HOP_REST

function setPose(next: THREE.AnimationAction | null) {
  if (!next || next === pose)
    return
  next.reset().fadeIn(0.08).play()
  pose?.fadeOut(0.08)
  pose = next
}

function updateHop(time: number) {
  if (!plush)
    return
  const model = plush.model
  const t = time % HOP_CYCLE
  const hop = Math.floor(t / (HOP_AIR + HOP_GROUND))
  const local = t - hop * (HOP_AIR + HOP_GROUND)
  let y = 0
  let squash = 0
  if (hop < HOPS && local < HOP_AIR) {
    const p = local / HOP_AIR
    y = 4 * p * (1 - p) * hopHeight
    setPose(p < 0.5 ? up : fall)
  }
  else {
    if (hop < HOPS)
      squash = Math.sin(Math.PI * (local - HOP_AIR) / HOP_GROUND)
    setPose(idle)
  }
  model.position.y = baseY + y
  model.scale.copy(baseScale).multiply(new THREE.Vector3(1 + 0.08 * squash, 1 - 0.12 * squash, 1 + 0.08 * squash))
  // A little wiggle while airborne.
  model.rotation.z = Math.sin(Math.PI * 2 * y / (hopHeight || 1)) * 0.08 * (hop % 2 ? 1 : -1)
}

function render(timestamp?: number) {
  if (!renderer)
    return
  timer.update(timestamp)
  mixer?.update(timer.getDelta())
  if (props.mood === 'jump' && !reducedMotion)
    updateHop(timer.getElapsed())
  if (plush)
    plush.eyeTexture.offset.x = blinkOffset(timer.getElapsed())
  renderer.render(scene, camera)
}

function loop(timestamp: number) {
  resize()
  render(timestamp)
  frame = requestAnimationFrame(loop)
}

function start() {
  if (frame || !renderer)
    return
  if (reducedMotion) {
    render()
    return
  }
  timer.reset()
  frame = requestAnimationFrame(loop)
}

function stop() {
  cancelAnimationFrame(frame)
  frame = 0
}

function playWave() {
  if (props.mood !== 'wave' || !wave || !idle || reducedMotion || wave.isRunning())
    return
  clearTimeout(waveTimer)
  wave.reset().setEffectiveWeight(1).fadeIn(0.1).play()
  idle.fadeOut(0.1)
}

// Waves again every few seconds while the cover is shown; the slight
// randomness keeps it from looking mechanical.
function scheduleWave(delay = 5000 + Math.random() * 3000) {
  clearTimeout(waveTimer)
  if (props.mood === 'wave' && active.value && !reducedMotion)
    waveTimer = setTimeout(playWave, delay)
}

let lastSize = ''

// Slidev scales the whole slide with a CSS transform to fit the screen, which
// layout sizes (and ResizeObserver) don't see. Render at the on-screen size so
// the canvas isn't upscaled and blurry; checked every frame, it's cheap.
function resize() {
  const el = container.value
  if (!el || !renderer)
    return
  const { clientWidth: w, clientHeight: h } = el
  if (!w || !h)
    return
  const ratio = Math.min(devicePixelRatio * el.getBoundingClientRect().width / w, 3)
  const size = `${w}x${h}@${ratio}`
  if (size === lastSize)
    return
  lastSize = size
  renderer.setPixelRatio(ratio)
  renderer.setSize(w, h, false)
  camera.aspect = w / h
  camera.updateProjectionMatrix()
  if (reducedMotion)
    render()
}

onMounted(async () => {
  const el = container.value!
  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
  renderer.outputColorSpace = THREE.SRGBColorSpace
  el.appendChild(renderer.domElement)
  addPlushLights(scene)

  const instance = await createPlush()
  if (!renderer) {
    instance.dispose()
    return
  }
  plush = instance
  const model = instance.model
  model.rotation.y = -0.45
  scene.add(model)
  baseY = model.position.y
  baseScale.copy(model.scale)

  const box = new THREE.Box3().setFromObject(model)
  const size = box.getSize(new THREE.Vector3())
  const center = box.getCenter(new THREE.Vector3())
  // Jumping needs headroom: frame the whole hop instead of just the standing plush.
  hopHeight = props.mood === 'jump' ? size.y * 0.45 : 0
  const halfHeight = props.mood === 'jump' ? size.y * 0.62 + hopHeight / 2 : size.y * 0.85
  const lift = props.mood === 'jump' ? hopHeight / 2 : size.y * 0.08
  const distance = halfHeight / Math.tan(THREE.MathUtils.degToRad(camera.fov / 2))
  camera.position.set(center.x, center.y + lift + size.y * 0.02, center.z + distance)
  camera.lookAt(center.x, center.y + lift, center.z)

  mixer = new THREE.AnimationMixer(model)
  const clip = (name: string) => THREE.AnimationClip.findByName(instance.animations, name)
  idle = mixer.clipAction(clip('idle'))
  wave = mixer.clipAction(clip('wave'))
  up = mixer.clipAction(clip('up'))
  fall = mixer.clipAction(clip('fall'))
  wave.setLoop(THREE.LoopOnce, 1)
  wave.clampWhenFinished = true
  idle.play()
  pose = idle
  mixer.addEventListener('finished', (e) => {
    if (e.action === wave) {
      idle!.reset().fadeIn(0.2).play()
      wave!.fadeOut(0.2)
      scheduleWave()
    }
  })

  resizeObserver = new ResizeObserver(resize)
  resizeObserver.observe(el)
  // The animation loop rechecks the size; this covers reduced motion, which has no loop.
  window.addEventListener('resize', resize)
  resize()

  watch(active, (isActive) => {
    clearTimeout(waveTimer)
    if (isActive) {
      start()
      scheduleWave(700)
    }
    else {
      stop()
    }
  }, { immediate: true })
  if (reducedMotion)
    render()
})

onBeforeUnmount(() => {
  clearTimeout(waveTimer)
  stop()
  resizeObserver?.disconnect()
  window.removeEventListener('resize', resize)
  mixer?.stopAllAction()
  plush?.dispose()
  renderer?.dispose()
  renderer?.domElement.remove()
  renderer = null
})
</script>

<template>
  <div
    ref="container"
    class="godot-plush"
    role="img"
    :aria-label="mood === 'jump' ? 'Le personnage en peluche de Godot, qui saute de joie' : 'Le personnage en peluche de Godot, qui fait coucou'"
    :title="mood === 'jump' ? 'Youpi !' : 'Coucou !'"
    @click="playWave"
  />
</template>

<style scoped>
.godot-plush {
  cursor: pointer;
}
.godot-plush :deep(canvas) {
  display: block;
  width: 100%;
  height: 100%;
}
</style>

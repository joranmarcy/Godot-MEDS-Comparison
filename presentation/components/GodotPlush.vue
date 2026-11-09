<!-- Godot plush character by Tibo (MIT): https://github.com/gtibo/Godot-Plush-Character -->
<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useIsSlideActive } from '@slidev/client'
import * as THREE from 'three'
import { addPlushLights, blinkOffset, createPlush, type PlushInstance } from '../composables/plush'

const container = ref<HTMLDivElement>()
const active = useIsSlideActive()
const reducedMotion = typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches

let renderer: THREE.WebGLRenderer | null = null
let plush: PlushInstance | null = null
let mixer: THREE.AnimationMixer | null = null
let idle: THREE.AnimationAction | null = null
let wave: THREE.AnimationAction | null = null
let frame = 0
let resizeObserver: ResizeObserver | null = null
let waveTimer: ReturnType<typeof setTimeout> | undefined
const scene = new THREE.Scene()
const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 50)
const timer = new THREE.Timer()

function render(timestamp?: number) {
  if (!renderer)
    return
  timer.update(timestamp)
  mixer?.update(timer.getDelta())
  if (plush)
    plush.eyeTexture.offset.x = blinkOffset(timer.getElapsed())
  renderer.render(scene, camera)
}

function loop(timestamp: number) {
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
  if (!wave || !idle || reducedMotion || wave.isRunning())
    return
  wave.reset().setEffectiveWeight(1).fadeIn(0.1).play()
  idle.fadeOut(0.1)
}

function resize() {
  const el = container.value
  if (!el || !renderer)
    return
  const { clientWidth: w, clientHeight: h } = el
  if (!w || !h)
    return
  renderer.setSize(w, h, false)
  camera.aspect = w / h
  camera.updateProjectionMatrix()
  if (reducedMotion)
    render()
}

onMounted(async () => {
  const el = container.value!
  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
  renderer.setPixelRatio(Math.min(devicePixelRatio, 2))
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

  const box = new THREE.Box3().setFromObject(model)
  const size = box.getSize(new THREE.Vector3())
  const center = box.getCenter(new THREE.Vector3())
  const distance = (size.y * 0.85) / Math.tan(THREE.MathUtils.degToRad(camera.fov / 2))
  camera.position.set(center.x, center.y + size.y * 0.1, center.z + distance)
  camera.lookAt(center.x, center.y + size.y * 0.08, center.z)

  mixer = new THREE.AnimationMixer(model)
  const clip = (name: string) => THREE.AnimationClip.findByName(instance.animations, name)
  idle = mixer.clipAction(clip('idle'))
  wave = mixer.clipAction(clip('wave'))
  wave.setLoop(THREE.LoopOnce, 1)
  wave.clampWhenFinished = true
  idle.play()
  mixer.addEventListener('finished', (e) => {
    if (e.action === wave) {
      idle!.reset().fadeIn(0.2).play()
      wave!.fadeOut(0.2)
    }
  })

  resizeObserver = new ResizeObserver(resize)
  resizeObserver.observe(el)
  resize()

  watch(active, (isActive) => {
    clearTimeout(waveTimer)
    if (isActive) {
      start()
      waveTimer = setTimeout(playWave, 700)
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
    aria-label="Le personnage en peluche de Godot, qui fait coucou"
    title="Coucou !"
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

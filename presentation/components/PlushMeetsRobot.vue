<!-- The Godot plush (Tibo, MIT) meets a small robot built from primitives: they wave at each other in turn. -->
<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useIsSlideActive } from '@slidev/client'
import * as THREE from 'three'
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js'
import { addPlushLights, blinkOffset, createPlush, plushMaterial, type PlushInstance } from '../composables/plush'

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
const scene = new THREE.Scene()
const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 100)
const timer = new THREE.Timer()
const framing = new THREE.Box3()
const disposables: { dispose: () => void }[] = []

// Robot parts animated every frame.
const robot = new THREE.Group()
const robotBody = new THREE.Group()
const robotHead = new THREE.Group()
const waveArm = new THREE.Group()
const eyes: THREE.Mesh[] = []
let antennaMaterial: THREE.MeshStandardMaterial | null = null

// Greeting loop: the plush waves, then the robot waves back.
const CYCLE = 6
const PLUSH_WAVE_AT = 0.4
const ROBOT_WAVE_AT = 2.2
const ROBOT_WAVE_FOR = 1.8
let lastCycleTime = 0

function track<T extends { dispose: () => void }>(item: T) {
  disposables.push(item)
  return item
}

function mesh(geometry: THREE.BufferGeometry, material: THREE.Material) {
  return new THREE.Mesh(track(geometry), material)
}

function buildRobot() {
  const metal = track(plushMaterial({ color: 0xD9DEE7, roughness: 0.45, metalness: 0.25 }))
  const dark = track(plushMaterial({ color: 0x2A3242, roughness: 0.6 }))
  const glow = track(new THREE.MeshStandardMaterial({ color: 0x5FF3FF, emissive: 0x5FF3FF, emissiveIntensity: 1.6 }))
  antennaMaterial = track(new THREE.MeshStandardMaterial({ color: 0xFC7F7F, emissive: 0xFC7F7F, emissiveIntensity: 1 }))

  for (const side of [-1, 1]) {
    const leg = mesh(new THREE.CapsuleGeometry(0.11, 0.22, 6, 16), dark)
    leg.position.set(side * 0.2, 0.26, 0)
    const foot = mesh(new RoundedBoxGeometry(0.26, 0.12, 0.34, 3, 0.05), metal)
    foot.position.set(side * 0.2, 0.06, 0.04)
    robot.add(leg, foot)
  }

  const torso = mesh(new RoundedBoxGeometry(0.9, 0.78, 0.6, 4, 0.14), metal)
  torso.position.y = 0.86
  const chest = mesh(new THREE.CircleGeometry(0.09, 24), glow)
  chest.position.set(0, 0.92, 0.305)
  const neck = mesh(new THREE.CylinderGeometry(0.1, 0.12, 0.14, 16), dark)
  neck.position.y = 1.3
  robotBody.add(torso, chest, neck)

  const head = mesh(new RoundedBoxGeometry(0.82, 0.6, 0.62, 4, 0.16), metal)
  const visor = mesh(new RoundedBoxGeometry(0.64, 0.3, 0.06, 3, 0.06), dark)
  visor.position.set(0, 0, 0.3)
  for (const side of [-1, 1]) {
    const eye = mesh(new THREE.SphereGeometry(0.065, 20, 12), glow)
    eye.position.set(side * 0.15, 0.01, 0.34)
    eye.scale.z = 0.5
    eyes.push(eye)
    const ear = mesh(new THREE.CylinderGeometry(0.09, 0.09, 0.08, 20), dark)
    ear.rotation.z = Math.PI / 2
    ear.position.set(side * 0.44, 0, 0)
    robotHead.add(eye, ear)
  }
  const stalk = mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.22, 8), dark)
  stalk.position.y = 0.4
  const bulb = mesh(new THREE.SphereGeometry(0.07, 20, 12), antennaMaterial)
  bulb.position.y = 0.54
  robotHead.add(head, visor, stalk, bulb)
  robotHead.position.y = 1.66
  robotBody.add(robotHead)

  for (const side of [-1, 1]) {
    const shoulder = side === 1 ? waveArm : new THREE.Group()
    shoulder.position.set(side * 0.52, 1.12, 0)
    const arm = mesh(new THREE.CapsuleGeometry(0.09, 0.36, 6, 16), dark)
    arm.position.y = -0.27
    const hand = mesh(new THREE.SphereGeometry(0.12, 20, 12), metal)
    hand.position.y = -0.56
    shoulder.add(arm, hand)
    shoulder.rotation.z = side * 0.12
    robotBody.add(shoulder)
  }

  robot.add(robotBody)
}

function playPlushWave() {
  if (!wave || !idle || wave.isRunning())
    return
  wave.reset().setEffectiveWeight(1).fadeIn(0.1).play()
  idle.fadeOut(0.1)
}

function animateRobot(time: number) {
  const t = time % CYCLE
  robotBody.position.y = Math.sin(time * 2.2) * 0.015
  robotHead.rotation.z = Math.sin(time * 1.3) * 0.05

  // Wave: raise the arm, wiggle, lower it.
  const w = t - ROBOT_WAVE_AT
  if (w > 0 && w < ROBOT_WAVE_FOR) {
    const raise = Math.min(1, w / 0.25, (ROBOT_WAVE_FOR - w) / 0.25)
    waveArm.rotation.z = 0.12 + raise * (2.5 + Math.sin(w * 14) * 0.3)
    robotHead.rotation.z += raise * 0.12
  }
  else {
    waveArm.rotation.z = 0.12
  }

  // Blink every ~3 s.
  const blink = time % 3.1 < 0.12 ? 0.15 : 1
  for (const eye of eyes)
    eye.scale.y = blink
  if (antennaMaterial)
    antennaMaterial.emissiveIntensity = 0.6 + 0.8 * (0.5 + 0.5 * Math.sin(time * 4))
}

function render(timestamp?: number) {
  if (!renderer)
    return
  timer.update(timestamp)
  mixer?.update(timer.getDelta())
  const time = timer.getElapsed()
  if (plush)
    plush.eyeTexture.offset.x = blinkOffset(time)
  if (!reducedMotion) {
    const t = time % CYCLE
    if (lastCycleTime < PLUSH_WAVE_AT && t >= PLUSH_WAVE_AT)
      playPlushWave()
    lastCycleTime = t
    animateRobot(time)
  }
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
  lastCycleTime = 0
  frame = requestAnimationFrame(loop)
}

function stop() {
  cancelAnimationFrame(frame)
  frame = 0
}

// Fit both characters, whatever the container's aspect ratio.
function frameCamera() {
  const size = framing.getSize(new THREE.Vector3())
  const center = framing.getCenter(new THREE.Vector3())
  const tan = Math.tan(THREE.MathUtils.degToRad(camera.fov / 2))
  const distance = Math.max(size.y / 2 / tan, size.x / 2 / (tan * camera.aspect)) * 1.12 + size.z / 2
  camera.position.set(center.x, center.y + size.y * 0.12, center.z + distance)
  camera.lookAt(center.x, center.y, center.z)
}

let lastSize = ''

// Slidev scales slides with a CSS transform; render at the on-screen size to stay sharp.
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
  frameCamera()
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
  scene.add(model)
  const plushBox = new THREE.Box3().setFromObject(model)
  const plushHeight = plushBox.getSize(new THREE.Vector3()).y

  // Plush on the left looking right, robot on the right looking left; the robot is a bit taller.
  const gap = plushHeight * 0.6
  model.position.x = -gap
  model.rotation.y = 0.85
  buildRobot()
  robot.scale.setScalar(plushHeight * 1.1 / 2.3)
  robot.position.set(gap, plushBox.min.y, 0)
  robot.rotation.y = -0.85
  scene.add(robot)

  framing.setFromObject(model).union(new THREE.Box3().setFromObject(robot))
  // Headroom for the raised arms.
  framing.max.y += plushHeight * 0.1

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
  window.addEventListener('resize', resize)
  resize()
  // Draw a first frame right away so the scene is visible while the slide transitions in.
  render()

  watch(active, isActive => isActive ? start() : stop(), { immediate: true })
  if (reducedMotion)
    render()
})

onBeforeUnmount(() => {
  stop()
  resizeObserver?.disconnect()
  window.removeEventListener('resize', resize)
  mixer?.stopAllAction()
  plush?.dispose()
  for (const d of disposables)
    d.dispose()
  renderer?.dispose()
  renderer?.domElement.remove()
  renderer = null
})
</script>

<template>
  <div
    ref="container"
    class="plush-meets-robot"
    role="img"
    aria-label="Le personnage en peluche de Godot rencontre un robot : ils se font coucou"
  />
</template>

<style scoped>
.plush-meets-robot :deep(canvas) {
  display: block;
  width: 100%;
  height: 100%;
}
</style>

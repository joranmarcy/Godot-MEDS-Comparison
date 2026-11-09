<!-- Inline 3D heart that beats and gently sways, sized to the surrounding text. -->
<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useIsSlideActive } from '@slidev/client'
import * as THREE from 'three'

const container = ref<HTMLSpanElement>()
const active = useIsSlideActive()
const reducedMotion = typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches

let renderer: THREE.WebGLRenderer | null = null
let heart: THREE.Group | null = null
let frame = 0
let lastSize = ''
const scene = new THREE.Scene()
const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 50)
camera.position.z = 6.8

function heartGeometry() {
  // Classic two-lobe heart outline: notch at the top, point at the bottom.
  const s = new THREE.Shape()
  s.moveTo(0, 0.5)
  s.bezierCurveTo(0, 0.5, -0.1, 1, -0.6, 1)
  s.bezierCurveTo(-1.3, 1, -1.3, 0.2, -1.3, 0.2)
  s.bezierCurveTo(-1.3, -0.3, -0.8, -0.8, 0, -1.3)
  s.bezierCurveTo(0.8, -0.8, 1.3, -0.3, 1.3, 0.2)
  s.bezierCurveTo(1.3, 0.2, 1.3, 1, 0.6, 1)
  s.bezierCurveTo(0.1, 1, 0, 0.5, 0, 0.5)
  const geometry = new THREE.ExtrudeGeometry(s, {
    depth: 0.35,
    bevelEnabled: true,
    bevelThickness: 0.3,
    bevelSize: 0.25,
    bevelSegments: 10,
    curveSegments: 32,
  })
  geometry.center()
  return geometry
}

function resize() {
  const el = container.value
  if (!el || !renderer)
    return
  const w = el.clientWidth
  const h = el.clientHeight
  if (!w || !h)
    return
  // The slide is CSS-scaled to fit the screen: render at the on-screen size so it stays sharp.
  const ratio = Math.min(devicePixelRatio * el.getBoundingClientRect().width / w, 3)
  const size = `${w}x${h}@${ratio}`
  if (size === lastSize)
    return
  lastSize = size
  renderer.setPixelRatio(ratio)
  renderer.setSize(w, h, false)
  camera.aspect = w / h
  camera.updateProjectionMatrix()
}

// Double "lub-dub" beat every 1.1 s.
function beat(t: number) {
  const p = (t % 1.1) / 1.1
  const pulse = (center: number, width: number) => Math.max(0, 1 - Math.abs(p - center) / width)
  return 1 + 0.16 * pulse(0.08, 0.08) + 0.1 * pulse(0.28, 0.08)
}

function render(time: number) {
  if (!renderer || !heart)
    return
  resize()
  const t = time / 1000
  heart.scale.setScalar(reducedMotion ? 1 : beat(t))
  heart.rotation.y = reducedMotion ? 0.35 : Math.sin(t * 1.4) * 0.5
  heart.rotation.x = reducedMotion ? 0 : Math.sin(t * 0.9) * 0.12
  renderer.render(scene, camera)
}

function loop(time: number) {
  render(time)
  frame = requestAnimationFrame(loop)
}

function start() {
  if (frame || reducedMotion) {
    render(0)
    return
  }
  frame = requestAnimationFrame(loop)
}

function stop() {
  cancelAnimationFrame(frame)
  frame = 0
}

onMounted(() => {
  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
  renderer.outputColorSpace = THREE.SRGBColorSpace
  container.value!.appendChild(renderer.domElement)

  scene.add(new THREE.HemisphereLight(0xFFFFFF, 0x401020, 1.4))
  const key = new THREE.DirectionalLight(0xFFFFFF, 2.6)
  key.position.set(2, 3, 4)
  scene.add(key)
  const rim = new THREE.DirectionalLight(0xFF9FB8, 1.5)
  rim.position.set(-3, 1, -2)
  scene.add(rim)

  const mesh = new THREE.Mesh(
    heartGeometry(),
    new THREE.MeshPhysicalMaterial({ color: 0xF0344F, roughness: 0.25, clearcoat: 1, clearcoatRoughness: 0.15 }),
  )
  heart = new THREE.Group()
  heart.add(mesh)
  scene.add(heart)

  watch(active, isActive => (isActive ? start() : stop()), { immediate: true })
})

onBeforeUnmount(() => {
  stop()
  scene.traverse((o) => {
    const mesh = o as THREE.Mesh
    if (mesh.isMesh) {
      mesh.geometry.dispose()
      ;(mesh.material as THREE.Material).dispose()
    }
  })
  renderer?.dispose()
  renderer = null
})
</script>

<template>
  <span ref="container" class="heart-3d" role="img" aria-label="cœur" />
</template>

<style scoped>
.heart-3d {
  display: inline-block;
  width: 2.2em;
  height: 2.2em;
  margin: -0.6em -0.3em -0.6em 0;
  vertical-align: middle;
}
.heart-3d :deep(canvas) {
  display: block;
  width: 100%;
  height: 100%;
}
</style>

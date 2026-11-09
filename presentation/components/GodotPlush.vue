<!-- Godot plush character by Tibo (MIT): https://github.com/gtibo/Godot-Plush-Character -->
<script setup lang="ts">
import { onMounted, onBeforeUnmount, ref, watch } from 'vue'
import { useIsSlideActive } from '@slidev/client'
import * as THREE from 'three'
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js'

const base = import.meta.env.BASE_URL
const container = ref<HTMLDivElement>()
const active = useIsSlideActive()
const reducedMotion = typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches

// Same keys as the project's custom_animations/blink (6 s loop, step interpolation):
// eye surfaces shift their texture by 0.75 to show the closed-eye line.
const BLINK_KEYS: [number, number][] = [[0, 0], [1, 0.75], [1.2, 0], [1.4, 0.75], [1.5, 0], [3, 0.75], [3.2, 0]]
function blinkOffset(time: number) {
  const t = time % 6
  let value = 0
  for (const [key, v] of BLINK_KEYS) {
    if (t >= key)
      value = v
  }
  return value
}

let renderer: THREE.WebGLRenderer | null = null
let mixer: THREE.AnimationMixer | null = null
let idle: THREE.AnimationAction | null = null
let wave: THREE.AnimationAction | null = null
let eyeTexture: THREE.Texture | null = null
let frame = 0
let resizeObserver: ResizeObserver | null = null
let waveTimer: ReturnType<typeof setTimeout> | undefined
const scene = new THREE.Scene()
const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 50)
const timer = new THREE.Timer()
const disposables: { dispose: () => void }[] = []

function plushMaterial(map: THREE.Texture, normalMap: THREE.Texture) {
  const material = new THREE.MeshStandardMaterial({ map, normalMap, roughness: 0.7, metalness: 0 })
  // Port of godot_plush.gdshader's fresnel rim light on upward-facing surfaces.
  material.onBeforeCompile = (shader) => {
    shader.fragmentShader = shader.fragmentShader.replace(
      '#include <emissivemap_fragment>',
      `#include <emissivemap_fragment>
      float plushFresnel = 1.0 - clamp(dot(normalize(normal), normalize(vViewPosition)), 0.0, 1.0);
      totalEmissiveRadiance += mix(vec3(1.0), diffuseColor.rgb, 0.75)
        * clamp(smoothstep(0.6, 0.7, plushFresnel) * normal.y, 0.0, 1.0) * 2.0;`,
    )
  }
  disposables.push(material)
  return material
}

function render(timestamp?: number) {
  if (!renderer)
    return
  timer.update(timestamp)
  mixer?.update(timer.getDelta())
  if (eyeTexture)
    eyeTexture.offset.x = blinkOffset(timer.getElapsed())
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

  scene.add(new THREE.HemisphereLight(0xffffff, 0x2d3a4a, 1.6))
  const sun = new THREE.DirectionalLight(0xffffff, 2.2)
  sun.position.set(2, 4, 3)
  scene.add(sun)

  const textures = new THREE.TextureLoader()
  const [gltf, albedo, normal] = await Promise.all([
    new GLTFLoader().loadAsync(`${base}plush/godot_plush_model.glb`),
    textures.loadAsync(`${base}plush/godot_plush_albedo.png`),
    textures.loadAsync(`${base}plush/godot_plush_normal.png`),
  ])
  if (!renderer)
    return
  albedo.colorSpace = THREE.SRGBColorSpace
  albedo.flipY = normal.flipY = false
  eyeTexture = albedo.clone()
  disposables.push(albedo, normal, eyeTexture)

  const body = plushMaterial(albedo, normal)
  const eyes = plushMaterial(eyeTexture, normal)
  const surfaces: THREE.Mesh[] = []
  gltf.scene.traverse((o) => {
    if ((o as THREE.Mesh).isMesh)
      surfaces.push(o as THREE.Mesh)
  })
  // glTF primitives keep Godot's surface order; surfaces 1 and 2 are the eyes.
  surfaces.forEach((mesh, i) => {
    mesh.material = i === 1 || i === 2 ? eyes : body
    mesh.frustumCulled = false
    disposables.push(mesh.geometry)
  })

  const model = gltf.scene
  model.rotation.y = -0.45
  scene.add(model)

  const box = new THREE.Box3().setFromObject(model)
  const size = box.getSize(new THREE.Vector3())
  const center = box.getCenter(new THREE.Vector3())
  const distance = (size.y * 0.85) / Math.tan(THREE.MathUtils.degToRad(camera.fov / 2))
  camera.position.set(center.x, center.y + size.y * 0.1, center.z + distance)
  camera.lookAt(center.x, center.y + size.y * 0.08, center.z)

  mixer = new THREE.AnimationMixer(model)
  const clip = (name: string) => THREE.AnimationClip.findByName(gltf.animations, name)
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
  disposables.forEach(d => d.dispose())
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

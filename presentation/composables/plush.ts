// Godot plush character by Tibo (MIT): https://github.com/gtibo/Godot-Plush-Character
// Loads the model once and hands out independent, animatable copies.

import * as THREE from 'three'
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js'
import { clone as cloneSkinned } from 'three/examples/jsm/utils/SkeletonUtils.js'

// Same keys as the project's custom_animations/blink (6 s loop, step interpolation):
// eye surfaces shift their texture by 0.75 to show the closed-eye line.
const BLINK_KEYS: [number, number][] = [[0, 0], [1, 0.75], [1.2, 0], [1.4, 0.75], [1.5, 0], [3, 0.75], [3.2, 0]]

export function blinkOffset(time: number) {
  const t = time % 6
  let value = 0
  for (const [key, v] of BLINK_KEYS) {
    if (t >= key)
      value = v
  }
  return value
}

export interface PlushInstance {
  model: THREE.Object3D
  animations: THREE.AnimationClip[]
  eyeTexture: THREE.Texture
  dispose: () => void
}

interface PlushSource {
  gltf: { scene: THREE.Object3D, animations: THREE.AnimationClip[] }
  albedo: THREE.Texture
  normal: THREE.Texture
}

let source: Promise<PlushSource> | null = null

function loadSource() {
  const base = import.meta.env.BASE_URL
  const textures = new THREE.TextureLoader()
  source ??= Promise.all([
    new GLTFLoader().loadAsync(`${base}plush/godot_plush_model.glb`),
    textures.loadAsync(`${base}plush/godot_plush_albedo.png`),
    textures.loadAsync(`${base}plush/godot_plush_normal.png`),
  ]).then(([gltf, albedo, normal]) => {
    albedo.colorSpace = THREE.SRGBColorSpace
    albedo.flipY = normal.flipY = false
    return { gltf, albedo, normal }
  })
  return source
}

export function plushMaterial(params: THREE.MeshStandardMaterialParameters) {
  const material = new THREE.MeshStandardMaterial({ roughness: 0.7, metalness: 0, ...params })
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
  return material
}

export async function createPlush(): Promise<PlushInstance> {
  const { gltf, albedo, normal } = await loadSource()
  const model = cloneSkinned(gltf.scene)
  // Each copy blinks on its own, so it gets its own eye texture (sharing the image).
  const eyeTexture = albedo.clone()
  const body = plushMaterial({ map: albedo, normalMap: normal })
  const eyes = plushMaterial({ map: eyeTexture, normalMap: normal })

  let surface = 0
  model.traverse((o) => {
    const mesh = o as THREE.Mesh
    if (!mesh.isMesh)
      return
    // glTF primitives keep Godot's surface order; surfaces 1 and 2 are the eyes.
    mesh.material = surface === 1 || surface === 2 ? eyes : body
    mesh.frustumCulled = false
    surface++
  })

  return {
    model,
    animations: gltf.animations,
    eyeTexture,
    // Geometry and the shared textures belong to the cached source and stay alive.
    dispose: () => {
      body.dispose()
      eyes.dispose()
      eyeTexture.dispose()
    },
  }
}

// Body colour of the plush texture, so props match the character.
export const PLUSH_BLUE = 0x1899FF

export function addPlushLights(scene: THREE.Scene) {
  scene.add(new THREE.HemisphereLight(0xFFFFFF, 0x2D3A4A, 1.6))
  const sun = new THREE.DirectionalLight(0xFFFFFF, 2.2)
  sun.position.set(2, 4, 3)
  scene.add(sun)
}

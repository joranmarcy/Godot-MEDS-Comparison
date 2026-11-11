<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue'
import { useNav } from '@slidev/client'
import PlushRunTransition from './components/PlushRunTransition.vue'
import { isShareVisible, shareStream } from './composables/godotShare'

const video = ref<HTMLVideoElement>()
const overlay = ref<HTMLDivElement>()
// The capture usually includes the presenter window itself, so showing it there
// creates an endless mirror: the feed is for the audience view only.
const { isPresenter, currentSlideNo } = useNav()

watch([video, shareStream], ([el, stream]) => {
  if (el)
    el.srcObject = stream
})

// The feed covers the whole slide; the current slide's title is shown on top of it.
// Read every frame while shown, so it follows slide changes and late renders.
const title = ref('')
let frame = 0

function readTitle() {
  const h1 = overlay.value?.parentElement
    ?.querySelector<HTMLElement>(`#slideshow > .slidev-page-${currentSlideNo.value} h1`)
  title.value = h1?.textContent?.trim() ?? ''
  frame = requestAnimationFrame(readTitle)
}

watch([isShareVisible, overlay], () => {
  cancelAnimationFrame(frame)
  frame = 0
  if (isShareVisible.value && overlay.value)
    readTitle()
}, { immediate: true, flush: 'post' })

onBeforeUnmount(() => cancelAnimationFrame(frame))
</script>

<template>
  <PlushRunTransition />
  <div
    v-if="shareStream && !isPresenter"
    v-show="isShareVisible"
    ref="overlay"
    class="godot-share-overlay"
  >
    <video ref="video" autoplay muted playsinline />
    <div v-if="title" class="godot-share-title">
      {{ title }}
    </div>
  </div>
  <div v-if="isPresenter && shareStream && isShareVisible" class="godot-share-badge">
    <img src="/godot/icon_color.svg" alt="" />
    Godot à l'écran
  </div>
</template>

<style scoped>
.godot-share-overlay {
  position: absolute;
  inset: 0;
  z-index: 100;
  background: #000;
}
video {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: contain;
}
.godot-share-title {
  position: absolute;
  top: 0.75rem;
  left: 0.75rem;
  max-width: calc(100% - 1.5rem);
  padding: 0.35rem 0.9rem;
  border-radius: 8px;
  border-left: 4px solid var(--godot-blue);
  background: rgba(32, 35, 38, 0.85);
  backdrop-filter: blur(4px);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
  color: #fff;
  font-family: 'Montserrat Variable', sans-serif;
  font-size: 1.1rem;
  font-weight: 700;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.godot-share-badge {
  position: absolute;
  top: 0.75rem;
  right: 0.75rem;
  z-index: 100;
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.3rem 0.7rem;
  border-radius: 999px;
  background: rgba(0, 0, 0, 0.75);
  border: 1px solid var(--godot-blue);
  color: #fff;
  font-size: 0.8rem;
}
.godot-share-badge img {
  width: 1.1em;
  height: 1.1em;
}
</style>

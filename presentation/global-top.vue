<script setup lang="ts">
import { ref, watch } from 'vue'
import { useNav } from '@slidev/client'
import PlushRunTransition from './components/PlushRunTransition.vue'
import { isShareVisible, shareStream } from './composables/godotShare'

const video = ref<HTMLVideoElement>()
// The capture usually includes the presenter window itself, so showing it there
// creates an endless mirror: the feed is for the audience view only.
const { isPresenter } = useNav()

watch([video, shareStream], ([el, stream]) => {
  if (el)
    el.srcObject = stream
})
</script>

<template>
  <PlushRunTransition />
  <div v-if="shareStream && !isPresenter" v-show="isShareVisible" class="godot-share-overlay">
    <video ref="video" autoplay muted playsinline />
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
  width: 100%;
  height: 100%;
  object-fit: contain;
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

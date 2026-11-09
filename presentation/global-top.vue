<script setup lang="ts">
import { ref, watch } from 'vue'
import PlushRunTransition from './components/PlushRunTransition.vue'
import { isShareVisible, shareStream } from './composables/godotShare'

const video = ref<HTMLVideoElement>()

watch([video, shareStream], ([el, stream]) => {
  if (el)
    el.srcObject = stream
})
</script>

<template>
  <PlushRunTransition />
  <div v-if="shareStream" v-show="isShareVisible" class="godot-share-overlay">
    <video ref="video" autoplay muted playsinline />
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
</style>

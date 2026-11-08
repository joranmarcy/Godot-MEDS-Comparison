<script setup lang="ts">
import { ref } from 'vue'
import { isCapturing, isShareVisible, stopShare, toggleShare } from './composables/godotShare'

const error = ref('')

async function onClick() {
  error.value = ''
  try {
    await toggleShare()
  }
  catch (e) {
    if ((e as DOMException).name !== 'NotAllowedError')
      error.value = 'Partage impossible'
  }
}
</script>

<template>
  <button
    class="slidev-icon-btn godot-share-btn"
    :class="{ active: isShareVisible }"
    :title="error || (isShareVisible ? 'Revenir aux slides' : isCapturing ? 'Afficher l\'éditeur Godot' : 'Partager l\'éditeur Godot')"
    @click="onClick"
  >
    <carbon-presentation-file v-if="isShareVisible" />
    <img v-else src="/godot/icon_color.svg" alt="" />
  </button>
  <button
    v-if="isCapturing"
    class="slidev-icon-btn"
    title="Arrêter la capture de Godot"
    @click="stopShare"
  >
    <carbon-stop-outline />
  </button>
</template>

<style scoped>
.godot-share-btn img {
  width: 1.2em;
  height: 1.2em;
}
.godot-share-btn.active {
  color: var(--godot-blue-light);
}
</style>

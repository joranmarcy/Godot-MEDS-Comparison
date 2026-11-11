<script setup lang="ts">
import { ref, watchEffect } from 'vue'
import { useNav } from '@slidev/client'
import PhoneNotesResizer from './components/PhoneNotesResizer.vue'
import { isCapturing, isShareVisible, stopShare, toggleShare } from './composables/godotShare'

const error = ref('')
const { isPresenter } = useNav()

// Presenter view: hide the "Next" slide preview. The layout CSS lives in
// styles/godot.css (`.presenter-hide-next`); the choice is remembered.
const HIDE_NEXT_KEY = 'meds-presenter-hide-next'
const hideNext = ref(localStorage.getItem(HIDE_NEXT_KEY) === 'true')
watchEffect(() => {
  localStorage.setItem(HIDE_NEXT_KEY, String(hideNext.value))
  document.documentElement.classList.toggle('presenter-hide-next', hideNext.value)
})

// While the Godot feed is shown, the presenter view drops the notes to give it the room
// (`.godot-sharing` rules in styles/godot.css).
watchEffect(() => {
  document.documentElement.classList.toggle('godot-sharing', isShareVisible.value)
})

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
  <PhoneNotesResizer v-if="isPresenter" />
  <button
    v-if="isPresenter"
    class="slidev-icon-btn"
    :title="hideNext ? 'Afficher la slide suivante' : 'Masquer la slide suivante'"
    @click="hideNext = !hideNext"
  >
    <carbon-view v-if="hideNext" />
    <carbon-view-off v-else />
  </button>
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

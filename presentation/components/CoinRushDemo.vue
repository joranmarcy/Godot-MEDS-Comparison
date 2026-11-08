<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $page, $nav } = useSlideContext()
const playing = ref(false)
const active = computed(() => $page.value === $nav.value.currentSlideNo)
const gameUrl = `${import.meta.env.BASE_URL}games/coin-rush/index.html`

watch(active, (value) => {
  if (!value)
    playing.value = false
})
</script>

<template>
  <div class="coin-rush-demo">
    <div class="demo-toolbar">
      <span>Coin Rush — version classique</span>
      <button v-if="playing" type="button" @click="playing = false">Arrêter</button>
      <a :href="gameUrl" target="_blank" rel="noopener">Ouvrir à part ↗</a>
    </div>
    <div class="demo-screen">
      <iframe
        v-if="playing && active"
        :src="gameUrl"
        title="Coin Rush — jeu interactif"
        allow="autoplay; fullscreen; gamepad"
      />
      <div v-else class="demo-start">
        <button type="button" @click="playing = true">Jouer à Coin Rush</button>
        <p>Ramassez les pièces, évitez les ennemis.</p>
      </div>
    </div>
    <div class="demo-controls">
      WASD / flèches / manette · Échap : pause<br/>
      Cliquez dans le jeu pour le contrôler, puis sur « Arrêter » pour reprendre la présentation.
    </div>
  </div>
</template>

<style scoped>
.coin-rush-demo {
  text-align: left;
}
.demo-toolbar {
  display: flex;
  align-items: center;
  gap: 0.8rem;
  margin-bottom: 0.5rem;
  font-size: 0.7rem;
}
.demo-toolbar span {
  margin-right: auto;
}
button {
  border: 1px solid var(--godot-blue-light);
  border-radius: 0.5rem;
  background: var(--godot-blue-dark);
  color: #fff;
  padding: 0.4rem 0.8rem;
  cursor: pointer;
}
button:focus-visible {
  outline: 2px solid #fff;
  outline-offset: 3px;
}
.demo-screen {
  width: 100%;
  aspect-ratio: 16 / 9;
  overflow: hidden;
  border: 1px solid var(--godot-card-border);
  border-radius: 0.75rem;
  background: #12151f;
}
iframe {
  display: block;
  width: 100%;
  height: 100%;
  border: 0;
}
.demo-start {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
}
.demo-start p {
  font-size: 0.85rem;
  color: var(--godot-text-dim);
}
.demo-controls {
  margin-top: 0.5rem;
  font-size: 0.65rem;
  color: var(--godot-text-dim);
}
</style>

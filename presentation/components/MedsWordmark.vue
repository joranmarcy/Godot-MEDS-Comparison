<script setup lang="ts">
// The S is always shown; `highlight` (driven by a click on the slide) makes it
// pop, turn red and keep glowing.
defineProps<{ highlight?: boolean }>()
</script>

<template>
  <div class="meds-wordmark" :class="{ highlight }" role="img" aria-label="MEDS">
    <MedsLogo pill-only class="wordmark-pill" />
    <span class="letters" aria-hidden="true">
      <span>M</span><span>E</span><span>D</span><span class="letter-s">S</span>
    </span>
  </div>
</template>

<style scoped>
.meds-wordmark {
  display: inline-flex;
  align-items: center;
  gap: 0.35em;
  font-family: 'Montserrat Variable', sans-serif;
  font-weight: 800;
  font-size: 4.5rem;
  line-height: 1;
  color: #fff;
}

.wordmark-pill {
  width: 2.16em;
  height: 1em;
  flex-shrink: 0;
}

.letters {
  display: inline-flex;
  letter-spacing: 0.02em;
}

.letter-s {
  display: inline-block;
  transition: color 0.3s ease;
}

.highlight .letter-s {
  color: var(--meds-s);
  animation:
    s-pop 0.8s cubic-bezier(0.34, 1.56, 0.64, 1),
    s-glow 2.4s ease-in-out 0.8s infinite;
}

@keyframes s-pop {
  0% { transform: none; }
  40% { transform: translateY(-0.25em) rotate(-12deg) scale(1.45); text-shadow: 0 0 0.5em rgba(252, 127, 127, 0.9); }
  70% { transform: translateY(0.04em) rotate(4deg) scale(0.95); }
  100% { transform: none; }
}

@keyframes s-glow {
  0%, 100% { text-shadow: 0 0 0 transparent; transform: scale(1); }
  50% { text-shadow: 0 0 0.35em rgba(252, 127, 127, 0.75); transform: scale(1.08); }
}

@media (prefers-reduced-motion: reduce) {
  .highlight .letter-s {
    animation: none;
  }
}
</style>

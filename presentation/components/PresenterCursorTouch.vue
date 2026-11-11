<!-- Presenter view: while the presenter cursor tool is on, a finger on the current
     slide moves the cursor shown to the audience. Slidev would also read that drag as
     a swipe and change slide, so the touch never reaches its swipe handler then.
     Both toggles are Slidev's own settings, read from localStorage. -->
<script setup lang="ts">
import { onBeforeUnmount, onMounted } from 'vue'

const isOn = (key: string, fallback: boolean) => {
  const value = localStorage.getItem(key)
  return value === null ? fallback : value === 'true'
}

function onPointerDown(e: PointerEvent) {
  if (e.pointerType !== 'touch')
    return
  const slide = (e.target as Element | null)?.closest('.slidev-presenter .grid-section.main')
  if (!slide)
    return
  // Drawing needs the touch; Slidev already disables swipes while drawing.
  if (!isOn('slidev-presenter-cursor', true) || isOn('slidev-drawing-enabled', false))
    return
  e.stopPropagation()
}

// Capture on window runs before the swipe listener on the slide section.
onMounted(() => window.addEventListener('pointerdown', onPointerDown, { capture: true }))
onBeforeUnmount(() => window.removeEventListener('pointerdown', onPointerDown, { capture: true }))
</script>

<template>
  <span hidden />
</template>

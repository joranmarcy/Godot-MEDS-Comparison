<!-- Presenter view on a phone (portrait, layout 1): Slidev stacks slide / notes /
     next and doesn't let you resize them. This adds a drag handle at the top of
     the notes. The height is stored in --meds-phone-notes-height and applied by
     the `presenter-phone-notes` rules in styles/godot.css. -->
<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'

const STORAGE_KEY = 'meds-presenter-phone-notes-height'
const MIN_HEIGHT = 100
const MAX_RATIO = 0.8

const handle = ref<HTMLDivElement>()
let startY = 0
let startHeight = 0

function apply(height: number | null) {
  const root = document.documentElement
  root.classList.toggle('presenter-phone-notes', height !== null)
  if (height === null)
    root.style.removeProperty('--meds-phone-notes-height')
  else
    root.style.setProperty('--meds-phone-notes-height', `${height}px`)
}

function onPointerDown(e: PointerEvent) {
  const notes = handle.value?.parentElement
  if (!notes)
    return
  e.preventDefault()
  handle.value!.setPointerCapture(e.pointerId)
  startY = e.clientY
  startHeight = notes.getBoundingClientRect().height
}

function onPointerMove(e: PointerEvent) {
  if (!handle.value?.hasPointerCapture(e.pointerId))
    return
  const grid = handle.value.closest('.grid-container')
  const max = (grid?.getBoundingClientRect().height ?? window.innerHeight) * MAX_RATIO
  // Dragging the top edge up makes the notes taller.
  const height = Math.round(Math.min(Math.max(startHeight - (e.clientY - startY), MIN_HEIGHT), max))
  apply(height)
}

function onPointerUp(e: PointerEvent) {
  if (!handle.value?.hasPointerCapture(e.pointerId))
    return
  handle.value.releasePointerCapture(e.pointerId)
  const value = getComputedStyle(document.documentElement).getPropertyValue('--meds-phone-notes-height')
  if (value)
    localStorage.setItem(STORAGE_KEY, String(Number.parseFloat(value)))
}

// Double tap: back to Slidev's default split.
function reset() {
  localStorage.removeItem(STORAGE_KEY)
  apply(null)
}

onMounted(() => {
  const saved = Number(localStorage.getItem(STORAGE_KEY))
  if (saved > 0)
    apply(saved)
})

onBeforeUnmount(() => apply(null))
</script>

<template>
  <Teleport defer to=".slidev-presenter .grid-section.note">
    <div
      ref="handle"
      class="phone-notes-resizer"
      role="separator"
      aria-orientation="horizontal"
      title="Glisser pour redimensionner les notes (double-tap : taille par défaut)"
      @pointerdown="onPointerDown"
      @pointermove="onPointerMove"
      @pointerup="onPointerUp"
      @pointercancel="onPointerUp"
      @dblclick="reset"
    />
  </Teleport>
</template>

<style>
/* Hidden by default; shown only where Slidev stacks layout 1 (see godot.css). */
.phone-notes-resizer {
  display: none;
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 22px;
  z-index: 10;
  cursor: row-resize;
  touch-action: none;
}

.phone-notes-resizer::before {
  content: '';
  position: absolute;
  top: 7px;
  left: 50%;
  width: 44px;
  height: 5px;
  border-radius: 3px;
  background: currentColor;
  opacity: 0.35;
  transform: translateX(-50%);
}

@media (max-aspect-ratio: 3/5) {
  .slidev-presenter .grid-container.layout1 .phone-notes-resizer {
    display: block;
  }

  /* Keep the first note lines clear of the handle. */
  .slidev-presenter .grid-container.layout1 .grid-section.note {
    padding-top: 14px;
  }
}
</style>

<script setup lang="ts">
import { useNav } from '@slidev/client'

const { currentPage, total, currentLayout } = useNav()
</script>

<template>
  <div
    v-if="!['cover', 'section'].includes(currentLayout)"
    class="slide-counter"
  >
    {{ currentPage }} / {{ total }}
  </div>
</template>

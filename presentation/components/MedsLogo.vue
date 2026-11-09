<!-- MEDS logo from joranmarcy/Godot-MEDS-Sample (logo/meds.svg), cropped to its artwork.
     Inlined so the text uses the Montserrat font loaded by the deck. -->
<script setup lang="ts">
defineProps<{ pillOnly?: boolean }>()
</script>

<template>
  <svg
    :viewBox="pillOnly ? '58 112 94 43.5' : '37.26667 81.880775 135.46666 135.46666'"
    xmlns="http://www.w3.org/2000/svg"
    role="img"
    aria-label="Godot MEDS"
  >
    <rect v-if="!pillOnly" fill="#363c52" width="135.46666" height="135.46666" x="37.26667" y="81.880775" />
    <g transform="matrix(0.92521091,0,0,0.92521091,-6.0217374,-3.5062074)">
      <rect class="meds-logo-pill" fill="#4a88b9" width="101.06055" height="46.470566" x="69.465866" y="125.07384" ry="23.235283" />
      <rect class="meds-logo-bar" fill="#ffffff" width="4.8588605" height="46.468472" x="117.56671" y="125.07626" />
    </g>
    <text
      v-if="!pillOnly"
      x="58.689556"
      y="196.40514"
      fill="#ffffff"
      style="font-size: 29.4502px; font-weight: 700; font-family: 'Montserrat Variable', Montserrat, sans-serif; letter-spacing: normal"
    >MEDS</text>
  </svg>
</template>

<script setup lang="ts">
defineProps<{ after: boolean }>()

const otherFields = [
  { name: 'health', y: 92 },
  { name: 'score', y: 122 },
  { name: 'combo', y: 182 },
  { name: 'level', y: 212 },
  { name: 'is_running', y: 242 },
]
</script>

<template>
  <svg
    class="arch-morph"
    :class="{ after }"
    viewBox="0 0 1000 290"
    role="img"
    :aria-label="after
      ? 'Player écrit dans la variable PlayerPosition, que Enemy lit.'
      : 'Player écrit player_position dans le singleton GameState, que Enemy lit.'"
  >
    <defs>
      <marker id="arch-morph-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto">
        <path d="M0 0 L10 5 L0 10 z" fill="#cdcfd2" />
      </marker>
    </defs>

    <g class="node">
      <rect x="10" y="110" width="180" height="70" />
      <text x="100" y="152">Player</text>
    </g>
    <g class="node">
      <rect x="810" y="110" width="180" height="70" />
      <text x="900" y="152">Enemy</text>
    </g>

    <g class="before">
      <g class="edges">
        <line x1="190" y1="145" x2="376" y2="145" marker-end="url(#arch-morph-arrow)" />
        <line x1="620" y1="145" x2="806" y2="145" marker-end="url(#arch-morph-arrow)" />
      </g>
      <text class="edge-label" x="283" y="132">writes</text>
      <text class="edge-label" x="713" y="132">reads</text>
      <rect class="core" x="380" y="15" width="240" height="260" rx="6" />
      <text class="title" x="500" y="50">GameState (AutoLoad)</text>
      <text
        v-for="(field, i) in otherFields"
        :key="field.name"
        class="field"
        :class="field.y < 152 ? 'up' : 'down'"
        :style="{ transitionDelay: after ? `${i * 40}ms` : `${300 + i * 40}ms` }"
        x="500"
        :y="field.y"
      >{{ field.name }}</text>
      <rect class="focus" x="420" y="134" width="160" height="26" rx="4" />
      <text class="field focused" x="500" y="152">player_position</text>
    </g>

    <g class="after-group">
      <g class="edges">
        <line x1="190" y1="145" x2="406" y2="145" marker-end="url(#arch-morph-arrow)" />
        <line x1="590" y1="145" x2="806" y2="145" marker-end="url(#arch-morph-arrow)" />
      </g>
      <text class="edge-label" x="298" y="132">writes</text>
      <text class="edge-label" x="698" y="132">reads</text>
      <g class="variable">
        <path d="M410 60 V230 A90 18 0 0 0 590 230 V60" />
        <ellipse cx="500" cy="60" rx="90" ry="18" />
        <text x="500" y="142">PlayerPosition</text>
        <text x="500" y="172">Vector2Variable</text>
      </g>
    </g>
  </svg>
</template>

<style scoped>
.arch-morph {
  width: 100%;
  max-height: 270px;
  font-family: 'Inter Variable', sans-serif;
}
text {
  fill: #fff;
  font-size: 20px;
  text-anchor: middle;
}
.node rect {
  fill: var(--godot-base);
  stroke: #cdcfd2;
  stroke-width: 1.5;
}
.edges line {
  stroke: #cdcfd2;
  stroke-width: 1.5;
}
.edge-label {
  font-size: 17px;
  fill: #cdcfd2;
}
.core {
  fill: #4d3420;
  stroke: #ffb373;
  stroke-width: 2;
}
.title {
  font-family: 'Montserrat Variable', sans-serif;
  font-size: 18px;
  font-weight: 700;
}
.field {
  font-family: 'JetBrains Mono Variable', monospace;
  font-size: 16px;
  fill: hsla(0, 0%, 100%, 0.75);
}
.focus {
  fill: #1f3d57;
  stroke: #478cbf;
}
.focused {
  fill: #fff;
}
.variable path,
.variable ellipse {
  fill: #1f3d57;
  stroke: #478cbf;
  stroke-width: 2;
}
.before > *,
.after-group,
.variable {
  transition: opacity 0.5s ease, transform 0.6s ease;
  transform-box: view-box;
  transform-origin: 500px 145px;
}

.after-group {
  opacity: 0;
}
.variable {
  transform: scale(0.75);
}

.after .field:not(.focused) {
  opacity: 0;
}
.after .field.up {
  transform: translateY(-24px);
}
.after .field.down {
  transform: translateY(24px);
}
.after .core,
.after .title,
.after .before .edges,
.after .before .edge-label {
  opacity: 0;
  transition-delay: 0.25s;
}
.after .focus,
.after .focused {
  opacity: 0;
  transform: scale(1.15);
  transition-delay: 0.45s;
}
.after .after-group {
  opacity: 1;
  transition-delay: 0.45s;
}
.after .variable {
  transform: scale(1);
  transition-delay: 0.45s;
}

@media (prefers-reduced-motion: reduce) {
  .before > *,
  .after-group,
  .variable {
    transition-duration: 0s;
    transition-delay: 0s !important;
  }
}
</style>

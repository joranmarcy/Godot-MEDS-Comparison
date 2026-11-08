<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{ after: boolean }>()

type Kind = 'system' | 'core' | 'var' | 'evt'
type Point = [number, number]
interface ArchNode { id: string, kind: Kind, label: string, afterLabel?: string, before?: Point, after?: Point }
interface ArchEdge { from: string, to: string, label?: string[], route?: 'down' | 'loop' }

const CORE: Point = [500, 210]

// MEDS-only nodes start hidden inside GameState; the classic-only GameState has no `after`.
const nodes: ArchNode[] = [
  { id: 'player', kind: 'system', label: 'Player', before: [90, 90], after: [60, 110] },
  { id: 'coin', kind: 'system', label: 'Coin', before: [90, 210], after: [60, 340] },
  { id: 'enemy', kind: 'system', label: 'Enemy', before: [90, 330], after: [880, 40] },
  { id: 'gs', kind: 'core', label: 'GameState', before: CORE },
  { id: 'hud', kind: 'system', label: 'HUD', afterLabel: 'HUD (bindings)', before: [880, 60], after: [720, 290] },
  { id: 'shake', kind: 'system', label: 'ScreenShake', before: [880, 160], after: [390, 120] },
  { id: 'sfx', kind: 'system', label: 'SoundEffects', afterLabel: 'PlaySoundOnEvent', before: [880, 260], after: [390, 180] },
  { id: 'gos', kind: 'system', label: 'GameOverScreen', before: [880, 360], after: [880, 280] },
  { id: 'pp', kind: 'var', label: 'PlayerPosition', after: [390, 40] },
  { id: 'ph', kind: 'evt', label: 'PlayerHit', after: [240, 180] },
  { id: 'dmg', kind: 'system', label: 'DamageOnEvent', after: [390, 240] },
  { id: 'hp', kind: 'var', label: 'PlayerHealth', after: [560, 240] },
  { id: 'goz', kind: 'system', label: 'GameOverOnZeroHealth', after: [720, 180] },
  { id: 'go', kind: 'var', label: 'GameOver', after: [880, 180] },
  { id: 'cc', kind: 'evt', label: 'CoinCollected', after: [240, 340] },
  { id: 'sk', kind: 'system', label: 'ScoreKeeper', after: [390, 340] },
  { id: 'sc', kind: 'var', label: 'Score', after: [560, 340] },
  { id: 'lfs', kind: 'system', label: 'LevelFromScore', after: [720, 390] },
  { id: 'lv', kind: 'var', label: 'Level', after: [880, 390] },
]

const beforeEdges: ArchEdge[] = [
  { from: 'player', to: 'gs', label: ['damage_player()', 'player_position'] },
  { from: 'coin', to: 'gs', label: ['collect_coin()'] },
  { from: 'enemy', to: 'gs', label: ['player_position', 'level, is_running'] },
  { from: 'gs', to: 'hud', label: ['health_changed', 'score_changed'] },
  { from: 'gs', to: 'shake', label: ['player_hit'] },
  { from: 'gs', to: 'sfx', label: ['coin_collected', 'game_over'] },
  { from: 'gs', to: 'gos', label: ['game_over'] },
]

const afterEdges: ArchEdge[] = [
  { from: 'player', to: 'pp', label: ['writes'] },
  { from: 'pp', to: 'enemy' },
  { from: 'player', to: 'ph', label: ['déclenche'] },
  { from: 'ph', to: 'shake' },
  { from: 'ph', to: 'sfx' },
  { from: 'ph', to: 'dmg' },
  { from: 'dmg', to: 'hp' },
  { from: 'hp', to: 'hud' },
  { from: 'hp', to: 'goz' },
  { from: 'goz', to: 'go' },
  { from: 'go', to: 'gos', route: 'down' },
  { from: 'coin', to: 'cc', label: ['déclenche'] },
  { from: 'cc', to: 'sk' },
  { from: 'sk', to: 'sc' },
  { from: 'sc', to: 'hud' },
  { from: 'sc', to: 'lfs' },
  { from: 'lfs', to: 'lv' },
  { from: 'lv', to: 'enemy', route: 'loop' },
]

const byId = Object.fromEntries(nodes.map(n => [n.id, n]))

function label(n: ArchNode, after: boolean) {
  return after ? n.afterLabel ?? n.label : n.label
}
function width(n: ArchNode, after: boolean) {
  if (n.kind === 'core')
    return 190
  return Math.max(n.kind === 'var' ? 100 : 80, label(n, after).length * 7.6 + 26)
}
function height(n: ArchNode) {
  return n.kind === 'core' ? 90 : n.kind === 'var' ? 46 : 36
}
function position(n: ArchNode, after: boolean): Point {
  return (after ? n.after : n.before) ?? CORE
}

function nodeStyle(n: ArchNode) {
  const present = props.after ? !!n.after : !!n.before
  const [x, y] = position(n, props.after)
  const scale = present ? 1 : n.kind === 'core' ? 1.4 : 0.3
  return {
    transform: `translate(${x}px, ${y}px) scale(${scale})`,
    opacity: present ? 1 : 0,
  }
}

function rectStyle(n: ArchNode) {
  const w = width(n, props.after)
  return { x: `${-w / 2}px`, width: `${w}px` }
}

function cylinder(n: ArchNode) {
  const w = width(n, true) / 2
  const h = height(n) / 2
  return `M ${-w} ${-h + 7} V ${h - 7} A ${w} 7 0 0 0 ${w} ${h - 7} V ${-h + 7}`
}
function flag(n: ArchNode) {
  const w = width(n, true) / 2
  const h = height(n) / 2
  return `${-w},${-h} ${w},${-h} ${w},${h} ${-w},${h} ${-w + 10},0`
}

function edgeGeometry(e: ArchEdge, after: boolean) {
  const a = byId[e.from]
  const b = byId[e.to]
  const [ax, ay] = position(a, after)
  const [bx, by] = position(b, after)
  if (e.route === 'down') {
    const y1 = ay + height(a) / 2
    const y2 = by - height(b) / 2 - 2
    return { d: `M ${ax} ${y1} V ${y2}`, mid: [ax, (y1 + y2) / 2] }
  }
  if (e.route === 'loop') {
    const x1 = ax + width(a, after) / 2
    const x2 = bx + width(b, after) / 2 + 2
    const far = Math.max(x1, x2) + 55
    return { d: `M ${x1} ${ay} C ${far} ${ay}, ${far} ${by}, ${x2} ${by}`, mid: [far, (ay + by) / 2] }
  }
  const x1 = ax + width(a, after) / 2
  const x2 = bx - width(b, after) / 2 - 2
  const dx = Math.max(30, (x2 - x1) / 2)
  return {
    d: `M ${x1} ${ay} C ${x1 + dx} ${ay}, ${x2 - dx} ${by}, ${x2} ${by}`,
    mid: [(x1 + x2) / 2, (ay + by) / 2],
  }
}

const edgeSets = computed(() => [
  { name: 'old', edges: beforeEdges.map(e => ({ ...e, ...edgeGeometry(e, false) })) },
  { name: 'new', edges: afterEdges.map(e => ({ ...e, ...edgeGeometry(e, true) })) },
])
</script>

<template>
  <svg
    class="architecture-morph"
    :class="{ after }"
    viewBox="0 0 1000 430"
    role="img"
    :aria-label="after
      ? 'Architecture MEDS : les systèmes communiquent via des variables et des événements partagés.'
      : 'Architecture classique : tous les systèmes passent par le singleton GameState.'"
  >
    <defs>
      <marker id="architecture-morph-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto">
        <path d="M0 0 L10 5 L0 10 z" fill="#9aa0a6" />
      </marker>
    </defs>

    <g v-for="set in edgeSets" :key="set.name" class="edges" :class="set.name">
      <g v-for="e in set.edges" :key="`${e.from}-${e.to}`">
        <path :d="e.d" marker-end="url(#architecture-morph-arrow)" />
        <text v-if="e.label" class="edge-label" :x="e.mid[0]" :y="e.mid[1] - (e.label.length * 14) / 2 - 2">
          <tspan v-for="(line, i) in e.label" :key="line" :x="e.mid[0]" :dy="i ? 14 : 0">{{ line }}</tspan>
        </text>
      </g>
    </g>

    <g v-for="n in nodes" :key="n.id" class="node" :class="n.kind" :style="nodeStyle(n)">
      <template v-if="n.kind === 'var'">
        <path :d="cylinder(n)" />
        <ellipse cx="0" :cy="-height(n) / 2 + 7" :rx="width(n, true) / 2" ry="7" />
        <text y="10">{{ n.label }}</text>
      </template>
      <template v-else-if="n.kind === 'evt'">
        <polygon :points="flag(n)" />
        <text x="4" y="5">{{ n.label }}</text>
      </template>
      <template v-else-if="n.kind === 'core'">
        <rect x="-95" y="-45" width="190" height="90" rx="6" />
        <text class="core-title" y="-2">GameState</text>
        <text class="core-sub" y="20">(AutoLoad)</text>
      </template>
      <template v-else>
        <rect :style="rectStyle(n)" y="-18" height="36" />
        <text class="label-before" y="5">{{ n.label }}</text>
        <text v-if="n.afterLabel" class="label-after" y="5">{{ n.afterLabel }}</text>
      </template>
    </g>
  </svg>
</template>

<style scoped>
.architecture-morph {
  width: 100%;
  max-height: 390px;
  font-family: 'Inter Variable', sans-serif;
}
text {
  fill: #fff;
  font-size: 13px;
  text-anchor: middle;
}
.edges path {
  fill: none;
  stroke: #9aa0a6;
  stroke-width: 1.3;
}
.edge-label {
  font-size: 11px;
  fill: #cdcfd2;
  paint-order: stroke;
  stroke: var(--godot-bg);
  stroke-width: 4px;
  stroke-linejoin: round;
}
.system rect {
  fill: var(--godot-base);
  stroke: #cdcfd2;
  stroke-width: 1.2;
}
.core rect {
  fill: #4d3420;
  stroke: #ffb373;
  stroke-width: 2;
}
.core-title {
  font-family: 'Montserrat Variable', sans-serif;
  font-weight: 700;
  font-size: 18px;
}
.core-sub {
  fill: hsla(0, 0%, 100%, 0.75);
}
.var path,
.var ellipse {
  fill: #1f3d57;
  stroke: #478cbf;
  stroke-width: 1.5;
}
.evt polygon {
  fill: #4d2a2e;
  stroke: #fc7f7f;
  stroke-width: 1.5;
}

/* Edges fade out, nodes move, then the new edges fade in (and back). */
.node {
  transform-box: view-box;
  transform-origin: 0 0;
  transition: transform 0.8s ease-in-out 0.3s, opacity 0.6s ease 0.3s;
}
.system rect {
  transition: x 0.8s ease-in-out 0.3s, width 0.8s ease-in-out 0.3s;
}
.label-before,
.label-after {
  transition: opacity 0.4s ease 0.5s;
}
.label-after,
.after .label-before:has(+ .label-after) {
  opacity: 0;
}
.after .label-after {
  opacity: 1;
}
.edges {
  transition: opacity 0.3s ease;
}
.edges.old {
  transition-delay: 1.1s;
}
.edges.new {
  opacity: 0;
}
.after .edges.old {
  opacity: 0;
  transition-delay: 0s;
}
.after .edges.new {
  opacity: 1;
  transition-delay: 1.1s;
}

@media (prefers-reduced-motion: reduce) {
  .node,
  .system rect,
  .label-before,
  .label-after,
  .edges {
    transition: none !important;
  }
}
</style>

// Re-exports classic-game (Coin Rush) for the Web, into public/games/coin-rush/,
// where the CoinRushDemo slide component loads it.
//
// Godot binary: $GODOT if set, otherwise `godot` on PATH. If that version has no
// Web export templates installed (e.g. a version manager picked a newer patch
// release), falls back to a gdvm-installed version that has them.

import { spawnSync } from 'node:child_process'
import { existsSync, mkdirSync, readdirSync, rmSync } from 'node:fs'
import { homedir, platform } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..')
const project = join(root, 'classic-game')
const outDir = join(root, 'presentation', 'public', 'games', 'coin-rush')
const preset = 'Web'

function templatesRoot() {
  if (platform() === 'win32')
    return join(process.env.APPDATA ?? join(homedir(), 'AppData', 'Roaming'), 'Godot', 'export_templates')
  if (platform() === 'darwin')
    return join(homedir(), 'Library', 'Application Support', 'Godot', 'export_templates')
  return join(process.env.XDG_DATA_HOME ?? join(homedir(), '.local', 'share'), 'godot', 'export_templates')
}

function run(bin, args) {
  return spawnSync(bin, args, { cwd: project, encoding: 'utf8' })
}

// "4.6.2.stable.official.71f334935" -> "4.6.2.stable" (the templates folder name).
function godotVersion(bin) {
  const result = run(bin, ['--headless', '--version'])
  if (result.error || result.status !== 0)
    return null
  const line = `${result.stdout}\n${result.stderr}`.split(/\r?\n/).map(l => l.trim()).find(l => /^\d+\.\d+/.test(l))
  return line?.match(/^(\d+\.\d+(?:\.\d+)?\.[a-z0-9]+)/i)?.[1] ?? null
}

function hasWebTemplates(version) {
  return existsSync(join(templatesRoot(), version, 'web_nothreads_release.zip'))
}

function gdvmCandidates() {
  const installs = join(homedir(), '.gdvm', 'installs')
  if (!existsSync(installs))
    return []
  return readdirSync(installs).sort().reverse().flatMap((folder) => {
    const files = readdirSync(join(installs, folder))
    const macApp = join(installs, folder, 'Godot.app', 'Contents', 'MacOS', 'Godot')
    if (existsSync(macApp))
      return [macApp]
    const exe = files.find(f => /^Godot_v.*_console\.exe$/.test(f))
      ?? files.find(f => /^Godot_v.*\.(exe|x86_64|arm64)$/.test(f))
    return exe ? [join(installs, folder, exe)] : []
  })
}

function findGodot() {
  const candidates = [process.env.GODOT, platform() === 'win32' ? 'godot_console' : null, 'godot', ...gdvmCandidates()]
    .filter(Boolean)
  const tried = []
  for (const bin of candidates) {
    const version = godotVersion(bin)
    if (!version)
      continue
    if (hasWebTemplates(version))
      return { bin, version }
    tried.push(`${bin} (${version})`)
  }
  const detail = tried.length ? `Found ${tried.join(', ')}, but none has` : 'No Godot executable found with'
  console.error(`${detail} Web export templates in ${templatesRoot()}.`)
  console.error('Install them from the Godot editor (Editor > Manage Export Templates), or set GODOT to a matching executable.')
  process.exit(1)
}

function step(label, bin, args) {
  console.log(`> ${label}`)
  const result = run(bin, args)
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`
  const failed = result.error || result.status !== 0
    || output.split(/\r?\n/).some(l => /^(ERROR|SCRIPT ERROR)/.test(l.trim()))
  if (failed) {
    console.error(output || result.error)
    console.error(`${label} failed.`)
    process.exit(result.status || 1)
  }
}

const { bin, version } = findGodot()
console.log(`Using Godot ${version}: ${bin}`)

rmSync(outDir, { recursive: true, force: true })
mkdirSync(outDir, { recursive: true })

step('Importing assets', bin, ['--headless', '--path', project, '--import'])
step(`Exporting preset "${preset}"`, bin, ['--headless', '--path', project, '--export-release', preset, join(outDir, 'index.html')])

if (!existsSync(join(outDir, 'index.wasm')) || !existsSync(join(outDir, 'index.pck'))) {
  console.error(`Export finished but ${outDir} is incomplete.`)
  process.exit(1)
}
console.log(`Coin Rush exported to ${outDir}`)

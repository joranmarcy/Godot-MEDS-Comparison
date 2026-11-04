# Coin Rush — Classic Godot vs. Godot MEDS

The same small arcade game implemented twice, so the **only** difference between the two projects is the architecture:

| Folder | Approach |
| --- | --- |
| [classic-game/](./classic-game/) | Idiomatic Godot: a `GameState` **autoload singleton** owns all shared state and rules, nodes talk to it through signals and direct calls. |
| [meds-game/](./meds-game/) | [Godot MEDS](https://github.com/joranmarcy/Godot-MEDS-Sample): shared state lives in **Resource variables** (`.tres`), communication goes through **Resource events**, and each rule is a tiny node. |

Gameplay, visuals, tuning values and scene layout are identical; most scripts (player, coin, enemy, spawner, arena…) are line-for-line equivalent apart from *where they read and write state*.

## The game

Move the blue orb with **WASD / arrow keys**, collect gold coins and dodge the red enemies.

- Each coin gives `10 × combo`. The combo grows with each coin and resets after 2 s without a pickup.
- Every 200 points the level increases: enemies spawn faster and move faster.
- Touching an enemy costs 1 health (then 1 s of invulnerability). At 0 health the game is over.
- The best score is saved to disk. Press **Enter** on the game-over screen to restart.
- Sounds for coins (pitch rises with the combo), hits, level-ups and game over, plus a looping music track.
- **Esc** pauses and opens the volume settings (separate **Music** and **Sound effects** sliders, saved to disk).
- **F1** toggles an in-game debug overlay.

## Running

Requires **Godot 4.6** (MEDS also supports 4.5). Open either `project.godot` from the Godot project manager and press **F5**.

Both projects ship the same headless gameplay test (physics pickup/contact, combo scoring, levels, game over, restart reset, sounds, volume settings and pause menu):

```powershell
cd classic-game   # or meds-game
godot --headless --path . -s res://tests/test_gameplay.gd
```

The sounds are generated, not downloaded. To change them, edit [tools/generate_sounds.py](./tools/generate_sounds.py) and run `python tools/generate_sounds.py`; it writes identical files into both projects.

## Architecture at a glance

### Classic

```mermaid
flowchart LR
    Coin -- "GameState.collect_coin()" --> GS[(GameState autoload<br/>health, score, combo, level,<br/>high_score, is_running<br/>+ all the rules)]
    Player -- "GameState.damage_player()" --> GS
    Enemy -- "get_first_node_in_group('player')" --> Player
    GS -- signals --> HUD
    GS -- signals --> GameOverScreen
    GS -- signals --> ScreenFlash & ScreenShake & DebugOverlay
    GS -- "signals + reads combo" --> SoundEffects
    Spawner -- reads level / is_running --> GS
    SettingsMenu -- "sets volumes" --> ST[(Settings autoload<br/>music/sfx volume<br/>+ save/load + buses)]
    ST -- signals --> SettingsMenu
```

### MEDS

```mermaid
flowchart LR
    Coin -- raises --> CC([coin-collected])
    Player -- raises --> PH([player-hit])
    Player -- writes --> POS[(player-position)]
    POS -- read by --> Enemy
    CC --> ScoreKeeper -- writes --> SCORE[(score)] & COMBO[(combo)]
    SCORE --> LevelFromScore -- writes --> LEVEL[(level)]
    SCORE --> HighScoreTracker -- writes --> HIGH[(high-score)]
    PH --> DamageOnPlayerHit -- writes --> HEALTH[(player-health)]
    HEALTH --> GameOverOnZeroHealth -- writes --> RUN[(game-running)]
    GameOverOnZeroHealth -- raises --> GO([game-over])
    PH --> ScreenFlash & ScreenShake
    SCORE & COMBO & LEVEL & HIGH & HEALTH --> HUD["HUD (addon label / progress-bar bindings)"]
    RUN --> GameOverScreen
    CC --> CoinSound
    COMBO -. pitch .-> CoinSound
    PH --> HitSound
    LEVEL --> LevelUpSound
    GO --> GameOverSound
    RUN --> MusicWhileRunning
    SettingsMenu["SettingsMenu (addon slider bindings)"] -- writes --> VOL[(music-volume<br/>sfx-volume)]
    VOL --> BusVolume["MusicVolume / SfxVolume bus bindings"]
```

### Where things live

| Concern | Classic | MEDS |
| --- | --- | --- |
| Health, score, combo, level, high score | Properties of [game_state.gd](./classic-game/scripts/game_state.gd) | One `.tres` each in [game/variables/](./meds-game/game/variables/) |
| Tuning (player speed, enemy speed, coin value, combo window, damage) | `const`s and per-node `@export`s | `.tres` variables, editable in the inspector and **at runtime** |
| Scoring / combo rule | `GameState.collect_coin()` | [score_keeper.gd](./meds-game/game/scripts/score_keeper.gd) node |
| Level rule | Setter of `GameState.score` | [level_from_score.gd](./meds-game/game/scripts/level_from_score.gd) node |
| High score rule + save | Setter of `GameState.score` + `_save_high_score()` | [high_score_tracker.gd](./meds-game/game/scripts/high_score_tracker.gd) + `save_to_device = true` on the resource |
| Damage rule | `GameState.damage_player()` | [damage_on_event.gd](./meds-game/game/scripts/damage_on_event.gd) node |
| Game-over rule | `GameState.damage_player()` → `_end_game()` | [game_over_on_zero_health.gd](./meds-game/game/scripts/game_over_on_zero_health.gd) node |
| Enemy → player position | `get_tree().get_first_node_in_group("player")` | Reads `player-position.tres` |
| HUD | Custom [hud.gd](./classic-game/scripts/hud.gd) (5 signal handlers) | **No custom script**: MEDS `variable-driven-label` / `variable-driven-progress-bar` |
| Game-over screen | Custom script listening to `GameState.game_over` | `bool_to_visibility` + MEDS labels + restart button |
| Session reset on restart | `GameState.start_game()` called from `main.gd` | `ResetSessionVariables` node listing the variables to reset |
| Debug overlay | Hand-written field by field | Generic: takes `Array[BaseVariable]` / `Array[Event]` |
| Sounds | [sound_effects.gd](./classic-game/scripts/sound_effects.gd) connects to 4 `GameState` signals and reads `GameState.combo` | Reusable players: [play_sound_on_event.gd](./meds-game/game/scripts/play_sound_on_event.gd), [play_sound_on_increase.gd](./meds-game/game/scripts/play_sound_on_increase.gd), [play_while_true.gd](./meds-game/game/scripts/play_while_true.gd), wired to events/variables in [audio.tscn](./meds-game/game/scenes/audio.tscn) |
| Volume settings | Second autoload, [settings.gd](./classic-game/scripts/settings.gd): one property + signal + save/load code per setting; [settings_menu.gd](./classic-game/scripts/settings_menu.gd) wires each slider both ways | `music-volume.tres` / `sfx-volume.tres` (`save_to_device`), MEDS `variable-driven-slider`, [bind_float_to_bus_volume.gd](./meds-game/game/scripts/bind_float_to_bus_volume.gd) |

## How MEDS improves *understanding*

1. **The scene tree documents the rules.** Open [main.tscn](./meds-game/game/scenes/main.tscn): the `GameRules` node lists every rule of the game (`ScoreKeeper`, `LevelFromScore`, `HighScoreTracker`, `DamageOnPlayerHit`, `GameOverOnZeroHealth`). Select one and the inspector shows exactly which variables/events it reads and writes. In the classic project, the same knowledge is spread inside setters and methods of a single script — e.g. the level and high-score rules are hidden in the `score` setter.
2. **Dependencies are explicit.** A MEDS script can only touch what is assigned to its exports. A classic script can reach `GameState.anything` from anywhere, so you need to read every script to know who depends on what.
3. **Scenes are self-contained.** `player.tscn`, `enemy.tscn`, `hud.tscn` reference resources, not other nodes or an autoload, so each can be opened and run on its own (F6). Enemies no longer need to find the player node.
4. **State has a name and an icon.** Health is `player-health.tres` (an `IntVariable` clamped to 0–5), visible in the FileSystem dock with a MEDS icon, instead of a field inside a 140-line singleton.

## How MEDS improves *debugging* — side-by-side scenarios

### 1. "Who changed the score, and what reacted to it?"

**Classic:** put a breakpoint or `print` in the `score` setter, read the call stack, then search the project for `score_changed` to guess who listens.

**MEDS:** tick **debug_logs** on `score.tres` (in the inspector, or live from the *Variable Values* bottom panel) and collect a coin:

```text
--- Debug: Value Change Detected ---
Resource: res://game/variables/score runtime value changed to: 10
Caller node: /Main/GameRules/ScoreKeeper
Stack trace:
  ...
  at res://addons/godot_meds_core/scripts/variables/int-variable.gd:30 (set_value)
  at res://game/scripts/score_keeper.gd:30 (_on_coin_collected)
  at res://addons/godot_meds_core/scripts/events/event.gd:23 (raise_event)
  at res://game/scripts/coin.gd:25 (_on_body_entered)
- /Main/GameRules/LevelFromScore reacted to value change
- /Main/GameRules/HighScoreTracker reacted to value change
- /Main/HUD/TopBar/Margin/HBox/ScoreLabel reacted to value change
- /Main/GameOverScreen/Root/Center/Panel/Margin/VBox/FinalScoreLabel reacted to value change
- /Main/DebugOverlay reacted to value change
--- End of Debug ---
```

You get the writer, the full causal chain (coin → event → rule → variable) and every listener, with node paths that are clickable in the Output panel. This is why every rule in the MEDS project calls `set_value(new_value, self)`: the `caller` argument is what fills in *Caller node*.

### 2. "Tune the game while playing"

**Classic:** enemy speed is an `@export` on *each enemy instance*; changing it in the Remote tree affects one enemy only, and `COIN_VALUE` / `COMBO_WINDOW` are constants that require a restart.

**MEDS:** open the **Variable Values** bottom panel while the game runs and edit `player-speed`, `enemy-speed`, `coin-value`, `combo-window` or `player-damage`. Every system using the variable picks the new value up immediately. The same goes for `music-volume` / `sfx-volume`: the in-game sliders move as you edit them.

### 3. "Test the game-over flow without playing for 5 minutes"

**Classic:** there is no editor UI to call `GameState.damage_player()`, so you add a temporary debug key. Setting `health` to 0 in the Remote tree updates the HUD (the setter runs) but the game-over screen never appears: the rule lives in `damage_player()`, not in the data.

**MEDS:** in the **Events** bottom panel, raise `player-hit` five times — or set `player-health` to `0` in **Variable Values**. Because the game-over rule *listens to the data*, both paths trigger the real game-over flow, exactly as in gameplay.

### 4. "Is it safe to rename or remove this piece of state?"

**Classic:** text-search `GameState.combo` / `combo_changed` and hope nobody used `GameState.get("combo")` or connected by string.

**MEDS:** right-click `combo.tres` in the FileSystem dock → **Log references** to list every scene, script and resource that uses it.

### 5. In-game overlay (works in exported builds)

Press **F1** in both games.

- Classic [debug_overlay.gd](./classic-game/scripts/debug_overlay.gd) hard-codes each field and signal; every new piece of state must be added by hand (adding the volume settings meant editing the script and reading a second singleton).
- MEDS [debug_overlay.gd](./meds-game/game/scripts/debug_overlay.gd) knows nothing about the game: it iterates over the variables/events dragged into its arrays, highlights values as they change and timestamps every event raise. It can be dropped into any MEDS project unchanged; the volumes were added by dragging two resources into its array.

## Trade-offs (the honest part)

- **More files.** MEDS adds 14 variable and 3 event resources and several small rule scripts. For a jam-sized game the classic singleton is quicker to write.
- **Wiring lives in the inspector.** Dependencies are in `.tscn` files rather than in code, so plain text search is less useful — which is precisely what the MEDS reference tracking and debug logs compensate for.
- **Resources outlive scenes.** A variable keeps its value while anything references it (including across `reload_current_scene()`), so the start of a session must be explicit — here via the `ResetSessionVariables` node, which must stay first in `main.tscn`. The classic version has the same issue with its autoload (`GameState.start_game()`).
- **Listener order.** Several listeners on the same variable or event run in connection order. Rules that depend on each other (score *then* combo) are kept in one node (`ScoreKeeper`) to stay deterministic. The coin sound reads `combo` for its pitch, so it relies on sitting below `GameRules` in the scene tree (it connects later, so it plays after the combo has been increased).
- **High-frequency variables.** `player-position` changes every physics frame; avoid enabling `debug_logs` on it.
- **Saved variables write on every change.** With `save_to_device`, dragging a volume slider rewrites `user://settings.cfg` on each step. The classic `Settings` autoload does the same here, but it could be changed to save once when the menu closes.

## Project structure

```text
tools/generate_sounds.py     generates the .wav files for both projects
classic-game/
  scripts/game_state.gd      autoload: all state + rules
  scripts/settings.gd        autoload: volume settings + save/load
  scripts/*.gd               player, coin, enemy, spawner, hud, game_over_screen, effects, sounds, settings menu, overlay
  scenes/*.tscn
  sounds/*.wav
  tests/test_gameplay.gd
meds-game/
  addons/godot_meds_core/    MEDS runtime (copied from Godot-MEDS-Sample)
  addons/godot_meds_editor/  MEDS editor tools (docks, reference tracking)
  game/variables/*.tres      shared state, tuning & volume settings
  game/events/*.tres         coin-collected, player-hit, game-over
  game/scripts/*.gd          gameplay nodes + one script per rule + reusable sound/volume bindings
  game/scenes/*.tscn
  game/sounds/*.wav
  tests/test_gameplay.gd
```

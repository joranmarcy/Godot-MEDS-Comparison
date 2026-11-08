# Coin Rush — Classic version

Idiomatic Godot implementation: one autoload singleton, [`GameState`](./scripts/game_state.gd), owns every piece of shared state (health, score, combo, level, high score, running flag) **and** every rule that changes it (scoring, combo timeout, levelling, damage, game over, high-score save). Other nodes call its methods and connect to its signals. A second autoload, [`Settings`](./scripts/settings.gd), owns the saved music/SFX volumes and applies them to the `Music` and `SFX` audio buses.

See the [comparison guide](../README.md) for the side-by-side with the MEDS version.

The player publishes its global position to `GameState.player_position` at startup
and after each movement step. Enemies read that value from the singleton rather
than looking up the player node. Reloading the scene publishes the new player's
starting position before gameplay resumes.

- Main scene: [scenes/main.tscn](./scenes/main.tscn)
- Controls: WASD / arrows / gamepad / touch drag to move, Esc or the on-screen II button to pause (volume, debug overlay), F1 debug overlay, Restart button after game over
- Test: `godot --path . -s res://tests/test_gameplay.gd` (add `--headless` to skip the touch checks)

## Web demo in the presentation

Slide 10 of the [Slidev deck](../presentation/slides.md) embeds a local Web export.
With Godot 4.6.2 and its export templates installed, run from the repository root:
Use the matching Godot executable directly if a version manager selects a newer
4.6 release without its templates.

```powershell
New-Item -ItemType Directory -Force presentation\public\games\coin-rush
godot_console.exe --headless --path classic-game --editor --import
godot_console.exe --headless --path classic-game --export-release Web ..\presentation\public\games\coin-rush\index.html
cd presentation
npm run dev
```

The Web preset uses Compatibility rendering (Web only) and no threads, so Slidev
does not need cross-origin isolation headers. Generated game files are kept in
the deck's public assets; re-export after changing the game. Serve the deck over
HTTP (localhost) or HTTPS, not `file://`.

Click **Jouer à Coin Rush**, then inside the game to give it keyboard focus.
**Arrêter** returns control to Slidev. Leaving the slide also unloads the game.

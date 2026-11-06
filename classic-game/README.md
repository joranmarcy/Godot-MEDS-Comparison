# Coin Rush — Classic version

Idiomatic Godot implementation: one autoload singleton, [`GameState`](./scripts/game_state.gd), owns every piece of shared state (health, score, combo, level, high score, running flag) **and** every rule that changes it (scoring, combo timeout, levelling, damage, game over, high-score save). Other nodes call its methods and connect to its signals. A second autoload, [`Settings`](./scripts/settings.gd), owns the saved music/SFX volumes and applies them to the `Music` and `SFX` audio buses.

See the [comparison guide](../README.md) for the side-by-side with the MEDS version.

- Main scene: [scenes/main.tscn](./scenes/main.tscn)
- Controls: WASD / arrows / gamepad / touch drag to move, Esc or the on-screen II button to pause (volume, debug overlay), F1 debug overlay, Restart button after game over
- Test: `godot --path . -s res://tests/test_gameplay.gd` (add `--headless` to skip the touch checks)

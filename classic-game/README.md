# Coin Rush — Classic version

Idiomatic Godot implementation: one autoload singleton, [`GameState`](./scripts/game_state.gd), owns every piece of shared state (health, score, combo, level, high score, running flag) **and** every rule that changes it (scoring, combo timeout, levelling, damage, game over, high-score save). Other nodes call its methods and connect to its signals.

See the [comparison guide](../README.md) for the side-by-side with the MEDS version.

- Main scene: [scenes/main.tscn](./scenes/main.tscn)
- Controls: WASD / arrows to move, F1 debug overlay, Enter to restart after game over
- Test: `godot --headless --path . -s res://tests/test_gameplay.gd`

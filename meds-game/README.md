# Coin Rush — MEDS version

The same game built with [Godot MEDS](https://github.com/joranmarcy/Godot-MEDS-Sample) (both plugins are enabled in `project.godot`).

- **State** → one Resource per value in [game/variables/](./game/variables/) (`IntVariable`, `FloatVariable`, `BoolVariable`, `Vector2Variable`).
- **Communication** → Resource events in [game/events/](./game/events/): `coin-collected`, `player-hit`, `game-over`.
- **Rules** → one small node each under `Main/GameRules` in [main.tscn](./game/scenes/main.tscn).
- **UI** → MEDS addon bindings (`variable-driven-label`, `variable-driven-progress-bar`, `variable-driven-slider`), no HUD script.
- **Audio** → `Main/Audio`: sound players driven by events/variables, and `music-volume` / `sfx-volume` variables (saved with `save_to_device`) bound to the `Music` and `SFX` buses. Esc opens the pause menu with the volume sliders.
- **Session start** → `Main/ResetSessionVariables` (must stay the first child of `Main`) resets the listed variables to their `initial_value`.

See the [comparison guide](../README.md) for debugging walkthroughs.

## Debugging cheat sheet

| Goal | How |
| --- | --- |
| Watch / edit values live | Run the game, open the **Variable Values** bottom panel |
| Raise an event manually / watch raises | **Events** bottom panel |
| See who changed a value + who reacted | Enable `debug_logs` on the variable (inspector or Variable Values panel), check the Output |
| Find every usage of a variable/event | Right-click the `.tres` in the FileSystem dock → **Log references** |
| Inspect state in an exported build | Press **F1** (generic overlay) |

When writing a variable from code, pass the caller (`variable.set_value(x, self)`) so debug logs can tell you which node made the change.

Test: `godot --headless --path . -s res://tests/test_gameplay.gd`

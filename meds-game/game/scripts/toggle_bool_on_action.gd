extends Node
## Flips a BoolVariable each time an input action is pressed (keyboard, gamepad...).
## Set process_mode to Always if it must work while the game is paused.

@export var action: StringName
@export var variable: BoolVariable


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(action):
		variable.set_value(not variable.value, self)
		get_viewport().set_input_as_handled()

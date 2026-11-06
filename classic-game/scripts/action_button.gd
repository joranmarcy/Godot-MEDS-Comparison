extends Button
## On-screen button that triggers an input action, as if its key had been pressed.
## Lets touch players reach keyboard-only features (pause, debug overlay) without extra wiring.

@export var action: StringName


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	for is_pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = is_pressed
		Input.parse_input_event(event)

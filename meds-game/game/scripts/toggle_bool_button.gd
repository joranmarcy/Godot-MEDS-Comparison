extends Button
## Flips a BoolVariable when pressed (on-screen pause, resume, debug overlay...).

@export var variable: BoolVariable


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	variable.set_value(not variable.value, self)

extends AudioStreamPlayer
## Plays this stream while `variable` is true and stops it when it becomes false.

@export var variable: BoolVariable


func _ready() -> void:
	variable.value_changed.connect(_on_value_changed)
	_on_value_changed(variable.value)


func _on_value_changed(new_value: bool) -> void:
	if new_value and not playing:
		play()
	elif not new_value:
		stop()

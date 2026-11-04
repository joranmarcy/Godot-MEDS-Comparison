extends AudioStreamPlayer
## Plays this sound whenever `variable` goes up (e.g. level up). Resets do not trigger it.

@export var variable: IntVariable

var _last_value: int


func _ready() -> void:
	_last_value = variable.value
	variable.value_changed.connect(_on_value_changed)


func _on_value_changed(new_value: int) -> void:
	if new_value > _last_value:
		play()
	_last_value = new_value

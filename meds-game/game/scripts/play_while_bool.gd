extends AudioStreamPlayer
## Plays this stream while `variable` equals `play_while` and stops it otherwise
## (e.g. music that plays until `game-over` becomes true).

@export var variable: BoolVariable
@export var play_while: bool = true


func _ready() -> void:
	variable.value_changed.connect(_on_value_changed)
	_on_value_changed(variable.value)


func _on_value_changed(new_value: bool) -> void:
	if new_value == play_while:
		if not playing:
			play()
	else:
		stop()

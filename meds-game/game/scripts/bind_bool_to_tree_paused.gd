extends Node
## Pauses the SceneTree while `variable` is true.
##
## The variable is the single source of truth: pause the game by writing to it
## (from code, a button, or the Variable Values panel), never by setting
## `get_tree().paused` directly. Needs process_mode Always to keep listening while paused.

@export var variable: BoolVariable


func _ready() -> void:
	variable.value_changed.connect(_on_value_changed)
	_on_value_changed(variable.value)


func _on_value_changed(new_value: bool) -> void:
	get_tree().paused = new_value

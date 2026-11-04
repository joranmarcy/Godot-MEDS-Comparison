extends Node
## Rule: when `health` reaches zero, stop the game and raise `game_over`.

@export var health: IntVariable
@export var game_running: BoolVariable
@export var game_over: Event


func _ready() -> void:
	health.value_changed.connect(_on_health_changed)


func _on_health_changed(new_health: int) -> void:
	if new_health > 0 or not game_running.value:
		return
	game_running.set_value(false, self)
	game_over.raise_event()

extends Node
## Rule: when `health` reaches zero, the game is over. Sets `game_over` and raises `player_died`.

@export var health: IntVariable
@export var game_over: BoolVariable
@export var player_died: Event


func _ready() -> void:
	health.value_changed.connect(_on_health_changed)


func _on_health_changed(new_health: int) -> void:
	if new_health > 0 or game_over.value:
		return
	game_over.set_value(true, self)
	player_died.raise_event()

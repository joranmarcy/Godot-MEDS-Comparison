extends Node

@export var scene: PackedScene
@export var container: Node2D
@export var group_name: StringName
@export var max_alive: int = 5
@export var base_interval: float = 1.5
@export var interval_decrease_per_level: float = 0.0
@export var min_interval: float = 0.3
## If true, spawns on the arena border; otherwise anywhere inside the arena.
@export var spawn_on_edges: bool = false
@export var margin: float = 40.0

var _time_left := 0.0


func _process(delta: float) -> void:
	if not GameState.is_running or scene == null or container == null:
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	_time_left = maxf(min_interval, base_interval - (GameState.level - 1) * interval_decrease_per_level)
	if get_tree().get_nodes_in_group(group_name).size() >= max_alive:
		return
	var instance := scene.instantiate() as Node2D
	instance.position = _random_position()
	container.add_child(instance)


func _random_position() -> Vector2:
	var arena := container.get_viewport_rect()
	if not spawn_on_edges:
		var inner := arena.grow(-margin)
		return Vector2(randf_range(inner.position.x, inner.end.x), randf_range(inner.position.y, inner.end.y))
	match randi() % 4:
		0:
			return Vector2(randf_range(0, arena.size.x), -margin * 0.5)
		1:
			return Vector2(randf_range(0, arena.size.x), arena.size.y + margin * 0.5)
		2:
			return Vector2(-margin * 0.5, randf_range(0, arena.size.y))
		_:
			return Vector2(arena.size.x + margin * 0.5, randf_range(0, arena.size.y))

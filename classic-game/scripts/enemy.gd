extends Area2D

@export var base_speed: float = 110.0
@export var speed_per_level: float = 15.0
@export var size: float = 14.0
@export var color: Color = Color(1.0, 0.3, 0.35)

var _player: Node2D


func _ready() -> void:
	add_to_group("enemies")
	# The enemy has to find the player node in the tree to know where to go.
	_player = get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	if not GameState.is_running or _player == null:
		return
	var speed := base_speed + (GameState.level - 1) * speed_per_level
	global_position = global_position.move_toward(_player.global_position, speed * delta)
	rotation += delta * 3.0


func explode() -> void:
	queue_free()


func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(0, -size), Vector2(size, 0), Vector2(0, size), Vector2(-size, 0),
	])
	draw_colored_polygon(points, color)

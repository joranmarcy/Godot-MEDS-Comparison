extends Area2D

@export var base_speed: float = 110.0
@export var speed_per_level: float = 15.0
@export var size: float = 14.0
@export var color: Color = Color(1.0, 0.3, 0.35)

func _ready() -> void:
	add_to_group("enemies")


func _physics_process(delta: float) -> void:
	if not GameState.is_running:
		return
	var speed := base_speed + (GameState.level - 1) * speed_per_level
	global_position = global_position.move_toward(GameState.player_position, speed * delta)
	rotation += delta * 3.0


func explode() -> void:
	queue_free()


func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(0, -size), Vector2(size, 0), Vector2(0, size), Vector2(-size, 0),
	])
	draw_colored_polygon(points, color)

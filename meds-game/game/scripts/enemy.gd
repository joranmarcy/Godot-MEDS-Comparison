extends Area2D
## Chases whatever position is stored in `target_position` (no node lookup needed).

@export var target_position: Vector2Variable
@export var base_speed: FloatVariable
@export var level: IntVariable
@export var game_over: BoolVariable
@export var speed_per_level: float = 15.0
@export var size: float = 14.0
@export var color: Color = Color(1.0, 0.3, 0.35)


func _ready() -> void:
	add_to_group("enemies")


func _physics_process(delta: float) -> void:
	if game_over.value:
		return
	var speed := base_speed.value + (level.value - 1) * speed_per_level
	global_position = global_position.move_toward(target_position.value, speed * delta)
	rotation += delta * 3.0


func explode() -> void:
	queue_free()


func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(0, -size), Vector2(size, 0), Vector2(0, size), Vector2(-size, 0),
	])
	draw_colored_polygon(points, color)

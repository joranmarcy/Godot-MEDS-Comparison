extends Node2D

@export var cell_size: float = 64.0
@export var grid_color: Color = Color(1, 1, 1, 0.04)
@export var border_color: Color = Color(0.35, 0.75, 1.0, 0.5)


func _ready() -> void:
	# The arena fills the screen, which changes size on rotation, window resize or phones with other aspect ratios.
	get_viewport().size_changed.connect(queue_redraw)


func _draw() -> void:
	var arena := get_viewport_rect()
	var x := 0.0
	while x <= arena.size.x:
		draw_line(Vector2(x, 0), Vector2(x, arena.size.y), grid_color)
		x += cell_size
	var y := 0.0
	while y <= arena.size.y:
		draw_line(Vector2(0, y), Vector2(arena.size.x, y), grid_color)
		y += cell_size
	draw_rect(arena, border_color, false, 4.0)

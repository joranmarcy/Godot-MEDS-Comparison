extends ColorRect

@export var flash_color: Color = Color(1, 0.2, 0.2, 0.35)
@export var duration: float = 0.25


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(flash_color, 0.0)
	GameState.player_hit.connect(_on_player_hit)


func _on_player_hit() -> void:
	color = flash_color
	create_tween().tween_property(self, "color:a", 0.0, duration)

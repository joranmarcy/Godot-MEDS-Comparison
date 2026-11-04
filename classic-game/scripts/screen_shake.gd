extends Camera2D

@export var strength: float = 12.0
@export var duration: float = 0.3

var _time_left := 0.0


func _ready() -> void:
	GameState.player_hit.connect(_on_player_hit)


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		offset = Vector2.ZERO
		return
	_time_left -= delta
	var current_strength := strength * (_time_left / duration)
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * current_strength


func _on_player_hit() -> void:
	_time_left = duration

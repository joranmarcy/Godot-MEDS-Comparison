extends Area2D
## Raises `coin_collected` when the player touches it. Scoring is someone else's job.

@export var coin_collected: Event
@export var game_over: BoolVariable
@export var radius: float = 10.0
@export var color: Color = Color(1.0, 0.82, 0.2)

var _time := 0.0


func _ready() -> void:
	add_to_group("coins")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or game_over.value:
		return
	coin_collected.raise_event()
	queue_free()


func _draw() -> void:
	var pulse := 1.0 + 0.12 * sin(_time * 6.0)
	draw_circle(Vector2.ZERO, radius * pulse, color)
	draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.3, Color(1, 1, 1, 0.6))

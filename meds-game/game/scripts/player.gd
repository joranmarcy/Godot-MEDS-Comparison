extends CharacterBody2D
## Moves the player and raises `player_hit` when an enemy touches it.
##
## The player does not know about health, score, UI or game over: it only reads
## its speed from a shared variable and publishes its position so enemies can
## chase it without holding a reference to this node.

@export var move_speed: FloatVariable
@export var position_variable: Vector2Variable
@export var game_running: BoolVariable
@export var player_hit: Event
@export var radius: float = 18.0
@export var invulnerability_time: float = 1.0
@export var color: Color = Color(0.35, 0.75, 1.0)
## Start in the middle of the screen, whatever its aspect ratio (phones are often wider than 16:9).
@export var start_at_viewport_center: bool = true

@onready var _hurtbox: Area2D = $Hurtbox

var _invulnerable_left := 0.0


func _ready() -> void:
	add_to_group("player")
	if start_at_viewport_center:
		global_position = get_viewport_rect().get_center()
	_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	position_variable.set_value(global_position, self)


func _physics_process(delta: float) -> void:
	_update_blink(delta)
	if not game_running.value:
		velocity = Vector2.ZERO
		return
	velocity = _read_move_input() * move_speed.value
	move_and_slide()
	var arena := get_viewport_rect().grow(-radius)
	global_position = global_position.clamp(arena.position, arena.end)
	position_variable.set_value(global_position, self)


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemies"):
		return
	area.call("explode")
	if _invulnerable_left > 0.0 or not game_running.value:
		return
	_invulnerable_left = invulnerability_time
	player_hit.raise_event()


func _update_blink(delta: float) -> void:
	if _invulnerable_left <= 0.0:
		modulate.a = 1.0
		return
	_invulnerable_left -= delta
	modulate.a = 0.3 if int(_invulnerable_left * 12.0) % 2 == 0 else 1.0


func _read_move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color.lightened(0.5), 3.0)

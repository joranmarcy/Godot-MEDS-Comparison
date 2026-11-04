extends CharacterBody2D

@export var speed: float = 320.0
@export var radius: float = 18.0
@export var invulnerability_time: float = 1.0
@export var color: Color = Color(0.35, 0.75, 1.0)

@onready var _hurtbox: Area2D = $Hurtbox

var _invulnerable_left := 0.0


func _ready() -> void:
	add_to_group("player")
	_hurtbox.area_entered.connect(_on_hurtbox_area_entered)


func _physics_process(delta: float) -> void:
	_update_blink(delta)
	if not GameState.is_running:
		velocity = Vector2.ZERO
		return
	velocity = _read_move_input() * speed
	move_and_slide()
	var arena := get_viewport_rect().grow(-radius)
	global_position = global_position.clamp(arena.position, arena.end)


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemies"):
		return
	area.call("explode")
	if _invulnerable_left > 0.0 or not GameState.is_running:
		return
	_invulnerable_left = invulnerability_time
	GameState.damage_player(1)


func _update_blink(delta: float) -> void:
	if _invulnerable_left <= 0.0:
		modulate.a = 1.0
		return
	_invulnerable_left -= delta
	modulate.a = 0.3 if int(_invulnerable_left * 12.0) % 2 == 0 else 1.0


func _read_move_input() -> Vector2:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	direction.x += float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	direction.y += float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	return direction.limit_length(1.0)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color.lightened(0.5), 3.0)

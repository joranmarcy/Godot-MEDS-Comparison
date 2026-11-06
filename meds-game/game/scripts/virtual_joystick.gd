extends Control
## Floating virtual joystick: touch anywhere inside this control and drag to move.
##
## It presses the regular input actions (with analog strength), so gameplay code
## reads touch exactly like keyboard or gamepad input and never knows touch exists.

@export var action_left: StringName = &"move_left"
@export var action_right: StringName = &"move_right"
@export var action_up: StringName = &"move_up"
@export var action_down: StringName = &"move_down"
## Drag distance (in pixels) for full speed. The base follows the finger beyond it.
@export var radius: float = 80.0
@export_range(0.0, 1.0) var dead_zone: float = 0.15
@export var base_color: Color = Color(1, 1, 1, 0.12)
@export var knob_color: Color = Color(1, 1, 1, 0.35)

var _touch_index := -1
var _origin := Vector2.ZERO
var _knob_offset := Vector2.ZERO
var _pressed_actions: Dictionary = {}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_origin = event.position
			_set_knob(Vector2.ZERO)
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_release()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		var offset: Vector2 = event.position - _origin
		if offset.length() > radius:
			_origin += offset - offset.limit_length(radius)
			offset = offset.limit_length(radius)
		_set_knob(offset)
		accept_event()


func _notification(what: int) -> void:
	# Never leave a direction pressed when the game pauses or the scene is reloaded mid-drag.
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		_release()


func _release() -> void:
	_touch_index = -1
	_set_knob(Vector2.ZERO)


func _set_knob(offset: Vector2) -> void:
	_knob_offset = offset
	var direction := offset / radius
	if direction.length() < dead_zone:
		direction = Vector2.ZERO
	_set_action_strength(action_left, -direction.x)
	_set_action_strength(action_right, direction.x)
	_set_action_strength(action_up, -direction.y)
	_set_action_strength(action_down, direction.y)
	queue_redraw()


func _set_action_strength(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
		_pressed_actions[action] = true
	elif _pressed_actions.has(action):
		Input.action_release(action)
		_pressed_actions.erase(action)


func _draw() -> void:
	if _touch_index == -1:
		return
	draw_circle(_origin, radius, base_color)
	draw_arc(_origin, radius, 0.0, TAU, 48, knob_color, 2.0)
	draw_circle(_origin + _knob_offset, radius * 0.45, knob_color)

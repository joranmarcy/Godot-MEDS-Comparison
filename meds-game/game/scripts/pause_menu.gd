extends CanvasLayer
## Pause menu (toggle with Esc). Volume sliders are bound to MEDS variables in the scene, not here.

@export var focus_on_open: Control

@onready var _root: Control = $Root


func _ready() -> void:
	_root.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_set_open(not _root.visible)
		get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	_root.visible = open
	get_tree().paused = open
	if open and focus_on_open != null:
		focus_on_open.grab_focus()
	else:
		get_viewport().gui_release_focus()

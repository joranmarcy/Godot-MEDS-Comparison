extends Node
## Gives keyboard/gamepad focus to `focus_target` while `variable` is true (e.g. a menu is open),
## and releases focus when it becomes false.

@export var variable: BoolVariable
@export var focus_target: Control


func _ready() -> void:
	variable.value_changed.connect(_on_value_changed)


func _on_value_changed(new_value: bool) -> void:
	if new_value and focus_target != null:
		focus_target.grab_focus.call_deferred()
	elif not new_value:
		get_viewport().gui_release_focus()

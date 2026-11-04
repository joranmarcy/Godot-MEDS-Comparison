extends Button
## Reloads the current scene when pressed; grabs focus when it becomes visible.


func _ready() -> void:
	pressed.connect(_on_pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		grab_focus.call_deferred()


func _on_pressed() -> void:
	get_tree().call_deferred("reload_current_scene")

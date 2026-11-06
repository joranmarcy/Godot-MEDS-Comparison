extends SceneTree
## Tests BaseVariable's "reset_on" behaviour across real scene changes.
## Run: godot --headless --path . -s res://addons/godot_meds_core/scripts/tests/scene_load_reset_test_runner.gd

const SCENE_SCRIPT_SOURCE := """
extends Node
var value_seen_in_ready: Variant
func _ready() -> void:
	value_seen_in_ready = (get_meta(&"variable") as BaseVariable).call(&"_get_value_variant")
"""

var _checks: int = 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var on_scene_load := _int_variable(5, BaseVariable.RESET_ON_SCENE_LOAD)
	var on_app_start := _int_variable(5, BaseVariable.RESET_ON_APPLICATION_START)
	var saved := _int_variable(5, BaseVariable.RESET_ON_SCENE_LOAD)
	saved.set("save_to_device", true)
	var position := Vector2Variable.new()
	position.initial_value = Vector2(1, 2)
	# Variables register for the reset once they have been reported (next frame).
	await process_frame
	await process_frame

	var scene := _scene_using(on_scene_load)
	change_scene_to_packed(scene)
	await process_frame
	await process_frame

	on_scene_load.value = 1
	on_app_start.value = 1
	position.value = Vector2(9, 9)
	saved.set("_value", 1)  # Bypass set_value so the test never writes user://settings.cfg.
	var changes: Array = []
	on_scene_load.value_changed.connect(func(v: int) -> void: changes.append(v))

	# Same packed scene again: the old scene keeps the variable alive the whole time, which is
	# exactly the reload_current_scene() case where a reload alone would not reset it.
	change_scene_to_packed(scene)
	await process_frame
	await process_frame

	_expect(on_scene_load.value == 5, "On Scene Load variable is back to its initial value after a scene change (got %s)" % on_scene_load.value)
	_expect(current_scene.get("value_seen_in_ready") == 5, "the new scene's _ready() already sees the initial value (got %s)" % current_scene.get("value_seen_in_ready"))
	_expect(changes == [5], "the reset emits value_changed once (got %s)" % [changes])
	_expect(position.value == Vector2(1, 2), "non-numeric variables reset too (got %s)" % position.value)
	_expect(on_app_start.value == 1, "On Application Start variable keeps its value (got %s)" % on_app_start.value)
	_expect(saved.value == 1, "save_to_device variable keeps its value (got %s)" % saved.value)

	on_scene_load.value = 2
	var overlay := Node.new()
	root.add_child(overlay)
	await process_frame
	_expect(on_scene_load.value == 2, "adding a non-scene node to the root does not reset (got %s)" % on_scene_load.value)
	overlay.queue_free()

	# A freed variable must simply drop out of the registry.
	var temporary := _int_variable(3, BaseVariable.RESET_ON_SCENE_LOAD)
	await process_frame
	await process_frame
	temporary = null
	change_scene_to_packed(scene)
	await process_frame
	await process_frame
	_expect(on_scene_load.value == 5, "scene changes keep working after a registered variable was freed")

	_finish()


func _int_variable(initial: int, reset_on: String) -> IntVariable:
	var variable := IntVariable.new()
	variable.reset_on = reset_on
	variable.initial_value = initial
	return variable


func _scene_using(variable: BaseVariable) -> PackedScene:
	var script := GDScript.new()
	script.source_code = SCENE_SCRIPT_SOURCE
	script.reload()
	var node := Node.new()
	node.set_script(script)
	node.set_meta(&"variable", variable)
	var packed := PackedScene.new()
	packed.pack(node)
	node.free()
	return packed


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS " + message)
	else:
		_failures.append(message)
		printerr("FAIL " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("Scene load reset tests passed (%d checks)." % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	printerr("Scene load reset tests failed (%d/%d checks)." % [_failures.size(), _checks])
	quit(1)

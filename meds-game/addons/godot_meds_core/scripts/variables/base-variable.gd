@icon("res://addons/godot_meds_core/icons/BaseVariable.svg")
extends Resource
class_name BaseVariable

static var _runtime_value_cache: Dictionary = {}
static var _scene_load_variables: Array[WeakRef] = []
static var _scene_load_hooked := false
const RESET_ON_SCENE_LOAD := "On Scene Load"
const RESET_ON_APPLICATION_START := "On Application Start"

## If true, logs value changes and related runtime info for this variable.
@export var debug_logs: bool = false
## If true, persists the variable value to `user://settings.cfg` and restores it on load.
@export var save_to_device: bool = false
## On Scene Load: the value goes back to `initial_value` each time a new current scene is
## loaded (change_scene_to_file/_packed/_node, reload_current_scene), before that scene's
## nodes run `_ready()`. Variables with `save_to_device` keep their saved value instead.
## On Application Start: the value is kept for the whole run.
@export_enum("On Scene Load", "On Application Start") var reset_on: String = RESET_ON_SCENE_LOAD

var _value: Variant = null
var _runtime_cache_state: int = 0

func _init() -> void:
	# Ensure we have some initial value even when the exported property setter
	# doesn't run (e.g. brand new resources).
	if _value == null and _has_property_named("initial_value"):
		_value = get("initial_value")
	_restore_runtime_value_if_available()

	call_deferred("_report_next_frame")

func _has_property_named(prop_name: String) -> bool:
	var plist: Array = get_property_list()
	for p in plist:
		if typeof(p) == TYPE_DICTIONARY and str((p as Dictionary).get("name", "")) == prop_name:
			return true
	return false

func _report_next_frame() -> void:
	_restore_runtime_value_if_available()
	_register_for_scene_load_reset()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.process_frame
	VariableRuntimeReporter.report(self , _value)
	if save_to_device:
		# if there is a saved value for this variable, load it and override the initial value
		var config = ConfigFile.new()
		var err = config.load("user://settings.cfg")
		if err == OK:
			if config.has_section_key("variables", resource_path.get_basename()):
				var saved_value = config.get_value("variables", resource_path.get_basename())
				print("Loaded saved value for %s: %s" % [resource_path.get_basename(), str(saved_value)])
				_set_value_variant(saved_value, null)

func _apply_initial_value(new_val: Variant) -> void:
	_value = new_val
	_restore_runtime_value_if_available()
	if (debug_logs):
		Debug._log("%s: %s loaded initial_value: %s" % [get_class(), resource_path.get_basename(), str(new_val)])

func _set_value_variant(new_val: Variant, caller: Object = null) -> void:
	_restore_runtime_value_if_available()
	if _value != new_val:
		_value = new_val
		_remember_runtime_value()
		if save_to_device:
			save_value("variables", resource_path.get_basename(), _value)
		if has_signal("value_changed"):
			emit_signal("value_changed", _value)
		VariableRuntimeReporter.report(self , _value)
		if (debug_logs):
			Debug.log_value_change(self, caller)

func _get_value_variant() -> Variant:
	_restore_runtime_value_if_available()
	return _value

func _restore_runtime_value_if_available() -> void:
	if Engine.is_editor_hint():
		return
	if not _should_cache_runtime_value():
		return
	if _runtime_cache_state != 0:
		return

	var cache_key := _get_runtime_cache_key()
	if cache_key.is_empty():
		return

	if _runtime_value_cache.has(cache_key):
		_value = _runtime_value_cache[cache_key]
		_runtime_cache_state = 2
		return

	_runtime_cache_state = 1

func _remember_runtime_value() -> void:
	if Engine.is_editor_hint():
		return
	if not _should_cache_runtime_value():
		return

	var cache_key := _get_runtime_cache_key()
	if cache_key.is_empty():
		return

	_runtime_value_cache[cache_key] = _value
	_runtime_cache_state = 2

func _get_runtime_cache_key() -> String:
	return resource_path

func _should_cache_runtime_value() -> bool:
	return reset_on == RESET_ON_APPLICATION_START

# --- Reset on scene load ------------------------------------------------------
# A Resource stays alive (and keeps its value) while anything references it, including across
# reload_current_scene(), where the new scene is loaded before the old one is freed. So the
# reset can't rely on the resource being reloaded: every live variable registers here, and
# all "On Scene Load" ones are reset when a new current scene enters the tree.

## Registered from _report_next_frame() (deferred, so always on the main thread). Variables
## loaded together with a new scene are fresh anyway; only ones alive from a previous scene
## need resetting, and they have long been registered.
func _register_for_scene_load_reset() -> void:
	if Engine.is_editor_hint():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_scene_load_variables.append(weakref(self))
	if not _scene_load_hooked:
		_scene_load_hooked = true
		tree.node_added.connect(Callable(BaseVariable, "_on_tree_node_added"))

## SceneTree adds the new current scene to the root after freeing the previous one and before
## any of its nodes run _ready(), which is exactly when the values must be back to initial.
## Scenes added to the root by hand while there is no current scene (tests, custom loaders)
## count as a scene load too.
static func _on_tree_node_added(node: Node) -> void:
	var tree := node.get_tree()
	if tree == null or node.get_parent() != tree.root:
		return
	if tree.current_scene != null and tree.current_scene != node:
		return
	reset_scene_load_variables()

## Resets every live "On Scene Load" variable to its initial value. Called automatically on
## scene changes; call it yourself if you swap scenes without changing the current scene.
static func reset_scene_load_variables() -> void:
	var alive: Array[WeakRef] = []
	for ref in _scene_load_variables:
		var variable := ref.get_ref() as BaseVariable
		if variable == null:
			continue
		alive.append(ref)
		variable._reset_for_scene_load()
	_scene_load_variables = alive

func _reset_for_scene_load() -> void:
	if reset_on != RESET_ON_SCENE_LOAD or save_to_device:
		return
	if not _has_property_named("initial_value"):
		return
	_set_value_variant(get("initial_value"), null)

func save_value(section: String, key: String, value: Variant):
	var config = ConfigFile.new()
	# Load existing file if it exists to avoid overwriting other settings
	config.load("user://settings.cfg")
	
	config.set_value(section, key, value)
	config.save("user://settings.cfg")

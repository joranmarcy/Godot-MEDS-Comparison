@tool
extends VBoxContainer


signal variable_value_set_requested(session_id: int, path: String, type_name: String, value_str: String)
signal variable_debug_logs_set_requested(session_id: int, path: String, enabled: bool)


const COL_NAME := 0
const COL_TYPE := 1
const COL_VALUE := 2
const COL_DEBUG_LOGS := 3

const EditorUIUtils := preload("res://addons/godot_meds_editor/editor_ui_utils.gd")


var _tree: Tree
var _root: TreeItem
var _items_by_id: Dictionary = {}
var _editor_interface: Object = null
var _last_selected_column := -1
var _is_bulk_updating_debug_logs := false

var _vector_popup: PopupPanel
var _vector_spins: Array[EditorSpinSlider] = []
var _vector_edit_item: TreeItem = null
var _vector_edit_count := 0
var _is_populating_vector_popup := false

const NUMERIC_DRAG_THRESHOLD_PX := 4.0

var _num_drag_item: TreeItem = null
var _num_drag_press_pos := Vector2.ZERO
var _num_drag_active := false
var _num_drag_is_int := false
var _num_drag_value := 0.0
var _num_drag_per_px := 0.0
var _num_drag_last_sent := ""


func _get_pretty_type_name(type_name: String) -> String:
	# Runtime reports use script class names like "BoolVariable".
	# For the UI, show a shorter label like "bool".
	var t := type_name
	if t.ends_with("Variable"):
		return t.trim_suffix("Variable").to_lower()
	return t.to_lower()


func set_editor_interface(editor_interface: Object) -> void:
	_editor_interface = editor_interface


func _ready() -> void:
	# Header
	var header := HBoxContainer.new()
	add_child(header)

	var title := Label.new()
	title.text = "Runtime Variable Values"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var all_debug_btn := Button.new()
	all_debug_btn.text = "Enable Debug Logs (All)"
	all_debug_btn.pressed.connect(_on_enable_all_debug_logs_pressed)
	header.add_child(all_debug_btn)

	var no_debug_btn := Button.new()
	no_debug_btn.text = "Disable Debug Logs (All)"
	no_debug_btn.pressed.connect(_on_disable_all_debug_logs_pressed)
	header.add_child(no_debug_btn)

	# Tree
	_tree = Tree.new()
	_tree.columns = 4
	_tree.column_titles_visible = true
	_tree.set_column_title(COL_NAME, "Variable")
	_tree.set_column_title(COL_TYPE, "Type")
	_tree.set_column_title(COL_VALUE, "Value")
	_tree.set_column_title(COL_DEBUG_LOGS, "Debug Logs")
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_edited.connect(_on_tree_item_edited)
	if _tree.has_signal("item_activated"):
		_tree.item_activated.connect(_on_tree_item_activated)
	if _tree.has_signal("cell_selected"):
		_tree.cell_selected.connect(_on_tree_cell_selected)
	_tree.custom_popup_edited.connect(_on_tree_custom_popup_edited)
	_tree.gui_input.connect(_on_tree_gui_input)
	add_child(_tree)

	_build_vector_popup()

	_root = _tree.create_item()


func clear_values() -> void:
	_items_by_id.clear()
	_end_numeric_drag()
	_vector_edit_item = null
	if _vector_popup != null:
		_vector_popup.hide()
	if _tree != null:
		_tree.clear()
		_root = _tree.create_item()


func on_variable_value_updated(payload: Dictionary) -> void:
	# payload format (best-effort):
	#  id, path, name, type, value_str, debug_logs, ticks_msec, session_id
	var id := str(payload.get("id", ""))
	if id == "":
		id = str(payload.get("path", ""))
	if id == "":
		return

	var item: TreeItem = null
	if _items_by_id.has(id) and is_instance_valid(_items_by_id[id]):
		item = _items_by_id[id]
	else:
		item = _tree.create_item(_root)
		_items_by_id[id] = item
		item.set_text(COL_NAME, str(payload.get("name", id)))

	# Allow double-click selection to open the resource in the inspector.
	item.set_metadata(COL_NAME, {
		"path": str(payload.get("path", "")),
	})

	var raw_type := str(payload.get("type", ""))
	var new_value_str := str(payload.get("value_str", ""))
	var old_value_str := ""
	var old_blink_token := 0
	var value_meta_before: Variant = item.get_metadata(COL_VALUE)
	if typeof(value_meta_before) == TYPE_DICTIONARY:
		var vd := value_meta_before as Dictionary
		old_value_str = str(vd.get("value_str", ""))
		old_blink_token = int(vd.get("blink_token", 0))
	item.set_text(COL_TYPE, _get_pretty_type_name(raw_type))
	# Vectors are edited through a popup with per-component fields instead of raw text.
	# Note: set_cell_mode() clears the cell text, so only switch when needed and before set_text().
	var value_cell_mode := TreeItem.CELL_MODE_CUSTOM if _get_vector_component_count(raw_type) > 0 else TreeItem.CELL_MODE_STRING
	if item.get_cell_mode(COL_VALUE) != value_cell_mode:
		item.set_cell_mode(COL_VALUE, value_cell_mode)
	item.set_text(COL_VALUE, new_value_str)
	item.set_editable(COL_VALUE, true)
	item.set_cell_mode(COL_DEBUG_LOGS, TreeItem.CELL_MODE_CHECK)
	item.set_editable(COL_DEBUG_LOGS, true)
	item.set_checked(COL_DEBUG_LOGS, bool(payload.get("debug_logs", false)))

	# Store value_str for future blink detection.
	var blink_token := old_blink_token
	if old_value_str != "" and new_value_str != old_value_str:
		blink_token += 1
	item.set_metadata(COL_VALUE, {
		"session_id": int(payload.get("session_id", 0)),
		"path": str(payload.get("path", "")),
		"type": raw_type,
		"value_str": new_value_str,
		"blink_token": blink_token,
	})
	if old_value_str != "" and new_value_str != old_value_str:
		_blink_cell_bg(item, COL_VALUE, blink_token)
	item.set_metadata(COL_DEBUG_LOGS, {
		"session_id": int(payload.get("session_id", 0)),
		"path": str(payload.get("path", "")),
	})


func _blink_cell_bg(item: TreeItem, column: int, token: int) -> void:
	if item == null:
		return
	var blink_color := _get_blink_color()
	# TreeItem supports per-cell custom background.
	item.set_custom_bg_color(column, blink_color)
	call_deferred("_clear_blink_cell_bg_later", item, column, token)


func _clear_blink_cell_bg_later(item: TreeItem, column: int, token: int) -> void:
	# Short delay for the blink effect.
	await get_tree().create_timer(0.18).timeout
	if not is_instance_valid(item):
		return
	var meta: Variant = item.get_metadata(column)
	if typeof(meta) != TYPE_DICTIONARY:
		return
	var dict := meta as Dictionary
	if int(dict.get("blink_token", 0)) != token:
		return
	if item.has_method("clear_custom_bg_color"):
		item.call("clear_custom_bg_color", column)
	else:
		item.set_custom_bg_color(column, Color(0, 0, 0, 0))


func _get_blink_color() -> Color:
	# Prefer editor theme colors when available.
	if has_method("has_theme_color") and call("has_theme_color", "accent_color", "Editor"):
		var c: Color = get_theme_color("accent_color", "Editor")
		c.a = 0.35
		return c
	if has_method("has_theme_color") and call("has_theme_color", "warning_color", "Editor"):
		var w: Color = get_theme_color("warning_color", "Editor")
		w.a = 0.30
		return w
	return Color(1.0, 0.85, 0.2, 0.30)


func _on_tree_cell_selected() -> void:
	_last_selected_column = _get_selected_column()


func _get_selected_column() -> int:
	if _tree == null:
		return _last_selected_column
	if _tree.has_method("get_selected_column"):
		return int(_tree.call("get_selected_column"))
	return _last_selected_column


func _on_tree_item_activated() -> void:
	if _tree == null:
		return
	var item := _tree.get_selected()
	if item == null:
		return

	var column := _get_selected_column()
	if column != COL_NAME:
		return

	var meta: Variant = item.get_metadata(COL_NAME)
	if typeof(meta) != TYPE_DICTIONARY:
		return
	var dict := meta as Dictionary
	var path := str(dict.get("path", ""))
	if path == "":
		push_warning("Variable Values: can't open variable without a saved resource path.")
		return

	EditorUIUtils.select_resource_in_editor(_editor_interface, path)



func _get_metadata_dict(item: TreeItem, column: int) -> Dictionary:
	if item == null:
		return {}
	var meta: Variant = item.get_metadata(column)
	if typeof(meta) != TYPE_DICTIONARY:
		return {}
	return meta as Dictionary



func _on_tree_item_edited() -> void:
	if _is_bulk_updating_debug_logs:
		return
	var item := _tree.get_edited()
	if item == null:
		return
	var column := _tree.get_edited_column()
	match column:
		COL_VALUE:
			# Custom cells (vectors) are edited through the popup, not here.
			if item.get_cell_mode(COL_VALUE) == TreeItem.CELL_MODE_CUSTOM:
				return
			var value_meta := _get_metadata_dict(item, COL_VALUE)
			if value_meta.is_empty():
				return
			var session_id := int(value_meta.get("session_id", 0))
			var path := str(value_meta.get("path", ""))
			var type_name := str(value_meta.get("type", ""))
			if path == "":
				push_warning("Variable Values: can't edit values for resources without a saved path.")
				return
			var value_str := item.get_text(COL_VALUE)
			variable_value_set_requested.emit(session_id, path, type_name, value_str)
			return

		COL_DEBUG_LOGS:
			var debug_meta := _get_metadata_dict(item, COL_DEBUG_LOGS)
			if debug_meta.is_empty():
				return
			var session_id := int(debug_meta.get("session_id", 0))
			var path := str(debug_meta.get("path", ""))
			if path == "":
				push_warning("Variable Values: can't toggle debug logs for resources without a saved path.")
				return
			var enabled := bool(item.is_checked(COL_DEBUG_LOGS))
			variable_debug_logs_set_requested.emit(session_id, path, enabled)
			return

		_:
			return


func _get_vector_component_count(type_name: String) -> int:
	match type_name:
		"Vector2Variable":
			return 2
		"Vector3Variable":
			return 3
	return 0


func _parse_vector_components(value_str: String, count: int) -> PackedFloat64Array:
	# Accepts the displayed "(x, y)" form as well as "Vector2(x, y)", "x, y" and "x y".
	var s := value_str.strip_edges()
	var open_idx := s.find("(")
	var close_idx := s.rfind(")")
	if open_idx != -1 and close_idx > open_idx:
		s = s.substr(open_idx + 1, close_idx - open_idx - 1)
	var result := PackedFloat64Array()
	for chunk in s.split(",", false):
		for token in chunk.strip_edges().split(" ", false):
			if token.is_valid_float():
				result.append(token.to_float())
	if result.size() != count:
		result.resize(count)
		result.fill(0.0)
	return result


func _build_vector_popup() -> void:
	_vector_popup = PopupPanel.new()
	_vector_popup.popup_hide.connect(func() -> void: _vector_edit_item = null)
	add_child(_vector_popup)

	var row := HBoxContainer.new()
	_vector_popup.add_child(row)

	var axis_labels: Array[String] = ["x", "y", "z"]
	for i in axis_labels.size():
		var spin := EditorSpinSlider.new()
		spin.label = axis_labels[i]
		spin.flat = true
		spin.hide_slider = true
		spin.step = 0.001
		spin.min_value = -100000.0
		spin.max_value = 100000.0
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.custom_minimum_size = Vector2(110, 0)
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var color_name := "property_color_" + axis_labels[i]
		if has_theme_color(color_name, "Editor"):
			spin.add_theme_color_override("label_color", get_theme_color(color_name, "Editor"))
		spin.value_changed.connect(_on_vector_spin_value_changed.unbind(1))
		row.add_child(spin)
		_vector_spins.append(spin)


func _on_tree_custom_popup_edited(_arrow_clicked: bool) -> void:
	var item := _tree.get_edited()
	if item == null or _tree.get_edited_column() != COL_VALUE:
		return
	var value_meta := _get_metadata_dict(item, COL_VALUE)
	var count := _get_vector_component_count(str(value_meta.get("type", "")))
	if count == 0:
		return
	if str(value_meta.get("path", "")) == "":
		push_warning("Variable Values: can't edit values for resources without a saved path.")
		return

	_vector_edit_item = item
	_vector_edit_count = count
	var components := _parse_vector_components(str(value_meta.get("value_str", "")), count)
	_is_populating_vector_popup = true
	for i in _vector_spins.size():
		var spin := _vector_spins[i]
		spin.visible = i < count
		if i < count:
			spin.value = components[i]
	_is_populating_vector_popup = false

	# get_custom_popup_rect() is in canvas (global) coordinates and already starts at the cell's bottom edge.
	var cell_rect := _tree.get_custom_popup_rect()
	var screen_pos := cell_rect.position - _tree.get_global_position() + _tree.get_screen_position()
	_vector_popup.reset_size()
	_vector_popup.popup(Rect2i(Vector2i(screen_pos), Vector2i(int(cell_rect.size.x), 0)))


func _on_vector_spin_value_changed() -> void:
	if _is_populating_vector_popup or not is_instance_valid(_vector_edit_item):
		return
	var value_meta := _get_metadata_dict(_vector_edit_item, COL_VALUE)
	var path := str(value_meta.get("path", ""))
	if path == "":
		return
	var new_value: Variant
	if _vector_edit_count == 2:
		new_value = Vector2(_vector_spins[0].value, _vector_spins[1].value)
	else:
		new_value = Vector3(_vector_spins[0].value, _vector_spins[1].value, _vector_spins[2].value)
	# Apply live so dragging a field updates the running game immediately.
	variable_value_set_requested.emit(int(value_meta.get("session_id", 0)), path, str(value_meta.get("type", "")), var_to_str(new_value))


func _is_numeric_type(type_name: String) -> bool:
	return type_name == "IntVariable" or type_name == "FloatVariable"


# Returns the item when `pos` is over an editable int/float value cell, otherwise null.
func _get_numeric_value_item_at(pos: Vector2) -> TreeItem:
	var item := _tree.get_item_at_position(pos)
	if item == null or _tree.get_column_at_position(pos) != COL_VALUE:
		return null
	var value_meta := _get_metadata_dict(item, COL_VALUE)
	if not _is_numeric_type(str(value_meta.get("type", ""))):
		return null
	if str(value_meta.get("path", "")) == "" or not item.get_text(COL_VALUE).strip_edges().is_valid_float():
		return null
	return item


# Inspector-style drag editing: press on an int/float value and drag horizontally.
# A plain click (no drag) falls through to the Tree, so click-to-type still works.
func _on_tree_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_num_drag_item = _get_numeric_value_item_at(mb.position)
			_num_drag_press_pos = mb.position
			_num_drag_active = false
		else:
			if _num_drag_active:
				_end_numeric_drag()
				# Swallow the release so the Tree doesn't open the text editor after a drag.
				_tree.accept_event()
			_num_drag_item = null
		return

	var mm := event as InputEventMouseMotion
	if mm == null:
		return

	if _num_drag_item == null or (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		var hovering_numeric := _get_numeric_value_item_at(mm.position) != null
		_tree.mouse_default_cursor_shape = Control.CURSOR_HSIZE if hovering_numeric else Control.CURSOR_ARROW
		return
	if not is_instance_valid(_num_drag_item):
		_end_numeric_drag()
		return

	if not _num_drag_active:
		if mm.position.distance_to(_num_drag_press_pos) < NUMERIC_DRAG_THRESHOLD_PX:
			return
		_begin_numeric_drag()

	var delta := mm.relative.x * _num_drag_per_px
	if mm.shift_pressed:
		delta *= 0.1
	_num_drag_value += delta
	_apply_numeric_drag_value()
	_tree.accept_event()


func _begin_numeric_drag() -> void:
	var value_meta := _get_metadata_dict(_num_drag_item, COL_VALUE)
	_num_drag_is_int = str(value_meta.get("type", "")) == "IntVariable"
	_num_drag_value = _num_drag_item.get_text(COL_VALUE).strip_edges().to_float()
	# Scale drag speed with the value's magnitude so both small and large numbers feel usable.
	var min_per_px := 0.1 if _num_drag_is_int else 0.01
	_num_drag_per_px = maxf(absf(_num_drag_value) * 0.005, min_per_px)
	_num_drag_last_sent = _num_drag_item.get_text(COL_VALUE)
	_num_drag_active = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _apply_numeric_drag_value() -> void:
	var value_str: String
	if _num_drag_is_int:
		value_str = str(roundi(_num_drag_value))
	else:
		value_str = str(snappedf(_num_drag_value, 0.001))
	if value_str == _num_drag_last_sent:
		return
	_num_drag_last_sent = value_str
	_num_drag_item.set_text(COL_VALUE, value_str)
	var value_meta := _get_metadata_dict(_num_drag_item, COL_VALUE)
	variable_value_set_requested.emit(int(value_meta.get("session_id", 0)), str(value_meta.get("path", "")), str(value_meta.get("type", "")), value_str)


func _end_numeric_drag() -> void:
	if _num_drag_active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if _tree != null:
			_tree.warp_mouse(_num_drag_press_pos)
	_num_drag_active = false
	_num_drag_item = null


func _on_enable_all_debug_logs_pressed() -> void:
	_set_debug_logs_for_all(true)


func _on_disable_all_debug_logs_pressed() -> void:
	_set_debug_logs_for_all(false)


func _set_debug_logs_for_all(enabled: bool) -> void:
	if _tree == null:
		return

	_is_bulk_updating_debug_logs = true
	for key in _items_by_id.keys():
		var item: Variant = _items_by_id[key]
		if not is_instance_valid(item):
			continue
		var tree_item := item as TreeItem
		if tree_item == null:
			continue
		# Update UI first.
		tree_item.set_checked(COL_DEBUG_LOGS, enabled)

		# Then request the runtime change.
		var meta: Variant = tree_item.get_metadata(COL_DEBUG_LOGS)
		if typeof(meta) != TYPE_DICTIONARY:
			continue
		var dict := meta as Dictionary
		var path := str(dict.get("path", ""))
		if path == "":
			continue
		# Use session_id 0 to broadcast to all active debug sessions.
		variable_debug_logs_set_requested.emit(0, path, enabled)
	_is_bulk_updating_debug_logs = false

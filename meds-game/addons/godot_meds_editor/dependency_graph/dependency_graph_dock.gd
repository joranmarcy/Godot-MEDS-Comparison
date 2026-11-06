@tool
extends VBoxContainer
## "Dependencies" bottom panel: a graph of which scene nodes write, raise, listen to or read
## which MEDS variables and events. Built from saved scenes and scripts (see dependency_scanner.gd).
##
## While the game runs, variables and events flash when they change or are raised, along with
## the links to the nodes that react to them, using the same debugger messages as the
## Variable Values and Events docks.

signal open_node_requested(scene_path: String, node_path: String)

const Scanner := preload("res://addons/godot_meds_editor/dependency_graph/dependency_scanner.gd")
const Mermaid := preload("res://addons/godot_meds_editor/dependency_graph/dependency_graph_mermaid.gd")
const Layout := preload("res://addons/godot_meds_editor/dependency_graph/dependency_graph_layout.gd")
const EditorUIUtils := preload("res://addons/godot_meds_editor/editor_ui_utils.gd")

const SCOPE_EDITED_SCENE := 0
const SCOPE_MAIN_SCENE := 1
const SCOPE_PROJECT := 2

const EDGE_COLORS := {
	Scanner.EDGE_WRITES: Color(1.0, 0.62, 0.25),
	Scanner.EDGE_RAISES: Color(0.95, 0.45, 0.8),
	Scanner.EDGE_LISTENS: Color(0.4, 0.85, 0.5),
	Scanner.EDGE_READS: Color(0.55, 0.7, 0.95),
	Scanner.EDGE_REFERENCES: Color(0.55, 0.55, 0.55),
	Scanner.EDGE_SPAWNS: Color(0.95, 0.85, 0.35),
}
const EDGE_PORT_TYPES := {
	Scanner.EDGE_WRITES: 0, Scanner.EDGE_RAISES: 1, Scanner.EDGE_LISTENS: 2,
	Scanner.EDGE_READS: 3, Scanner.EDGE_REFERENCES: 4, Scanner.EDGE_SPAWNS: 5,
}
const EDGE_ORDER := [
	Scanner.EDGE_WRITES, Scanner.EDGE_RAISES, Scanner.EDGE_SPAWNS,
	Scanner.EDGE_LISTENS, Scanner.EDGE_READS, Scanner.EDGE_REFERENCES,
]
const NODE_COLORS := {
	Scanner.KIND_NODE: Color(0.28, 0.3, 0.35),
	Scanner.KIND_EVENT: Color(0.45, 0.24, 0.55),
	Scanner.KIND_VARIABLE: Color(0.16, 0.33, 0.55),
}
const FLASH_SECONDS := 0.9
const FLASH_MODULATE := Color(1.7, 1.5, 0.7)

var _editor_interface: Object = null
var _edited_scene_path := ""
var _dirty := true

var _scope: OptionButton
var _collapse: CheckBox
var _spawned: CheckBox
var _hide: LineEdit
var _status: Label
var _graph_edit: RoutedGraphEdit
var _file_dialog: Node = null

var _graph: Dictionary = {}
var _graph_nodes: Dictionary = {}     # graph id -> GraphNode
var _ports: Dictionary = {}           # graph id -> {"in": [kinds], "out": [kinds]}
var _base_subtitles: Dictionary = {}  # graph id -> subtitle text without runtime info
var _subtitle_labels: Dictionary = {} # graph id -> Label
var _connections: Array = []          # {from_id, to_id, from_name, from_port, to_name, to_port}
var _layout_version := 0
var _layout_done := false
var _backward_links := 0

var _flash_left: Dictionary = {}      # graph id -> seconds
var _seen_values: Dictionary = {}     # resource path -> last value string
var _raised_counts: Dictionary = {}   # resource path -> raise count


func _init() -> void:
	name = "Dependencies"
	custom_minimum_size = Vector2(0, 260)
	_build_ui()
	visibility_changed.connect(_on_visibility_changed)
	set_process(false)


func set_editor_interface(editor_interface: Object) -> void:
	_editor_interface = editor_interface


## Called by the plugin when the edited scene tab changes.
func set_edited_scene(scene_path: String) -> void:
	if scene_path == _edited_scene_path:
		return
	_edited_scene_path = scene_path
	if _scope.selected == SCOPE_EDITED_SCENE:
		mark_dirty()


## Called by the plugin when scenes or scripts are saved: the graph reflects saved files.
func mark_dirty() -> void:
	_dirty = true
	if is_visible_in_tree():
		refresh()


func refresh() -> void:
	_dirty = false
	var scanner := Scanner.new()
	scanner.collapse_instances = _collapse.button_pressed
	scanner.follow_spawned_scenes = _spawned.button_pressed
	var graph: Dictionary
	match _scope.selected:
		SCOPE_PROJECT:
			graph = scanner.scan_project()
		SCOPE_MAIN_SCENE:
			var main_scene := _main_scene_path()
			if main_scene == "":
				_show_message("No main scene set in Project Settings > Application > Run.")
				return
			graph = scanner.scan_scene(main_scene)
		_:
			if _edited_scene_path == "":
				_show_message("Open a scene (or pick another scope) to see its MEDS dependencies.")
				return
			graph = scanner.scan_scene(_edited_scene_path)
	set_graph(Scanner.filter_graph(graph, _hide.text.split(",", false)))


func set_graph(graph: Dictionary) -> void:
	_clear_graph()
	_graph = graph
	if graph.get("nodes", {}).is_empty():
		_show_message("%s: no node references a MEDS variable or event." % graph.get("title", "Graph"))
		return

	var ports := _compute_ports(graph)
	_ports = ports
	var index := 0
	for id in graph["nodes"]:
		var graph_node := _create_graph_node(graph["nodes"][id], ports[id], index)
		_graph_edit.add_child(graph_node)
		_graph_nodes[id] = graph_node
		index += 1

	for edge in graph["edges"]:
		var from_node: GraphNode = _graph_nodes[edge["from"]]
		var to_node: GraphNode = _graph_nodes[edge["to"]]
		var connection := {
			"from_id": edge["from"],
			"to_id": edge["to"],
			"from_name": from_node.name,
			"from_port": (ports[edge["from"]]["out"] as Array).find(edge["kind"]),
			"to_name": to_node.name,
			"to_port": (ports[edge["to"]]["in"] as Array).find(edge["kind"]),
		}
		_graph_edit.connect_node(connection["from_name"], connection["from_port"], connection["to_name"], connection["to_port"])
		_connections.append(connection)

	_request_layout()
	_status.text = "%s - %d nodes, %d variables/events, %d links. Reflects saved files." % [
		graph["title"], _count_kind(Scanner.KIND_NODE), graph["nodes"].size() - _count_kind(Scanner.KIND_NODE), graph["edges"].size()]


func get_graph() -> Dictionary:
	return _graph


func get_connection_count() -> int:
	return _graph_edit.get_connection_list().size()


func get_mermaid() -> String:
	return Mermaid.to_markdown(_graph) if not _graph.is_empty() else ""


# --- Runtime highlighting -----------------------------------------------------

## Payload from the Variable Values debugger channel ("path", "value_str").
func on_variable_value_updated(payload: Dictionary) -> void:
	var path := str(payload.get("path", ""))
	var id := "res:" + path
	if path == "" or not _graph_nodes.has(id):
		return
	var value_str := str(payload.get("value_str", ""))
	_set_runtime_subtitle(id, "= " + value_str)
	# The first report of a session is the initial value, not a change.
	if _seen_values.has(path) and _seen_values[path] != value_str:
		_start_flash(id)
	_seen_values[path] = value_str


## Payload from the Events debugger channel ("path", "raised_count").
func on_event_updated(payload: Dictionary) -> void:
	var path := str(payload.get("path", ""))
	var id := "res:" + path
	if path == "" or not _graph_nodes.has(id):
		return
	var count := int(payload.get("raised_count", 0))
	if count > int(_raised_counts.get(path, 0)):
		_start_flash(id)
	_raised_counts[path] = count
	if count > 0:
		_set_runtime_subtitle(id, "raised x%d" % count)


func clear_runtime(_session_id: int = 0) -> void:
	for id in _flash_left.keys():
		_apply_flash(id, 0.0)
	_flash_left.clear()
	_seen_values.clear()
	_raised_counts.clear()
	for id in _subtitle_labels:
		(_subtitle_labels[id] as Label).text = _base_subtitles[id]
	set_process(false)


func is_flashing(resource_path: String) -> bool:
	return _flash_left.has("res:" + resource_path)


func _start_flash(id: String) -> void:
	_flash_left[id] = FLASH_SECONDS
	_apply_flash(id, 1.0)
	set_process(true)


func _process(delta: float) -> void:
	for id in _flash_left.keys():
		var left: float = _flash_left[id] - delta
		if left <= 0.0:
			_flash_left.erase(id)
			_apply_flash(id, 0.0)
		else:
			_flash_left[id] = left
			_apply_flash(id, left / FLASH_SECONDS)
	if _flash_left.is_empty():
		set_process(false)


## Lights the variable/event and its outgoing links, i.e. the nodes that were notified or read it.
func _apply_flash(id: String, amount: float) -> void:
	var graph_node: GraphNode = _graph_nodes.get(id)
	if graph_node == null:
		return
	graph_node.self_modulate = Color.WHITE.lerp(FLASH_MODULATE, amount)
	for connection in _connections:
		if connection["from_id"] == id:
			_graph_edit.set_connection_activity(connection["from_name"], connection["from_port"], connection["to_name"], connection["to_port"], amount)


func _set_runtime_subtitle(id: String, runtime_text: String) -> void:
	var label: Label = _subtitle_labels.get(id)
	if label != null:
		label.text = "%s  %s" % [_base_subtitles[id], runtime_text]


# --- UI -------------------------------------------------------------------------

func _build_ui() -> void:
	var toolbar := HBoxContainer.new()
	add_child(toolbar)

	_scope = OptionButton.new()
	_scope.add_item("Edited scene", SCOPE_EDITED_SCENE)
	_scope.add_item("Main scene", SCOPE_MAIN_SCENE)
	_scope.add_item("Whole project", SCOPE_PROJECT)
	_scope.tooltip_text = "Edited/Main scene: follows instanced and spawned sub-scenes.\nWhole project: every scene outside addons/."
	_scope.item_selected.connect(func(_i: int) -> void: refresh())
	toolbar.add_child(_scope)

	_collapse = CheckBox.new()
	_collapse.text = "Collapse sub-scenes"
	_collapse.button_pressed = true
	_collapse.tooltip_text = "Scene scopes: one box per instanced sub-scene (HUD, Player...).\nWhole project: one box per scene file."
	_collapse.toggled.connect(func(_on: bool) -> void: refresh())
	toolbar.add_child(_collapse)

	_spawned = CheckBox.new()
	_spawned.text = "Spawned scenes"
	_spawned.button_pressed = true
	_spawned.tooltip_text = "Follow PackedScene exports (e.g. a spawner's scene) and show 'spawns' links."
	_spawned.toggled.connect(func(_on: bool) -> void: refresh())
	toolbar.add_child(_spawned)

	var hide_label := Label.new()
	hide_label.text = "Hide:"
	toolbar.add_child(hide_label)
	_hide = LineEdit.new()
	_hide.placeholder_text = "comma-separated, e.g. DebugOverlay, ResetSessionVariables"
	_hide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hide.text_submitted.connect(func(_t: String) -> void: refresh())
	toolbar.add_child(_hide)

	for spec in [["Refresh", refresh], ["Auto layout", _on_auto_layout], ["Copy Mermaid", _on_copy_mermaid], ["Save Mermaid...", _on_save_mermaid]]:
		var button := Button.new()
		button.text = spec[0]
		button.pressed.connect(spec[1])
		toolbar.add_child(button)

	var legend := HBoxContainer.new()
	add_child(legend)
	for kind in EDGE_ORDER:
		var item := Label.new()
		item.text = "-- %s" % kind
		item.add_theme_color_override("font_color", EDGE_COLORS[kind])
		legend.add_child(item)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend.add_child(spacer)
	_status = Label.new()
	_status.modulate = Color(1, 1, 1, 0.7)
	legend.add_child(_status)

	_graph_edit = RoutedGraphEdit.new()
	_graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph_edit.minimap_enabled = true
	_graph_edit.right_disconnects = false
	# GraphEdit's own arranger ignores link kinds and routing; "Auto layout" replaces it.
	_graph_edit.show_arrange_button = false
	_graph_edit.zoom = 0.85
	add_child(_graph_edit)


func _create_graph_node(node: Dictionary, ports: Dictionary, index: int) -> GraphNode:
	var graph_node := GraphNode.new()
	graph_node.name = "n%d" % index
	graph_node.title = node["label"]
	graph_node.tooltip_text = _tooltip(node)
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = NODE_COLORS.get(node["kind"], NODE_COLORS[Scanner.KIND_NODE])
	title_style.set_corner_radius_all(4)
	title_style.content_margin_left = 8
	title_style.content_margin_right = 4
	graph_node.add_theme_stylebox_override("titlebar", title_style)
	var selected_style := title_style.duplicate() as StyleBoxFlat
	selected_style.bg_color = title_style.bg_color.lightened(0.25)
	graph_node.add_theme_stylebox_override("titlebar_selected", selected_style)

	var open_button := Button.new()
	open_button.text = "Open"
	open_button.flat = true
	open_button.tooltip_text = "Select the resource in the FileSystem/Inspector" if node["kind"] != Scanner.KIND_NODE else "Open the scene and select this node"
	open_button.pressed.connect(_on_open_pressed.bind(node["id"]))
	graph_node.get_titlebar_hbox().add_child(open_button)

	var subtitle := Label.new()
	subtitle.text = node["subtitle"]
	subtitle.modulate = Color(1, 1, 1, 0.65)
	graph_node.add_child(subtitle)
	_subtitle_labels[node["id"]] = subtitle
	_base_subtitles[node["id"]] = node["subtitle"]

	var ins: Array = ports["in"]
	var outs: Array = ports["out"]
	for row in maxi(ins.size(), outs.size()):
		var row_box := HBoxContainer.new()
		var left := Label.new()
		left.text = ins[row] if row < ins.size() else ""
		left.add_theme_color_override("font_color", EDGE_COLORS[ins[row]] if row < ins.size() else Color.WHITE)
		row_box.add_child(left)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.custom_minimum_size.x = 24
		row_box.add_child(gap)
		var right := Label.new()
		right.text = outs[row] if row < outs.size() else ""
		right.add_theme_color_override("font_color", EDGE_COLORS[outs[row]] if row < outs.size() else Color.WHITE)
		row_box.add_child(right)
		graph_node.add_child(row_box)
		graph_node.set_slot(row + 1,
			row < ins.size(), EDGE_PORT_TYPES.get(ins[row], 0) if row < ins.size() else 0, EDGE_COLORS[ins[row]] if row < ins.size() else Color.WHITE,
			row < outs.size(), EDGE_PORT_TYPES.get(outs[row], 0) if row < outs.size() else 0, EDGE_COLORS[outs[row]] if row < outs.size() else Color.WHITE)
	return graph_node


## One port per link kind on each side, so every link keeps a single colour end to end.
static func _compute_ports(graph: Dictionary) -> Dictionary:
	var ports: Dictionary = {}
	for id in graph["nodes"]:
		ports[id] = {"in": [], "out": []}
	for edge in graph["edges"]:
		if not (ports[edge["from"]]["out"] as Array).has(edge["kind"]):
			ports[edge["from"]]["out"].append(edge["kind"])
		if not (ports[edge["to"]]["in"] as Array).has(edge["kind"]):
			ports[edge["to"]]["in"].append(edge["kind"])
	for id in ports:
		for side in ["in", "out"]:
			(ports[id][side] as Array).sort_custom(func(a: String, b: String) -> bool: return EDGE_ORDER.find(a) < EDGE_ORDER.find(b))
	return ports


func _tooltip(node: Dictionary) -> String:
	if node["kind"] == Scanner.KIND_NODE:
		return "%s\nNode: %s\nScene: %s" % [node["label"], node["node_path"], node["scene_path"]]
	return "%s (%s)\n%s" % [node["label"], node["type"], node["resource_path"]]


func _clear_graph() -> void:
	clear_runtime()
	_layout_version += 1
	_layout_done = false
	_graph_edit.routes = {}
	_ports.clear()
	_graph_edit.clear_connections()
	for graph_node in _graph_nodes.values():
		_graph_edit.remove_child(graph_node)
		graph_node.queue_free()
	_graph_nodes.clear()
	_subtitle_labels.clear()
	_base_subtitles.clear()
	_connections.clear()
	_graph = {}


func _show_message(text: String) -> void:
	_clear_graph()
	_status.text = text


func _count_kind(kind: String) -> int:
	var count := 0
	for node in _graph["nodes"].values():
		if node["kind"] == kind:
			count += 1
	return count


func _main_scene_path() -> String:
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_scene.begins_with("uid://"):
		var uid := ResourceUID.text_to_id(main_scene)
		main_scene = ResourceUID.get_id_path(uid) if ResourceUID.has_id(uid) else ""
	return main_scene


# --- Layout ---------------------------------------------------------------------

## Port positions are only known once the GraphNodes have been sized, a frame or two after
## they are added, so the layout runs deferred (and again when the dock becomes visible).
func _request_layout() -> void:
	_layout_version += 1
	_layout_done = false
	_run_layout_when_ready.call_deferred(_layout_version)


func _run_layout_when_ready(version: int) -> void:
	for _attempt in 10:
		if version != _layout_version or not is_inside_tree():
			return
		if _ports_ready():
			_apply_layout()
			return
		await get_tree().process_frame


func _ports_ready() -> bool:
	for id in _graph_nodes:
		var graph_node: GraphNode = _graph_nodes[id]
		if graph_node.size == Vector2.ZERO:
			return false
		if graph_node.get_input_port_count() != _ports[id]["in"].size() or graph_node.get_output_port_count() != _ports[id]["out"].size():
			return false
	return true


func _apply_layout() -> void:
	var nodes: Dictionary = {}
	for id in _graph_nodes:
		var graph_node: GraphNode = _graph_nodes[id]
		var in_ports: Dictionary = {}
		var out_ports: Dictionary = {}
		for i in _ports[id]["in"].size():
			in_ports[_ports[id]["in"][i]] = graph_node.get_input_port_position(i)
		for i in _ports[id]["out"].size():
			out_ports[_ports[id]["out"][i]] = graph_node.get_output_port_position(i)
		nodes[id] = {"size": graph_node.size, "in": in_ports, "out": out_ports}
	var edges: Array = []
	for edge in _graph["edges"]:
		edges.append({
			"from": edge["from"],
			"to": edge["to"],
			"kind": edge["kind"],
			"weak": edge["kind"] == Scanner.EDGE_READS or edge["kind"] == Scanner.EDGE_REFERENCES,
		})
	var result: Dictionary = Layout.new().compute(nodes, edges)

	# Routes are keyed by their end points, which is all GraphEdit gives _get_connection_line().
	var routes: Dictionary = {}
	for e in edges.size():
		var edge: Dictionary = edges[e]
		var from_point: Vector2 = result["positions"][edge["from"]] + nodes[edge["from"]]["out"][edge["kind"]]
		var to_point: Vector2 = result["positions"][edge["to"]] + nodes[edge["to"]]["in"][edge["kind"]]
		routes[RoutedGraphEdit.route_key(from_point, to_point)] = result["routes"][e]
	_graph_edit.routes = routes
	for id in result["positions"]:
		(_graph_nodes[id] as GraphNode).position_offset = result["positions"][id]
	_backward_links = int(result["reversed"])
	_layout_done = true
	_frame_graph()


func is_layout_done() -> bool:
	return _layout_done


## Graph-space rectangle of a box, for tests.
func get_node_rect(id: String) -> Rect2:
	var graph_node: GraphNode = _graph_nodes[id]
	return Rect2(graph_node.position_offset, graph_node.size)


func get_route(from_id: String, to_id: String, kind: String) -> PackedVector2Array:
	var from_node: GraphNode = _graph_nodes[from_id]
	var to_node: GraphNode = _graph_nodes[to_id]
	var from_point := from_node.position_offset + from_node.get_output_port_position(_ports[from_id]["out"].find(kind))
	var to_point := to_node.position_offset + to_node.get_input_port_position(_ports[to_id]["in"].find(kind))
	return _graph_edit.routes.get(RoutedGraphEdit.route_key(from_point, to_point), PackedVector2Array())


func get_backward_link_count() -> int:
	return _backward_links


func _frame_graph() -> void:
	var bounds := Rect2()
	var first := true
	for graph_node in _graph_nodes.values():
		var rect := Rect2((graph_node as GraphNode).position_offset, (graph_node as GraphNode).size)
		bounds = rect if first else bounds.merge(rect)
		first = false
	if first:
		return
	# Fit the whole graph in the panel (within readable limits), then scroll to its top-left.
	var available := _graph_edit.size
	if available.x > 0.0 and available.y > 0.0:
		var fit := minf((available.x - 80.0) / bounds.size.x, (available.y - 140.0) / bounds.size.y)
		_graph_edit.zoom = clampf(fit, 0.35, 1.0)
	# Leave room for GraphEdit's own zoom/snap toolbar in the top-left corner.
	_graph_edit.scroll_offset = bounds.position * _graph_edit.zoom - Vector2(40, 70)


## GraphEdit that draws each link along the route computed by the layout. Links whose ends
## moved since (e.g. a box dragged by hand) fall back to a plain curve.
class RoutedGraphEdit extends GraphEdit:
	var routes: Dictionary = {}:
		set(value):
			routes = value
			queue_redraw()

	static func route_key(from_point: Vector2, to_point: Vector2) -> String:
		return "%d,%d>%d,%d" % [roundi(from_point.x), roundi(from_point.y), roundi(to_point.x), roundi(to_point.y)]

	func _get_connection_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
		var scale := zoom if zoom > 0.0 else 1.0
		var route: PackedVector2Array = routes.get(route_key(from_position / scale, to_position / scale), PackedVector2Array())
		if route.size() >= 2:
			var scaled := PackedVector2Array()
			scaled.resize(route.size())
			for i in route.size():
				scaled[i] = route[i] * scale
			return scaled
		var handle := maxf(absf(to_position.x - from_position.x) * 0.5, 40.0 * scale)
		var curve := Curve2D.new()
		curve.add_point(from_position, Vector2.ZERO, Vector2(handle, 0))
		curve.add_point(to_position, Vector2(-handle, 0), Vector2.ZERO)
		return curve.tessellate(5, 2.0)


# --- Actions ----------------------------------------------------------------------

func _on_open_pressed(id: String) -> void:
	var node: Dictionary = _graph["nodes"].get(id, {})
	if node.is_empty():
		return
	if node["kind"] == Scanner.KIND_NODE:
		open_node_requested.emit(node["scene_path"], node["node_path"])
	elif node["resource_path"] != "":
		EditorUIUtils.select_resource_in_editor(_editor_interface, node["resource_path"])


func _on_auto_layout() -> void:
	if not _graph.is_empty():
		_request_layout()


func _on_copy_mermaid() -> void:
	var text := get_mermaid()
	if text == "":
		return
	DisplayServer.clipboard_set(text)
	_status.text = "Mermaid copied to the clipboard (%d links)." % _graph["edges"].size()


func _on_save_mermaid() -> void:
	if _graph.is_empty():
		return
	if _file_dialog == null:
		# Created lazily: EditorFileDialog only exists inside the editor.
		_file_dialog = ClassDB.instantiate("EditorFileDialog") if ClassDB.class_exists("EditorFileDialog") else FileDialog.new()
		_file_dialog.set("file_mode", FileDialog.FILE_MODE_SAVE_FILE)
		_file_dialog.set("filters", PackedStringArray(["*.md ; Markdown"]))
		_file_dialog.connect("file_selected", _write_mermaid_file)
		add_child(_file_dialog)
	_file_dialog.set("current_file", "meds_dependencies.md")
	if _file_dialog.has_method("popup_file_dialog"):
		_file_dialog.call("popup_file_dialog")
	else:
		_file_dialog.call("popup_centered_ratio", 0.5)


func _write_mermaid_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_status.text = "Could not write %s (error %d)." % [path, FileAccess.get_open_error()]
		return
	file.store_string("# MEDS dependencies: %s\n\n%s" % [_graph["title"], get_mermaid()])
	file.close()
	_status.text = "Saved %s." % path


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		return
	if _dirty:
		refresh()
	elif not _layout_done and not _graph.is_empty():
		_request_layout()

@tool
extends RefCounted
## Builds a dependency graph between scene nodes and MEDS variables/events.
##
## Scenes are read through SceneState, so nothing is instantiated and no game code runs.
## Each link is classified by statically analysing the script of the node that holds the
## reference: writes (set_value, `.value =`), raises (raise_event), listens (connects to
## value_changed / event_raised) or reads (`.value`). The analysis is pattern based, so it
## only sees what goes through the exported property (including `for x in property` loops).
##
## Graph format (also consumed by the dock and the Mermaid exporter):
##   {"title": String,
##    "nodes": {id: {"id", "kind", "label", "subtitle", "type", "resource_path", "scene_path", "node_path"}},
##    "edges": [{"from": id, "to": id, "kind": String}]}

const KIND_VARIABLE := "variable"
const KIND_EVENT := "event"
const KIND_NODE := "node"

const EDGE_WRITES := "writes"
const EDGE_RAISES := "raises"
const EDGE_LISTENS := "listens"
const EDGE_READS := "reads"
const EDGE_REFERENCES := "references"
const EDGE_SPAWNS := "spawns"

## Edge kinds that go from a node to a resource; the others go from a resource to a node.
const OUTGOING_EDGE_KINDS := [EDGE_WRITES, EDGE_RAISES]

const _MAX_DEPTH := 16
const _SIGNALS := "(?:value_changed|event_raised|range_changed)"
const _WRITE_METHODS := "(?:set_value|_set_value_variant)"

static var _IDENTIFIER := RegEx.create_from_string("^\\w+$")

## Scene mode: show each top-level instanced sub-scene (HUD, Player...) as one box.
## Project mode: show each scene file as one box.
var collapse_instances := true
## Also scan scenes referenced by exported PackedScene properties (spawners) and add "spawns" links.
var follow_spawned_scenes := true

var _nodes: Dictionary = {}
var _edges: Dictionary = {}
var _usage_cache: Dictionary = {}
var _scanned_roots: Dictionary = {}
var _project_mode := false


func scan_scene(scene_path: String) -> Dictionary:
	_reset(false)
	_scan_root(scene_path)
	return _result(scene_path.get_file())


func scan_project(root_dir: String = "res://") -> Dictionary:
	_reset(true)
	for scene_path in find_scene_files(root_dir):
		_scan_root(scene_path)
	return _result("Whole project")


## Removes scene nodes whose label or path contains one of `patterns` (case-insensitive),
## then drops variables/events that no longer have any link.
static func filter_graph(graph: Dictionary, patterns: PackedStringArray) -> Dictionary:
	var cleaned := PackedStringArray()
	for p in patterns:
		if p.strip_edges() != "":
			cleaned.append(p.strip_edges().to_lower())
	if cleaned.is_empty():
		return graph

	var hidden: Dictionary = {}
	for id in graph["nodes"]:
		var node: Dictionary = graph["nodes"][id]
		if node["kind"] != KIND_NODE:
			continue
		var haystack := ("%s %s %s" % [node["label"], node.get("full_path", ""), node["scene_path"]]).to_lower()
		for p in cleaned:
			if haystack.contains(p):
				hidden[id] = true
				break

	var edges: Array = []
	var linked: Dictionary = {}
	for edge in graph["edges"]:
		if hidden.has(edge["from"]) or hidden.has(edge["to"]):
			continue
		edges.append(edge)
		linked[edge["from"]] = true
		linked[edge["to"]] = true

	var nodes: Dictionary = {}
	for id in graph["nodes"]:
		if linked.has(id):
			nodes[id] = graph["nodes"][id]
	return {"title": graph["title"], "nodes": nodes, "edges": edges}


static func find_scene_files(root_dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	var pending := [root_dir]
	while not pending.is_empty():
		var dir_path: String = pending.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for sub in dir.get_directories():
			if sub.begins_with(".") or (dir_path == "res://" and sub == "addons"):
				continue
			pending.append(dir_path.path_join(sub))
		for file in dir.get_files():
			if file.get_extension() in ["tscn", "scn"]:
				found.append(dir_path.path_join(file))
	found.sort()
	return found


func _reset(project_mode: bool) -> void:
	_project_mode = project_mode
	_nodes.clear()
	_edges.clear()
	_scanned_roots.clear()
	_usage_cache.clear()


# --- Scene traversal ---------------------------------------------------------

## Scans one scene file as a graph root. Returns true if it produced at least one node.
func _scan_root(scene_path: String) -> bool:
	if _scanned_roots.has(scene_path):
		return _scanned_roots[scene_path]
	_scanned_roots[scene_path] = false
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return false
	var entries: Dictionary = {}
	_collect(packed.get_state(), "", scene_path, "", "", entries, not _project_mode, 0)
	var produced := false
	for full_path in entries:
		if _add_links(entries[full_path], scene_path):
			produced = true
	_scanned_roots[scene_path] = produced
	return produced


## Flattens a SceneState into `entries` (full node path -> entry), following instanced
## sub-scenes when `follow_instances` is set. Parent scenes are processed after their
## sub-scenes, so their property overrides win.
func _collect(state: SceneState, prefix: String, scene_file: String, group: String, group_scene: String, entries: Dictionary, follow_instances: bool, depth: int) -> void:
	if state == null or depth > _MAX_DEPTH:
		return
	for i in state.get_node_count():
		var rel := String(state.get_node_path(i))
		if rel.begins_with("./"):
			rel = rel.substr(2)
		var full := _join_path(prefix, rel)
		var node_group := group
		var node_group_scene := group_scene
		var instance := state.get_node_instance(i)
		var instance_script: Script = null
		if instance != null:
			if follow_instances:
				var is_scan_root := depth == 0 and rel == "."
				if node_group == "" and not is_scan_root:
					node_group = full
					node_group_scene = instance.resource_path
				_collect(instance.get_state(), full, instance.resource_path, node_group, node_group_scene, entries, true, depth + 1)
			else:
				instance_script = _root_script(instance, 0)

		var entry: Dictionary = entries.get(full, {})
		if entry.is_empty():
			entry = {
				"full_path": full,
				"name": String(state.get_node_name(i)),
				"defined_scene": scene_file,
				"local_path": rel,
				"group": node_group,
				"group_scene": node_group_scene,
				"script": instance_script,
				"props": {},
			}
			entries[full] = entry
		for p in state.get_node_property_count(i):
			var prop_name := String(state.get_node_property_name(i, p))
			var value: Variant = state.get_node_property_value(i, p)
			if prop_name == "script":
				entry["script"] = value
			elif _is_relevant(value):
				entry["props"][prop_name] = value


func _root_script(packed: PackedScene, depth: int) -> Script:
	if packed == null or depth > _MAX_DEPTH:
		return null
	var state := packed.get_state()
	if state.get_node_count() == 0:
		return null
	for p in state.get_node_property_count(0):
		if String(state.get_node_property_name(0, p)) == "script":
			return state.get_node_property_value(0, p) as Script
	return _root_script(state.get_node_instance(0), depth + 1)


static func _join_path(prefix: String, rel: String) -> String:
	if rel == ".":
		return prefix if prefix != "" else "."
	if prefix == "" or prefix == ".":
		return rel
	return prefix + "/" + rel


static func _is_meds_resource(value: Variant) -> bool:
	return value is BaseVariable or value is Event


static func _is_relevant(value: Variant) -> bool:
	if _is_meds_resource(value) or value is PackedScene:
		return true
	if value is Array:
		for item in value:
			if _is_meds_resource(item) or item is PackedScene:
				return true
	return false


# --- Graph building ----------------------------------------------------------

func _add_links(entry: Dictionary, root_scene: String) -> bool:
	var refs: Array = []
	var spawned: Array = []
	for prop_name in entry["props"]:
		var value: Variant = entry["props"][prop_name]
		var values: Array = value if value is Array else [value]
		for item in values:
			if _is_meds_resource(item):
				refs.append([prop_name, item])
			elif item is PackedScene and follow_spawned_scenes and (item as PackedScene).resource_path != "":
				spawned.append(item)
	if refs.is_empty() and spawned.is_empty():
		return false

	var node_id := ""
	for ref in refs:
		if node_id == "":
			node_id = _ensure_scene_node(entry, root_scene)
		var resource_id := _ensure_resource_node(ref[1])
		for kind in usage_kinds(entry["script"], ref[0]):
			if kind in OUTGOING_EDGE_KINDS:
				_add_edge(node_id, resource_id, kind)
			else:
				_add_edge(resource_id, node_id, kind)

	for packed in spawned:
		var spawned_path: String = (packed as PackedScene).resource_path
		if spawned_path == root_scene:
			continue
		var target_id := _spawned_root_id(spawned_path)
		if target_id == "":
			continue
		if node_id == "":
			node_id = _ensure_scene_node(entry, root_scene)
		_add_edge(node_id, target_id, EDGE_SPAWNS)
	return node_id != ""


## The spawned scene is scanned as an extra root (in project mode it is scanned on its own
## anyway). The "spawns" link targets its root node, and only if that scene uses MEDS
## somewhere: spawned scenes without MEDS references would just be noise.
func _spawned_root_id(spawned_path: String) -> String:
	if not _scan_root(spawned_path):
		return ""
	var root_id := _scene_node_id(spawned_path, ".", "")
	if not _nodes.has(root_id):
		var packed := load(spawned_path) as PackedScene
		var root_name := String(packed.get_state().get_node_name(0)) if packed != null else spawned_path.get_file().get_basename()
		_nodes[root_id] = _make_scene_node(root_id, root_name, spawned_path, ".", spawned_path, "spawned " + spawned_path.get_file(), ".")
	return root_id


func _ensure_scene_node(entry: Dictionary, root_scene: String) -> String:
	var collapsed_group: String = entry["group"] if collapse_instances else ""
	var id := _scene_node_id(root_scene, entry["full_path"], collapsed_group)
	if _nodes.has(id):
		return id

	if _project_mode and collapse_instances:
		_nodes[id] = _make_scene_node(id, root_scene.get_file().get_basename(), root_scene, ".", root_scene, root_scene.get_file(), ".")
	elif collapsed_group != "":
		# One box for a whole instanced sub-scene; opening it selects the instance in the scanned scene.
		var sub_scene: String = entry["group_scene"]
		_nodes[id] = _make_scene_node(id, collapsed_group.get_file(), root_scene, collapsed_group, root_scene, sub_scene.get_file(), collapsed_group)
	else:
		var script := entry["script"] as Script
		var subtitle := script.resource_path.get_file() if script != null and script.resource_path != "" else ""
		if _project_mode:
			subtitle = root_scene.get_file() + (" · " + subtitle if subtitle != "" else "")
		elif root_scene != _first_root() and entry["full_path"] == ".":
			subtitle = "spawned " + root_scene.get_file()
		_nodes[id] = _make_scene_node(id, entry["name"], entry["defined_scene"], entry["local_path"], root_scene, subtitle, entry["full_path"])
	return id


func _first_root() -> String:
	for path in _scanned_roots:
		return path
	return ""


func _scene_node_id(root_scene: String, full_path: String, collapsed_group: String) -> String:
	if _project_mode and collapse_instances:
		return "node:" + root_scene
	return "node:%s::%s" % [root_scene, collapsed_group if collapsed_group != "" else full_path]


func _make_scene_node(id: String, label: String, scene_path: String, node_path: String, root_scene: String, subtitle: String, full_path: String) -> Dictionary:
	return {
		"id": id,
		"kind": KIND_NODE,
		"label": label,
		"subtitle": subtitle,
		"type": "",
		"resource_path": "",
		"scene_path": scene_path,
		"node_path": node_path,
		"root_scene": root_scene,
		"full_path": full_path,
	}


func _ensure_resource_node(resource: Resource) -> String:
	var path := resource.resource_path
	var id := "res:" + (path if path != "" else "builtin:%d" % resource.get_instance_id())
	if _nodes.has(id):
		return id
	var type_name := script_class_name(resource)
	var label := path.get_file().get_basename() if path != "" else (resource.resource_name if resource.resource_name != "" else "(built-in %s)" % type_name)
	_nodes[id] = {
		"id": id,
		"kind": KIND_EVENT if resource is Event else KIND_VARIABLE,
		"label": label,
		"subtitle": type_name,
		"type": type_name,
		"resource_path": path,
		"scene_path": "",
		"node_path": "",
	}
	return id


static func script_class_name(resource: Resource) -> String:
	var script := resource.get_script() as Script
	while script != null:
		var global_name := String(script.get_global_name())
		if global_name != "":
			return global_name
		script = script.get_base_script()
	return resource.get_class()


func _add_edge(from_id: String, to_id: String, kind: String) -> void:
	var key := "%s|%s|%s" % [from_id, to_id, kind]
	if not _edges.has(key):
		_edges[key] = {"from": from_id, "to": to_id, "kind": kind}


func _result(title: String) -> Dictionary:
	_drop_redundant_edges()
	_disambiguate_labels()
	return {"title": title, "nodes": _nodes.duplicate(true), "edges": _edges.values().duplicate(true)}


## After collapsing, one box can both listen to (or write) a variable and read it.
## Listening and writing already imply reading, so the plain "reads" link is noise.
func _drop_redundant_edges() -> void:
	for key in _edges.keys():
		var edge: Dictionary = _edges[key]
		if edge["kind"] != EDGE_READS and edge["kind"] != EDGE_REFERENCES:
			continue
		var stronger := [
			"%s|%s|%s" % [edge["from"], edge["to"], EDGE_LISTENS],
			"%s|%s|%s" % [edge["to"], edge["from"], EDGE_WRITES],
			"%s|%s|%s" % [edge["to"], edge["from"], EDGE_RAISES],
		]
		if edge["kind"] == EDGE_REFERENCES:
			stronger.append("%s|%s|%s" % [edge["from"], edge["to"], EDGE_READS])
		for other in stronger:
			if _edges.has(other):
				_edges.erase(key)
				break


## Gives scene nodes that share a name (e.g. several "Label") a longer, unique label.
func _disambiguate_labels() -> void:
	var by_label: Dictionary = {}
	for id in _nodes:
		var node: Dictionary = _nodes[id]
		if node["kind"] != KIND_NODE:
			continue
		if not by_label.has(node["label"]):
			by_label[node["label"]] = []
		by_label[node["label"]].append(id)
	for label in by_label:
		var ids: Array = by_label[label]
		if ids.size() < 2:
			continue
		for id in ids:
			var node: Dictionary = _nodes[id]
			var longer: String = node["full_path"] if node["full_path"] != "." else label
			if _project_mode or longer == label:
				longer = "%s:%s" % [(node["root_scene"] as String).get_file().get_basename(), longer]
			node["label"] = longer


# --- Script analysis ---------------------------------------------------------

## Returns how `script` uses the MEDS resource stored in its `property_name` property:
## any of writes / raises / listens / reads, or [references] when no usage is recognised.
func usage_kinds(script: Script, property_name: String) -> Array:
	if script == null:
		return [EDGE_REFERENCES]
	var cache_key := "%d|%s" % [script.get_instance_id(), property_name]
	if _usage_cache.has(cache_key):
		return _usage_cache[cache_key]
	var kinds := analyze_source(script_source(script), property_name)
	_usage_cache[cache_key] = kinds
	return kinds


static func script_source(script: Script) -> String:
	var parts := PackedStringArray()
	var current := script
	while current != null:
		var source := current.source_code
		if source == "" and current.resource_path != "" and FileAccess.file_exists(current.resource_path):
			source = FileAccess.get_file_as_string(current.resource_path)
		parts.append(source)
		current = current.get_base_script()
	return "\n".join(parts)


static func analyze_source(source: String, property_name: String) -> Array:
	var code := strip_comments(source)
	var names := [property_name]
	names.append_array(_aliases(code, property_name))
	var target := "\\b(?:%s)\\s*\\.\\s*" % "|".join(names)

	var found: Array = []
	if _matches_any(code, target, [
		_WRITE_METHODS + "\\s*\\(",
		"value\\s*[-+*/%]?=(?!=)",
		"call(?:_deferred)?\\s*\\(\\s*&?[\"']" + _WRITE_METHODS + "[\"']",
		"set(?:_deferred)?\\s*\\(\\s*&?[\"']value[\"']",
	]):
		found.append(EDGE_WRITES)
	if _matches_any(code, target, [
		"raise_event\\s*\\(",
		"call(?:_deferred)?\\s*\\(\\s*&?[\"']raise_event[\"']",
	]):
		found.append(EDGE_RAISES)
	var listens := _matches_any(code, target, [
		_SIGNALS + "\\s*\\.\\s*connect\\s*\\(",
		"connect\\s*\\(\\s*&?[\"']" + _SIGNALS + "[\"']",
	])
	if listens:
		found.append(EDGE_LISTENS)
	# Listeners and writers obviously read the value too; only report plain reads.
	if not listens and not found.has(EDGE_WRITES) and _matches_any(code, target, [
		"(?:value|initial_value|min_value|max_value)\\b(?!\\s*[-+*/%]?=(?!=))",
		"(?:_get_value_variant|get_value)\\s*\\(",
		"get\\s*\\(\\s*&?[\"'](?:value|initial_value)[\"']",
	]):
		found.append(EDGE_READS)
	if found.is_empty():
		found.append(EDGE_REFERENCES)
	return found


## Local names bound to the property: `for x in property:` and `var x := property`.
static func _aliases(code: String, property_name: String) -> Array:
	var aliases: Array = []
	var patterns := [
		"for\\s+(\\w+)(?:\\s*:\\s*[\\w\\[\\]]+)?\\s+in\\s+(?:self\\.)?%s\\b" % property_name,
		"(?m)var\\s+(\\w+)(?:\\s*:\\s*[\\w\\[\\]]+)?\\s*:?=\\s*(?:self\\.)?%s\\s*$" % property_name,
	]
	for pattern in patterns:
		var regex := RegEx.create_from_string(pattern)
		for m in regex.search_all(code):
			var alias := m.get_string(1)
			if alias != property_name and not aliases.has(alias):
				aliases.append(alias)
	return aliases


static func _matches_any(code: String, target: String, suffixes: Array) -> bool:
	for suffix in suffixes:
		var regex := RegEx.create_from_string(target + suffix)
		if regex != null and regex.search(code) != null:
			return true
	return false


## Removes `#` comments (doc comments included) so prose like "## health.value is ..." is ignored,
## and blanks string literals unless they are a bare identifier: `call("set_value")` and
## `connect("value_changed")` still match, while text such as "health.value = 3" does not.
static func strip_comments(source: String) -> String:
	var lines := PackedStringArray()
	for line in source.split("\n"):
		var out := ""
		var quote := ""
		var literal := ""
		var i := 0
		while i < line.length():
			var c := line[i]
			if quote != "":
				if c == "\\" and i + 1 < line.length():
					literal += line.substr(i, 2)
					i += 2
					continue
				if c == quote:
					out += literal if _IDENTIFIER.search(literal) != null else ""
					out += c
					quote = ""
				else:
					literal += c
			elif c == "\"" or c == "'":
				quote = c
				literal = ""
				out += c
			elif c == "#":
				break
			else:
				out += c
			i += 1
		lines.append(out)
	return "\n".join(lines)

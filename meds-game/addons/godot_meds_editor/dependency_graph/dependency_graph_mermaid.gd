@tool
extends RefCounted
## Converts a dependency graph (see dependency_scanner.gd) to a Mermaid flowchart.
##
## Shapes: variables are cylinders, events are stadiums, scene nodes are boxes.
## Links: `-- writes -->`, `-- raises -->`, `-->` (listens), `-. reads .->`,
## `-.-` (references, usage not recognised) and `== spawns ==>`.

const Scanner := preload("res://addons/godot_meds_editor/dependency_graph/dependency_scanner.gd")

const _KIND_ORDER := {Scanner.KIND_NODE: 0, Scanner.KIND_EVENT: 1, Scanner.KIND_VARIABLE: 2}
const _CLASS_STYLES := {
	Scanner.KIND_NODE: "fill:#3a3d45,stroke:#8a8f99,color:#ffffff",
	Scanner.KIND_EVENT: "fill:#5b2d6b,stroke:#c77ddb,color:#ffffff",
	Scanner.KIND_VARIABLE: "fill:#1f4473,stroke:#6fa3e8,color:#ffffff",
}


static func to_mermaid(graph: Dictionary, direction: String = "LR") -> String:
	var lines := PackedStringArray(["flowchart " + direction])
	var ids := _short_ids(graph)

	var by_kind: Dictionary = {}
	for node_id in _sorted_node_ids(graph):
		var node: Dictionary = graph["nodes"][node_id]
		var label := _escape(node["label"])
		var short_id: String = ids[node_id]
		match node["kind"]:
			Scanner.KIND_VARIABLE:
				lines.append("    %s[(\"%s\")]" % [short_id, label])
			Scanner.KIND_EVENT:
				lines.append("    %s([\"%s\"])" % [short_id, label])
			_:
				lines.append("    %s[\"%s\"]" % [short_id, label])
		if not by_kind.has(node["kind"]):
			by_kind[node["kind"]] = PackedStringArray()
		by_kind[node["kind"]].append(short_id)

	for edge in _sorted_edges(graph):
		var from_id: String = ids[edge["from"]]
		var to_id: String = ids[edge["to"]]
		match edge["kind"]:
			Scanner.EDGE_WRITES, Scanner.EDGE_RAISES:
				lines.append("    %s -- %s --> %s" % [from_id, edge["kind"], to_id])
			Scanner.EDGE_LISTENS:
				lines.append("    %s --> %s" % [from_id, to_id])
			Scanner.EDGE_READS:
				lines.append("    %s -. reads .-> %s" % [from_id, to_id])
			Scanner.EDGE_SPAWNS:
				lines.append("    %s == spawns ==> %s" % [from_id, to_id])
			_:
				lines.append("    %s -.- %s" % [from_id, to_id])

	for kind in _CLASS_STYLES:
		if by_kind.has(kind):
			lines.append("    classDef meds_%s %s" % [kind, _CLASS_STYLES[kind]])
			lines.append("    class %s meds_%s" % [",".join(by_kind[kind]), kind])
	return "\n".join(lines) + "\n"


## Mermaid block ready to paste into a Markdown file.
static func to_markdown(graph: Dictionary, direction: String = "LR") -> String:
	return "```mermaid\n%s```\n" % to_mermaid(graph, direction)


static func _short_ids(graph: Dictionary) -> Dictionary:
	var ids: Dictionary = {}
	var index := 0
	for node_id in _sorted_node_ids(graph):
		ids[node_id] = "n%d" % index
		index += 1
	return ids


## Stable order (kind, then label) so exports diff nicely between runs.
static func _sorted_node_ids(graph: Dictionary) -> Array:
	var node_ids: Array = graph["nodes"].keys()
	node_ids.sort_custom(func(a: String, b: String) -> bool:
		var na: Dictionary = graph["nodes"][a]
		var nb: Dictionary = graph["nodes"][b]
		if na["kind"] != nb["kind"]:
			return _KIND_ORDER.get(na["kind"], 9) < _KIND_ORDER.get(nb["kind"], 9)
		return String(na["label"]).naturalnocasecmp_to(nb["label"]) < 0
	)
	return node_ids


static func _sorted_edges(graph: Dictionary) -> Array:
	var ids := _short_ids(graph)
	var order: Dictionary = {}
	for node_id in ids:
		order[node_id] = int(String(ids[node_id]).substr(1))
	var edges: Array = graph["edges"].duplicate()
	edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["from"] != b["from"]:
			return order[a["from"]] < order[b["from"]]
		if a["to"] != b["to"]:
			return order[a["to"]] < order[b["to"]]
		return String(a["kind"]) < String(b["kind"])
	)
	return edges


static func _escape(text: String) -> String:
	return text.replace("\"", "#quot;").replace("<", "#lt;").replace(">", "#gt;")

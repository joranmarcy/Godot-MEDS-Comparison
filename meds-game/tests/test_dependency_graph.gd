extends SceneTree
## Tests the MEDS dependency graph (scanner, Mermaid export, dock) against this game's real scenes.
## Run from the project folder:
##   godot --headless --path . -s res://tests/test_dependency_graph.gd

const Scanner := preload("res://addons/godot_meds_editor/dependency_graph/dependency_scanner.gd")
const Mermaid := preload("res://addons/godot_meds_editor/dependency_graph/dependency_graph_mermaid.gd")
const Dock := preload("res://addons/godot_meds_editor/dependency_graph/dependency_graph_dock.gd")
const MAIN := "res://game/scenes/main.tscn"

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: " + msg)
	else:
		failures += 1
		printerr("FAIL: " + msg)


func _initialize() -> void:
	_run()


func _scan(collapse: bool, spawned: bool = true) -> Dictionary:
	var scanner := Scanner.new()
	scanner.collapse_instances = collapse
	scanner.follow_spawned_scenes = spawned
	return scanner.scan_scene(MAIN)


func _edges(graph: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	for edge in graph["edges"]:
		lines.append("%s -%s-> %s" % [graph["nodes"][edge["from"]]["label"], edge["kind"], graph["nodes"][edge["to"]]["label"]])
	return lines


func _has(graph: Dictionary, line: String) -> bool:
	return _edges(graph).has(line)


func _run() -> void:
	_check_source_analysis()

	var collapsed := _scan(true)
	for line in [
		"Coin -raises-> coin-collected",
		"coin-collected -listens-> ScoreKeeper",
		"ScoreKeeper -writes-> score",
		"ScoreKeeper -writes-> combo",
		"score -listens-> LevelFromScore",
		"LevelFromScore -writes-> level",
		"score -listens-> HighScoreTracker",
		"HighScoreTracker -writes-> high-score",
		"Player -raises-> player-hit",
		"Player -writes-> player-position",
		"player-position -reads-> Enemy",
		"player-hit -listens-> DamageOnPlayerHit",
		"DamageOnPlayerHit -writes-> player-health",
		"player-health -listens-> GameOverOnZeroHealth",
		"GameOverOnZeroHealth -writes-> game-over",
		"GameOverOnZeroHealth -raises-> player-died",
		"score -listens-> HUD",
		"game-over -listens-> GameOverScreen",
		"player-died -listens-> Audio",
		"combo -reads-> Audio",
		"SettingsMenu -writes-> music-volume",
		"CoinSpawner -spawns-> Coin",
		"EnemySpawner -spawns-> Enemy",
	]:
		check(_has(collapsed, line), "collapsed: " + line)
	check(not _has(collapsed, "music-volume -reads-> SettingsMenu"), "collapsed: no redundant 'reads' when a box also listens")
	check(not _has(collapsed, "score -reads-> ScoreKeeper"), "writer is not also reported as reader")
	var hud: Dictionary = collapsed["nodes"].get("node:%s::HUD" % MAIN, {})
	check(hud.get("scene_path") == MAIN and hud.get("node_path") == "HUD", "collapsed HUD opens the HUD instance in main.tscn")
	var keeper: Dictionary = collapsed["nodes"].get("node:%s::GameRules/ScoreKeeper" % MAIN, {})
	check(keeper.get("subtitle") == "score_keeper.gd", "rule node subtitle is its script")

	var expanded := _scan(false)
	for line in [
		"score -listens-> ScoreLabel",
		"coin-collected -listens-> CoinSound",
		"combo -reads-> CoinSound",
		"MusicSlider -writes-> music-volume",
		"music-volume -listens-> MusicSlider",
		"PauseButton -writes-> game-paused",
		"TogglePauseOnAction -writes-> game-paused",
		"game-paused -listens-> PauseTreeWhileTrue",
		"ResetSessionVariables -writes-> score",
		"score -listens-> DebugOverlay",
		"debug-overlay-visible -listens-> Panel",
	]:
		check(_has(expanded, line), "expanded: " + line)
	var label: Dictionary = expanded["nodes"].get("node:%s::HUD/TopBar/Margin/HBox/ScoreLabel" % MAIN, {})
	check(label.get("scene_path") == "res://game/scenes/hud.tscn" and label.get("node_path") == "TopBar/Margin/HBox/ScoreLabel", "expanded node opens in the scene that defines it")
	check(_edges(expanded).size() > _edges(collapsed).size(), "expanding sub-scenes shows more links")

	var no_spawn := _scan(true, false)
	check(not _has(no_spawn, "CoinSpawner -spawns-> Coin") and not _has(no_spawn, "Coin -raises-> coin-collected"), "spawned scenes can be turned off")

	var filtered := Scanner.filter_graph(collapsed, PackedStringArray(["debugoverlay", " ResetSessionVariables "]))
	check(not _has(filtered, "score -listens-> DebugOverlay") and not _has(filtered, "ResetSessionVariables -writes-> score"), "hide filter removes nodes (case-insensitive)")
	check(_has(filtered, "ScoreKeeper -writes-> score"), "hide filter keeps the rest")
	check(not filtered["nodes"].has("res:res://game/variables/debug-overlay-visible.tres") or _has(filtered, "SettingsMenu -writes-> debug-overlay-visible"), "variables only used by hidden nodes disappear")

	var project := Scanner.new().scan_project()
	check(project["nodes"].has("node:res://game/scenes/hud.tscn"), "project scope: one box per scene file")
	check(_has(project, "main -spawns-> coin"), "project scope: spawns between scene files")
	check(not project["nodes"].keys().any(func(id: String) -> bool: return id.contains("addons")), "project scope skips addons/")

	_check_mermaid(collapsed)
	await _check_dock(collapsed)

	print("FAILURES: %d" % failures)
	quit(failures)


func _check_layout(dock: Control, graph: Dictionary) -> void:
	for i in 30:
		await process_frame
		if dock.is_layout_done():
			break
	check(dock.is_layout_done(), "layout: runs once the boxes are sized")
	var ids: Array = graph["nodes"].keys()
	var overlaps := 0
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if dock.get_node_rect(ids[i]).grow(-1).intersects(dock.get_node_rect(ids[j]).grow(-1)):
				overlaps += 1
	check(overlaps == 0, "layout: no overlapping boxes (%d)" % overlaps)

	var missing := 0
	var through := 0
	var forward_strong := 0
	var strong := 0
	for edge in graph["edges"]:
		var route: PackedVector2Array = dock.get_route(edge["from"], edge["to"], edge["kind"])
		if route.size() < 2:
			missing += 1
			continue
		for id in ids:
			if id == edge["from"] or id == edge["to"]:
				continue
			var rect: Rect2 = dock.get_node_rect(id).grow(-3)
			if Array(route).any(func(p: Vector2) -> bool: return rect.has_point(p)):
				through += 1
				break
		if edge["kind"] != Scanner.EDGE_READS and edge["kind"] != Scanner.EDGE_REFERENCES:
			strong += 1
			if dock.get_node_rect(edge["to"]).position.x > dock.get_node_rect(edge["from"]).position.x:
				forward_strong += 1
	check(missing == 0, "layout: every link has a route")
	check(through == 0, "layout: no link is drawn through an unrelated box (%d)" % through)
	check(forward_strong >= strong * 0.85, "layout: cause -> effect links point right (%d/%d)" % [forward_strong, strong])

	var score_id := "res:res://game/variables/score.tres"
	var keeper_id := "node:%s::GameRules/ScoreKeeper" % MAIN
	var level_rule_id := "node:%s::GameRules/LevelFromScore" % MAIN
	check(dock.get_node_rect(keeper_id).position.x < dock.get_node_rect(score_id).position.x
		and dock.get_node_rect(score_id).position.x < dock.get_node_rect(level_rule_id).position.x, "layout: ScoreKeeper -> score -> LevelFromScore left to right")


func _check_port_labels(dock: Control) -> void:
	var enemy_speed: Dictionary = dock.get_port_labels("res:res://game/variables/enemy-speed.tres")
	check(enemy_speed["out"].has("read by") and enemy_speed["out"].has("listened to by") and not enemy_speed["out"].has("reads"), "labels: a variable says 'read by', not 'reads' (%s)" % [enemy_speed])
	var score: Dictionary = dock.get_port_labels("res:res://game/variables/score.tres")
	check(score["in"].has("written by") and not score["in"].has("writes"), "labels: a variable says 'written by' (%s)" % [score])
	var enemy: Dictionary = dock.get_port_labels("node:res://game/scenes/enemy.tscn::.")
	check(enemy["in"].has("reads") and enemy["in"].has("spawned by") and not enemy["in"].has("spawns"), "labels: the reader says 'reads', the spawned scene says 'spawned by' (%s)" % [enemy])
	var spawner: Dictionary = dock.get_port_labels("node:%s::EnemySpawner" % MAIN)
	check(spawner["out"].has("spawns") and spawner["in"].has("reads"), "labels: the spawner says 'spawns' and 'reads' (%s)" % [spawner])
	var keeper: Dictionary = dock.get_port_labels("node:%s::GameRules/ScoreKeeper" % MAIN)
	check(keeper["out"].has("writes") and keeper["in"].has("listens"), "labels: a rule says 'writes' and 'listens' (%s)" % [keeper])


func _check_focus(dock: Control) -> void:
	var keeper := "node:%s::GameRules/ScoreKeeper" % MAIN
	var player := "node:%s::Player" % MAIN
	var score := "res:res://game/variables/score.tres"
	var hit := "res:res://game/events/player-hit.tres"
	var hud := "node:%s::HUD" % MAIN
	dock.select_node(keeper, true)
	await process_frame
	await process_frame
	check(dock.get_node_alpha(keeper) == 1.0 and dock.get_node_alpha(score) == 1.0, "focus: selected box and its neighbours stay opaque")
	check(dock.get_node_alpha(hud) < 0.5 and dock.get_node_alpha(player) < 0.5, "focus: unconnected boxes fade")
	check(dock.get_link_alpha(keeper, score, "writes") == 1.0, "focus: links of the selected box stay opaque")
	check(dock.get_link_alpha(player, hit, "raises") < 0.5, "focus: unrelated links fade")
	check(dock.get_link_alpha(score, hud, "listens") < 0.5, "focus: links between two neighbours of the selection fade too")
	dock.select_node(player, true)
	await process_frame
	await process_frame
	check(dock.get_node_alpha(player) == 1.0 and dock.get_node_alpha(hit) == 1.0 and dock.get_node_alpha(score) == 1.0, "focus: multi-selection keeps both neighbourhoods")
	dock.select_node(keeper, false)
	dock.select_node(player, false)
	await process_frame
	await process_frame
	check(dock.get_node_alpha(hud) == 1.0 and dock.get_link_alpha(player, hit, "raises") == 1.0, "focus: deselecting everything restores the graph")


func _check_source_analysis() -> void:
	var source := """
extends Node
## health.value is documented here but this comment must be ignored
@export var health: IntVariable
@export var hit: Event
@export var others: Array[BaseVariable]
@export var speed: FloatVariable
func _ready():
	hit.event_raised.connect(_on_hit)
	for v in others:
		v.call("set_value", 0, self)
	var label := "speed.value = 3"
func _on_hit():
	if health.value == 0:
		pass
"""
	check(Scanner.analyze_source(source, "hit") == ["listens"], "analysis: event_raised.connect is listens")
	check(Scanner.analyze_source(source, "others") == ["writes"], "analysis: loop alias + call(\"set_value\") is writes")
	check(Scanner.analyze_source(source, "health") == ["reads"], "analysis: `==` is a read, comments ignored")
	check(Scanner.analyze_source(source, "speed") == ["references"], "analysis: text inside strings is not usage")


func _check_mermaid(graph: Dictionary) -> void:
	var text := Mermaid.to_mermaid(graph)
	check(text.begins_with("flowchart LR\n"), "mermaid: flowchart header")
	check(RegEx.create_from_string("n\\d+\\[\\(\"score\"\\)\\]").search(text) != null, "mermaid: variables are cylinders")
	check(RegEx.create_from_string("n\\d+\\(\\[\"player-hit\"\\]\\)").search(text) != null, "mermaid: events are stadiums")
	check(text.contains(" -- writes --> ") and text.contains(" -- raises --> ") and text.contains(" -. reads .-> ") and text.contains(" == spawns ==> "), "mermaid: link styles")
	check(text.count("\n") > graph["edges"].size() + graph["nodes"].size(), "mermaid: one line per node and link")
	check(Mermaid.to_mermaid(graph) == text, "mermaid: deterministic output")
	check(Mermaid.to_markdown(graph).begins_with("```mermaid\n") and Mermaid.to_markdown(graph).ends_with("```\n"), "mermaid: markdown fence")


func _check_dock(graph: Dictionary) -> void:
	var dock: Control = Dock.new()
	dock.size = Vector2(1400, 700)
	root.add_child(dock)
	await process_frame
	dock.set_graph(graph)
	check(dock.get_connection_count() == graph["edges"].size(), "dock: one GraphEdit connection per link (%d)" % dock.get_connection_count())
	check(dock.get_mermaid().begins_with("```mermaid"), "dock: mermaid export")
	await _check_layout(dock, graph)
	_check_port_labels(dock)
	await _check_focus(dock)

	var score := "res://game/variables/score.tres"
	dock.on_variable_value_updated({"path": score, "value_str": "0"})
	check(not dock.is_flashing(score), "dock: first report of a session is not a change")
	dock.on_variable_value_updated({"path": score, "value_str": "10"})
	check(dock.is_flashing(score), "dock: a value change flashes the variable")
	var hit := "res://game/events/player-hit.tres"
	dock.on_event_updated({"path": hit, "raised_count": 0})
	check(not dock.is_flashing(hit), "dock: event registration does not flash")
	dock.on_event_updated({"path": hit, "raised_count": 1})
	check(dock.is_flashing(hit), "dock: a raise flashes the event")
	await create_timer(dock.FLASH_SECONDS + 0.3).timeout
	await process_frame
	check(not dock.is_flashing(score) and not dock.is_flashing(hit), "dock: flashes fade out")
	dock.on_variable_value_updated({"path": "res://unknown.tres", "value_str": "1"})
	dock.clear_runtime()
	check(not dock.is_flashing(score), "dock: clear_runtime resets")
	dock.queue_free()
	await process_frame

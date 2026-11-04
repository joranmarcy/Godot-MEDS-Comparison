extends SceneTree
## Headless gameplay test. Run from the project folder:
##   godot --headless --path . -s res://tests/test_gameplay.gd

const SAVE_PATH := "user://settings.cfg"

var failures := 0
var _save_backup: PackedByteArray
var _had_save := false
var game_over_count := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: " + msg)
	else:
		failures += 1
		printerr("FAIL: " + msg)

func _initialize() -> void:
	_run()

func _backup_save() -> void:
	_had_save = FileAccess.file_exists(SAVE_PATH)
	if _had_save:
		_save_backup = FileAccess.get_file_as_bytes(SAVE_PATH)

func _restore_save() -> void:
	if _had_save:
		FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(_save_backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _run() -> void:
	_backup_save()
	var health: IntVariable = load("res://game/variables/player-health.tres")
	var score: IntVariable = load("res://game/variables/score.tres")
	var combo: IntVariable = load("res://game/variables/combo.tres")
	var level: IntVariable = load("res://game/variables/level.tres")
	var high: IntVariable = load("res://game/variables/high-score.tres")
	var running: BoolVariable = load("res://game/variables/game-running.tres")
	var coin_evt: Event = load("res://game/events/coin-collected.tres")
	var hit_evt: Event = load("res://game/events/player-hit.tres")
	var over_evt: Event = load("res://game/events/game-over.tres")
	over_evt.event_raised.connect(func(): game_over_count += 1)

	var main: Node = load("res://game/scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	check(health.value == 5, "health starts at 5")
	check(running.value, "game running at start")
	check(main.get_node("DebugOverlay").variables.size() == 12, "overlay typed variables array loaded")
	check(main.get_node("DebugOverlay").events.size() == 3, "overlay typed events array loaded")
	check(main.get_node("ResetSessionVariables").variables.size() == 6, "reset typed array loaded")
	check(not main.get_node("GameOverScreen/Root").visible, "game over hidden at start")

	var player: Node2D = main.get_node("Player")
	var coin: Node2D = load("res://game/scenes/coin.tscn").instantiate()
	coin.position = player.global_position
	main.get_node("Coins").add_child(coin)
	for i in 5: await physics_frame
	check(score.value == 10, "physics coin pickup -> score 10 (got %d)" % score.value)
	check(combo.value == 2, "combo 2 after pickup")
	coin_evt.raise_event()
	check(score.value == 30, "second coin x2 -> 30 (got %d)" % score.value)

	var enemy: Node2D = load("res://game/scenes/enemy.tscn").instantiate()
	enemy.position = player.global_position
	main.get_node("Enemies").add_child(enemy)
	for i in 5: await physics_frame
	check(health.value == 4, "physics enemy contact -> health 4 (got %d)" % health.value)
	check(not is_instance_valid(enemy), "enemy exploded")
	check(main.get_node("HUD/TopBar/Margin/HBox/HealthBar").value == 4, "HUD bar follows health")
	check(main.get_node("HUD/TopBar/Margin/HBox/ScoreLabel").text == "Score: 30", "HUD score label")

	score.set_value(450)
	check(level.value == 3, "level from score = 3 (got %d)" % level.value)
	check(high.value >= 450, "high score tracks score")

	for i in 4: hit_evt.raise_event()
	check(health.value == 0, "health 0")
	check(not running.value, "game stopped")
	check(game_over_count == 1, "game over raised once (got %d)" % game_over_count)
	check(main.get_node("GameOverScreen/Root").visible, "game over screen visible")
	hit_evt.raise_event()
	check(game_over_count == 1, "no second game over")
	coin_evt.raise_event()
	check(score.value == 450, "no scoring after game over")

	# Simulate restart (same as reload_current_scene: resources stay alive).
	main.free()
	var main2: Node = load("res://game/scenes/main.tscn").instantiate()
	root.add_child(main2)
	current_scene = main2
	await process_frame
	check(health.value == 5 and score.value == 0 and combo.value == 1 and level.value == 1 and running.value, "restart resets session variables")
	check(high.value >= 450, "high score survives restart")
	check(not main2.get_node("GameOverScreen/Root").visible, "game over hidden after restart")
	for i in 30: await process_frame
	main2.free()
	_restore_save()
	print("FAILURES: %d" % failures)
	quit(failures)

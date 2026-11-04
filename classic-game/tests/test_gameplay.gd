extends SceneTree
## Headless gameplay test. Run from the project folder:
##   godot --headless --path . -s res://tests/test_gameplay.gd

const SAVE_PATH := "user://highscore.cfg"

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
	await process_frame
	var gs: Node = root.get_node("GameState")
	gs.game_over.connect(func(): game_over_count += 1)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	check(gs.health == 5 and gs.is_running, "start state")
	check(not main.get_node("GameOverScreen/Root").visible, "game over hidden at start")
	var player: Node2D = main.get_node("Player")
	var coin: Node2D = load("res://scenes/coin.tscn").instantiate()
	coin.position = player.global_position
	main.get_node("Coins").add_child(coin)
	for i in 5: await physics_frame
	check(gs.score == 10 and gs.combo == 2, "physics coin pickup (score %d combo %d)" % [gs.score, gs.combo])
	gs.collect_coin()
	check(gs.score == 30, "combo scoring")
	var enemy: Node2D = load("res://scenes/enemy.tscn").instantiate()
	enemy.position = player.global_position
	main.get_node("Enemies").add_child(enemy)
	for i in 5: await physics_frame
	check(gs.health == 4, "physics enemy contact (health %d)" % gs.health)
	check(main.get_node("HUD/TopBar/Margin/HBox/ScoreLabel").text == "Score: 30", "HUD score")
	gs.score = 450
	check(gs.level == 3 and gs.high_score >= 450, "level + high score")
	for i in 4: gs.damage_player(1)
	check(gs.health == 0 and not gs.is_running and game_over_count == 1, "game over")
	check(main.get_node("GameOverScreen/Root").visible, "game over screen visible")
	main.free()
	var main2: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main2)
	current_scene = main2
	await process_frame
	check(gs.health == 5 and gs.score == 0 and gs.is_running and gs.high_score >= 450, "restart")
	for i in 30: await process_frame
	main2.free()
	_restore_save()
	print("FAILURES: %d" % failures)
	quit(failures)

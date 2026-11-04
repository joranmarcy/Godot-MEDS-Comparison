extends SceneTree
## Headless gameplay test. Run from the project folder:
##   godot --headless --path . -s res://tests/test_gameplay.gd

const SAVE_PATHS := ["user://highscore.cfg", "user://settings.cfg"]

var failures := 0
var game_over_count := 0
var _save_backups: Dictionary = {}

func check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: " + msg)
	else:
		failures += 1
		printerr("FAIL: " + msg)

func _initialize() -> void:
	_run()

func _backup_saves() -> void:
	for path in SAVE_PATHS:
		if FileAccess.file_exists(path):
			_save_backups[path] = FileAccess.get_file_as_bytes(path)

func _restore_saves() -> void:
	for path in SAVE_PATHS:
		if _save_backups.has(path):
			FileAccess.open(path, FileAccess.WRITE).store_buffer(_save_backups[path])
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _bus_db(bus_name: StringName) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus_name))

func _bus_muted(bus_name: StringName) -> bool:
	return AudioServer.is_bus_mute(AudioServer.get_bus_index(bus_name))

func _press_escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event)

func _saved_value(section: String, key: String) -> Variant:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") != OK:
		return null
	return config.get_value(section, key, null)

func _check_pause_menu(main: Node) -> void:
	var menu_root: Control = main.get_node("SettingsMenu/Root")
	check(not menu_root.visible and not paused, "settings menu closed at start")
	_press_escape()
	check(menu_root.visible and paused, "Esc opens settings menu and pauses")
	_press_escape()
	check(not menu_root.visible and not paused, "Esc closes settings menu and resumes")
	check(main.get_viewport().gui_get_focus_owner() == null, "sliders lose focus when menu closes")

func _run() -> void:
	_backup_saves()
	await process_frame
	var gs: Node = root.get_node("GameState")
	var settings: Node = root.get_node("Settings")
	gs.game_over.connect(func(): game_over_count += 1)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	check(gs.health == 5 and gs.is_running, "start state")
	check(not main.get_node("GameOverScreen/Root").visible, "game over hidden at start")
	check(main.get_node("SoundEffects/Music").playing, "music plays at start")

	var player: Node2D = main.get_node("Player")
	var coin: Node2D = load("res://scenes/coin.tscn").instantiate()
	coin.position = player.global_position
	main.get_node("Coins").add_child(coin)
	for i in 5: await physics_frame
	check(gs.score == 10 and gs.combo == 2, "physics coin pickup (score %d combo %d)" % [gs.score, gs.combo])
	var coin_sound: AudioStreamPlayer = main.get_node("SoundEffects/Coin")
	check(coin_sound.playing and is_equal_approx(coin_sound.pitch_scale, 1.06), "coin sound pitched by combo (%.2f)" % coin_sound.pitch_scale)
	gs.collect_coin()
	check(gs.score == 30, "combo scoring")
	var enemy: Node2D = load("res://scenes/enemy.tscn").instantiate()
	enemy.position = player.global_position
	main.get_node("Enemies").add_child(enemy)
	for i in 5: await physics_frame
	check(gs.health == 4, "physics enemy contact (health %d)" % gs.health)
	check(main.get_node("SoundEffects/Hit").playing, "hit sound")
	check(main.get_node("HUD/TopBar/Margin/HBox/ScoreLabel").text == "Score: 30", "HUD score")
	gs.score = 450
	check(gs.level == 3 and gs.high_score >= 450, "level + high score")
	check(main.get_node("SoundEffects/LevelUp").playing, "level up sound")

	var grid := "SettingsMenu/Root/Center/Panel/Margin/VBox/Grid/"
	settings.sfx_volume = 0.5
	check(is_equal_approx(_bus_db(&"SFX"), linear_to_db(0.5)) and not _bus_muted(&"SFX"), "SFX bus at 50%")
	check(is_equal_approx(main.get_node(grid + "SfxSlider").value, 0.5), "SFX slider follows setting")
	main.get_node(grid + "MusicSlider").value = 0.0
	check(_bus_muted(&"Music") and is_equal_approx(settings.music_volume, 0.0), "music slider at 0 mutes Music bus")
	check(is_equal_approx(float(_saved_value("audio", "sfx_volume")), 0.5), "volume saved to disk")
	settings.music_volume = 0.8
	_check_pause_menu(main)

	for i in 4: gs.damage_player(1)
	check(gs.health == 0 and not gs.is_running and game_over_count == 1, "game over")
	check(main.get_node("GameOverScreen/Root").visible, "game over screen visible")
	check(not main.get_node("SoundEffects/Music").playing, "music stops on game over")
	check(main.get_node("SoundEffects/GameOver").playing, "game over sound")
	main.free()
	var main2: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main2)
	current_scene = main2
	await process_frame
	check(gs.health == 5 and gs.score == 0 and gs.is_running and gs.high_score >= 450, "restart")
	check(main2.get_node("SoundEffects/Music").playing, "music restarts")
	check(not main2.get_node("SoundEffects/LevelUp").playing, "no level up sound on restart reset")
	for i in 30: await process_frame
	main2.free()
	_restore_saves()
	print("FAILURES: %d" % failures)
	quit(failures)

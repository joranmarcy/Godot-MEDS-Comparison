extends SceneTree
## Headless gameplay test. Run from the project folder:
##   godot --headless --path . -s res://tests/test_gameplay.gd

const SAVE_PATHS := ["user://settings.cfg"]

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
	var health: IntVariable = load("res://game/variables/player-health.tres")
	var score: IntVariable = load("res://game/variables/score.tres")
	var combo: IntVariable = load("res://game/variables/combo.tres")
	var level: IntVariable = load("res://game/variables/level.tres")
	var high: IntVariable = load("res://game/variables/high-score.tres")
	var running: BoolVariable = load("res://game/variables/game-running.tres")
	var music_volume: FloatVariable = load("res://game/variables/music-volume.tres")
	var sfx_volume: FloatVariable = load("res://game/variables/sfx-volume.tres")
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
	check(main.get_node("DebugOverlay").variables.size() == 14, "overlay typed variables array loaded")
	check(main.get_node("DebugOverlay").events.size() == 3, "overlay typed events array loaded")
	check(main.get_node("ResetSessionVariables").variables.size() == 6, "reset typed array loaded")
	check(not main.get_node("GameOverScreen/Root").visible, "game over hidden at start")
	check(main.get_node("Audio/MusicWhileRunning").playing, "music plays at start")

	var player: Node2D = main.get_node("Player")
	var coin: Node2D = load("res://game/scenes/coin.tscn").instantiate()
	coin.position = player.global_position
	main.get_node("Coins").add_child(coin)
	for i in 5: await physics_frame
	check(score.value == 10, "physics coin pickup -> score 10 (got %d)" % score.value)
	check(combo.value == 2, "combo 2 after pickup")
	var coin_sound: AudioStreamPlayer = main.get_node("Audio/CoinSound")
	check(coin_sound.playing and is_equal_approx(coin_sound.pitch_scale, 1.06), "coin sound pitched by combo (%.2f)" % coin_sound.pitch_scale)
	coin_evt.raise_event()
	check(score.value == 30, "second coin x2 -> 30 (got %d)" % score.value)

	var enemy: Node2D = load("res://game/scenes/enemy.tscn").instantiate()
	enemy.position = player.global_position
	main.get_node("Enemies").add_child(enemy)
	for i in 5: await physics_frame
	check(health.value == 4, "physics enemy contact -> health 4 (got %d)" % health.value)
	check(not is_instance_valid(enemy), "enemy exploded")
	check(main.get_node("Audio/HitSound").playing, "hit sound")
	check(main.get_node("HUD/TopBar/Margin/HBox/HealthBar").value == 4, "HUD bar follows health")
	check(main.get_node("HUD/TopBar/Margin/HBox/ScoreLabel").text == "Score: 30", "HUD score label")

	score.set_value(450)
	check(level.value == 3, "level from score = 3 (got %d)" % level.value)
	check(high.value >= 450, "high score tracks score")
	check(main.get_node("Audio/LevelUpSound").playing, "level up sound")

	var grid := "SettingsMenu/Root/Center/Panel/Margin/VBox/Grid/"
	sfx_volume.set_value(0.5)
	check(is_equal_approx(_bus_db(&"SFX"), linear_to_db(0.5)) and not _bus_muted(&"SFX"), "SFX bus at 50%")
	check(is_equal_approx(main.get_node(grid + "SfxSlider").value, 0.5), "SFX slider follows variable")
	main.get_node(grid + "MusicSlider").value = 0.0
	check(_bus_muted(&"Music") and is_equal_approx(music_volume.value, 0.0), "music slider at 0 mutes Music bus")
	check(is_equal_approx(float(_saved_value("variables", "res://game/variables/sfx-volume")), 0.5), "volume saved to disk")
	music_volume.set_value(0.8)
	_check_pause_menu(main)

	for i in 4: hit_evt.raise_event()
	check(health.value == 0, "health 0")
	check(not running.value, "game stopped")
	check(game_over_count == 1, "game over raised once (got %d)" % game_over_count)
	check(main.get_node("GameOverScreen/Root").visible, "game over screen visible")
	check(not main.get_node("Audio/MusicWhileRunning").playing, "music stops on game over")
	check(main.get_node("Audio/GameOverSound").playing, "game over sound")
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
	check(is_equal_approx(sfx_volume.value, 0.5), "volume survives restart")
	check(not main2.get_node("GameOverScreen/Root").visible, "game over hidden after restart")
	check(main2.get_node("Audio/MusicWhileRunning").playing, "music restarts")
	check(not main2.get_node("Audio/LevelUpSound").playing, "no level up sound on restart reset")
	for i in 30: await process_frame
	main2.free()
	_restore_saves()
	print("FAILURES: %d" % failures)
	quit(failures)

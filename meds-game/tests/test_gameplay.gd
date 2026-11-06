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

func _press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	root.push_input(event)

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

func _touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)

func _drag(position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = position
	Input.parse_input_event(event)

func _tap(control: Control) -> void:
	var center := control.get_global_rect().get_center()
	_touch(center, true)
	await process_frame
	_touch(center, false)
	await _settle()

# Events sent with Input.parse_input_event() are delivered on the next frame.
func _settle() -> void:
	for i in 2: await process_frame

func _strength(action: StringName) -> float:
	return Input.get_action_strength(action)

func _check_touch_controls(main: Node, player: Node2D) -> void:
	if DisplayServer.get_name() == "headless":
		print("skipped: touch checks need a display (headless never delivers Input.parse_input_event); run without --headless")
		return
	var start := player.global_position
	_touch(Vector2(300, 500), true)
	_drag(Vector2(400, 500))
	await _settle()
	check(is_equal_approx(_strength(&"move_right"), 1.0) and _strength(&"move_left") == 0.0, "touch drag right presses move_right fully")
	for i in 10: await physics_frame
	check(player.global_position.x > start.x + 20.0, "player moves right while dragging (%.0f -> %.0f)" % [start.x, player.global_position.x])
	# The joystick base followed the finger to x=320, so dragging straight down from there is pure "down".
	_drag(Vector2(320, 580))
	await _settle()
	check(is_equal_approx(_strength(&"move_down"), 1.0) and _strength(&"move_right") == 0.0, "joystick base follows finger, drag down")
	_touch(Vector2(320, 580), false)
	await _settle()
	var moving := false
	for action in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		moving = moving or _strength(action) > 0.0
	check(not moving, "releasing the finger releases all move actions")
	var stopped_at := player.global_position
	for i in 5: await physics_frame
	check(player.global_position.is_equal_approx(stopped_at), "player stops after release")

	var menu_root: Control = main.get_node("SettingsMenu/Root")
	var buttons := "SettingsMenu/Root/Center/Panel/Margin/VBox/Buttons/"
	await _tap(main.get_node("HUD/TopBar/Margin/HBox/PauseButton"))
	check(menu_root.visible and paused, "tapping the on-screen pause button opens the menu")
	await _tap(main.get_node(buttons + "DebugOverlayButton"))
	check(main.get_node("DebugOverlay/Panel").visible, "debug overlay button works while paused")
	await _tap(main.get_node(buttons + "DebugOverlayButton"))
	check(not main.get_node("DebugOverlay/Panel").visible, "debug overlay button toggles it off")
	await _tap(main.get_node(buttons + "ResumeButton"))
	check(not menu_root.visible and not paused, "resume button closes the menu")


func _run() -> void:
	_backup_saves()
	var health: IntVariable = load("res://game/variables/player-health.tres")
	var score: IntVariable = load("res://game/variables/score.tres")
	var combo: IntVariable = load("res://game/variables/combo.tres")
	var level: IntVariable = load("res://game/variables/level.tres")
	var high: IntVariable = load("res://game/variables/high-score.tres")
	var game_over: BoolVariable = load("res://game/variables/game-over.tres")
	var music_volume: FloatVariable = load("res://game/variables/music-volume.tres")
	var sfx_volume: FloatVariable = load("res://game/variables/sfx-volume.tres")
	var game_paused: BoolVariable = load("res://game/variables/game-paused.tres")
	var overlay_visible: BoolVariable = load("res://game/variables/debug-overlay-visible.tres")
	var coin_evt: Event = load("res://game/events/coin-collected.tres")
	var hit_evt: Event = load("res://game/events/player-hit.tres")
	var died_evt: Event = load("res://game/events/player-died.tres")
	died_evt.event_raised.connect(func(): game_over_count += 1)

	var main: Node = load("res://game/scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	check(health.value == 5, "health starts at 5")
	check(not game_over.value, "game not over at start")
	check(main.get_node("DebugOverlay").variables.size() == 15, "overlay typed variables array loaded")
	check(main.get_node("DebugOverlay").events.size() == 3, "overlay typed events array loaded")
	check(main.get_node("ResetSessionVariables").variables.size() == 7, "reset typed array loaded")
	check(not main.get_node("GameOverScreen/Root").visible, "game over hidden at start")
	check(main.get_node("Audio/MusicUntilGameOver").playing, "music plays at start")

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
	# Writing the variable is what the Variable Values panel does: it must drive the real pause flow.
	game_paused.set_value(true)
	check(paused and main.get_node("SettingsMenu/Root").visible, "writing game-paused pauses the tree and opens the menu")
	game_paused.set_value(false)
	check(not paused and not main.get_node("SettingsMenu/Root").visible, "clearing game-paused resumes")
	_press_key(KEY_F1)
	check(overlay_visible.value and main.get_node("DebugOverlay/Panel").visible, "F1 toggles debug-overlay-visible")
	_press_key(KEY_F1)
	check(not overlay_visible.value and not main.get_node("DebugOverlay/Panel").visible, "F1 toggles it back off")
	await _check_touch_controls(main, player)

	for i in 4: hit_evt.raise_event()
	check(health.value == 0, "health 0")
	var score_at_game_over := score.value
	check(game_over.value, "game-over set at zero health")
	check(game_over_count == 1, "game over raised once (got %d)" % game_over_count)
	check(main.get_node("GameOverScreen/Root").visible, "game over screen visible")
	check(not main.get_node("Audio/MusicUntilGameOver").playing, "music stops on game over")
	check(main.get_node("Audio/GameOverSound").playing, "game over sound")
	hit_evt.raise_event()
	check(game_over_count == 1, "no second game over")
	coin_evt.raise_event()
	check(score.value == score_at_game_over, "no scoring after game over")

	# Restart while paused and with the overlay open, to check what is reset and what is kept.
	game_paused.set_value(true)
	overlay_visible.set_value(true)
	# Simulate restart (same as reload_current_scene: resources stay alive).
	main.free()
	var main2: Node = load("res://game/scenes/main.tscn").instantiate()
	root.add_child(main2)
	current_scene = main2
	await process_frame
	check(health.value == 5 and score.value == 0 and combo.value == 1 and level.value == 1 and not game_over.value, "restart resets session variables")
	check(high.value >= 450, "high score survives restart")
	check(is_equal_approx(sfx_volume.value, 0.5), "volume survives restart")
	check(not main2.get_node("GameOverScreen/Root").visible, "game over hidden after restart")
	check(not game_paused.value and not paused and not main2.get_node("SettingsMenu/Root").visible, "restart un-pauses (game-paused is a session variable)")
	check(overlay_visible.value and main2.get_node("DebugOverlay/Panel").visible, "debug overlay stays open across restart")
	overlay_visible.set_value(false)
	check(main2.get_node("Audio/MusicUntilGameOver").playing, "music restarts")
	check(not main2.get_node("Audio/LevelUpSound").playing, "no level up sound on restart reset")
	for i in 30: await process_frame
	main2.free()
	_restore_saves()
	print("FAILURES: %d" % failures)
	quit(failures)

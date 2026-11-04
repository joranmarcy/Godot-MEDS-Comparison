extends Node
## Global game state (autoload "GameState").
##
## Classic approach: one singleton owns every piece of shared state and every
## rule that mutates it. Any script can read or write it from anywhere.

signal health_changed(new_health: int)
signal score_changed(new_score: int)
signal combo_changed(new_combo: int)
signal level_changed(new_level: int)
signal high_score_changed(new_high_score: int)
signal coin_collected
signal player_hit
signal game_over

const MAX_HEALTH := 5
const COIN_VALUE := 10
const MAX_COMBO := 10
const COMBO_WINDOW := 2.0
const POINTS_PER_LEVEL := 200
const SAVE_PATH := "user://highscore.cfg"

var is_running := false

var health: int = MAX_HEALTH:
	set(new_value):
		new_value = clampi(new_value, 0, MAX_HEALTH)
		if new_value == health:
			return
		health = new_value
		health_changed.emit(health)

var score: int = 0:
	set(new_value):
		if new_value == score:
			return
		score = new_value
		score_changed.emit(score)
		level = 1 + score / POINTS_PER_LEVEL
		if score > high_score:
			high_score = score

var combo: int = 1:
	set(new_value):
		new_value = clampi(new_value, 1, MAX_COMBO)
		if new_value == combo:
			return
		combo = new_value
		combo_changed.emit(combo)

var level: int = 1:
	set(new_value):
		if new_value == level:
			return
		level = new_value
		level_changed.emit(level)

var high_score: int = 0:
	set(new_value):
		if new_value == high_score:
			return
		high_score = new_value
		high_score_changed.emit(high_score)

var _combo_time_left := 0.0


func _ready() -> void:
	_load_high_score()


func _process(delta: float) -> void:
	if not is_running or combo <= 1:
		return
	_combo_time_left -= delta
	if _combo_time_left <= 0.0:
		combo = 1


func start_game() -> void:
	health = MAX_HEALTH
	score = 0
	combo = 1
	level = 1
	_combo_time_left = 0.0
	is_running = true


func collect_coin() -> void:
	if not is_running:
		return
	score += COIN_VALUE * combo
	combo += 1
	_combo_time_left = COMBO_WINDOW
	coin_collected.emit()


func damage_player(amount: int = 1) -> void:
	if not is_running:
		return
	health -= amount
	player_hit.emit()
	if health <= 0:
		_end_game()


func _end_game() -> void:
	is_running = false
	_save_high_score()
	game_over.emit()


func _load_high_score() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		high_score = int(config.get_value("scores", "high_score", 0))


func _save_high_score() -> void:
	var config := ConfigFile.new()
	config.set_value("scores", "high_score", high_score)
	config.save(SAVE_PATH)

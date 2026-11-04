extends Node
## Plays every game sound by listening to GameState signals.

@export var combo_pitch_step: float = 0.06

@onready var _music: AudioStreamPlayer = $Music
@onready var _coin: AudioStreamPlayer = $Coin
@onready var _hit: AudioStreamPlayer = $Hit
@onready var _level_up: AudioStreamPlayer = $LevelUp
@onready var _game_over: AudioStreamPlayer = $GameOver


func _ready() -> void:
	GameState.coin_collected.connect(_on_coin_collected)
	GameState.player_hit.connect(_hit.play)
	GameState.level_changed.connect(_on_level_changed)
	GameState.game_over.connect(_on_game_over)
	_music.play()


func _on_coin_collected() -> void:
	_coin.pitch_scale = 1.0 + combo_pitch_step * (GameState.combo - 1)
	_coin.play()


func _on_level_changed(new_level: int) -> void:
	# start_game() also emits level_changed(1) when resetting after a restart.
	if new_level > 1:
		_level_up.play()


func _on_game_over() -> void:
	_music.stop()
	_game_over.play()

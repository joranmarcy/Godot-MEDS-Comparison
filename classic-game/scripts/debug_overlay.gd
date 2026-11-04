extends CanvasLayer
## In-game debug overlay (toggle with F1).
##
## Every displayed field and every logged signal is wired by hand: adding a new
## piece of state to GameState means remembering to update this script too.

const MAX_LOG_LINES := 8

@onready var _panel: Control = $Panel
@onready var _label: Label = %OverlayLabel

var _log: PackedStringArray = []


func _ready() -> void:
	_panel.hide()
	GameState.coin_collected.connect(_log_event.bind("coin_collected"))
	GameState.player_hit.connect(_log_event.bind("player_hit"))
	GameState.game_over.connect(_log_event.bind("game_over"))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_panel.visible = not _panel.visible


func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	var lines := PackedStringArray([
		"GAME STATE (hand-written)",
		"is_running: %s" % GameState.is_running,
		"health: %d" % GameState.health,
		"score: %d" % GameState.score,
		"combo: %d" % GameState.combo,
		"level: %d" % GameState.level,
		"high_score: %d" % GameState.high_score,
		"music_volume: %.2f" % Settings.music_volume,
		"sfx_volume: %.2f" % Settings.sfx_volume,
		"",
		"SIGNALS",
	])
	lines.append_array(_log)
	_label.text = "\n".join(lines)


func _log_event(event_name: String) -> void:
	_log.append("%7.2fs  %s" % [Time.get_ticks_msec() / 1000.0, event_name])
	if _log.size() > MAX_LOG_LINES:
		_log.remove_at(0)

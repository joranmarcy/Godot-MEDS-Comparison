extends Node
## Rule: each collected coin adds `coin_value * combo` to the score, then grows the combo.
## The combo falls back to its initial value if no coin is collected within `combo_window` seconds.

@export var coin_collected: Event
@export var game_running: BoolVariable
@export var score: IntVariable
@export var combo: IntVariable
@export var coin_value: IntVariable
@export var combo_window: FloatVariable

var _combo_time_left := 0.0


func _ready() -> void:
	coin_collected.event_raised.connect(_on_coin_collected)


func _process(delta: float) -> void:
	if not game_running.value or combo.value == combo.initial_value:
		return
	_combo_time_left -= delta
	if _combo_time_left <= 0.0:
		combo.set_value(combo.initial_value, self)


func _on_coin_collected() -> void:
	if not game_running.value:
		return
	score.set_value(score.value + coin_value.value * combo.value, self)
	combo.set_value(combo.value + 1, self)
	_combo_time_left = combo_window.value

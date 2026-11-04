extends CanvasLayer

@onready var _root: Control = $Root
@onready var _final_score_label: Label = %FinalScoreLabel
@onready var _best_score_label: Label = %BestScoreLabel
@onready var _restart_button: Button = %RestartButton


func _ready() -> void:
	_root.hide()
	GameState.game_over.connect(_on_game_over)
	_restart_button.pressed.connect(_on_restart_pressed)


func _on_game_over() -> void:
	_final_score_label.text = "Score: %d" % GameState.score
	_best_score_label.text = "Best: %d" % GameState.high_score
	_root.show()
	_restart_button.grab_focus()


func _on_restart_pressed() -> void:
	get_tree().call_deferred("reload_current_scene")

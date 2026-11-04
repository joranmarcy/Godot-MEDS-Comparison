extends CanvasLayer

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _score_label: Label = %ScoreLabel
@onready var _combo_label: Label = %ComboLabel
@onready var _level_label: Label = %LevelLabel
@onready var _high_score_label: Label = %HighScoreLabel


func _ready() -> void:
	_health_bar.max_value = GameState.MAX_HEALTH
	GameState.health_changed.connect(_on_health_changed)
	GameState.score_changed.connect(_on_score_changed)
	GameState.combo_changed.connect(_on_combo_changed)
	GameState.level_changed.connect(_on_level_changed)
	GameState.high_score_changed.connect(_on_high_score_changed)
	_on_health_changed(GameState.health)
	_on_score_changed(GameState.score)
	_on_combo_changed(GameState.combo)
	_on_level_changed(GameState.level)
	_on_high_score_changed(GameState.high_score)


func _on_health_changed(new_health: int) -> void:
	_health_bar.value = new_health


func _on_score_changed(new_score: int) -> void:
	_score_label.text = "Score: %d" % new_score


func _on_combo_changed(new_combo: int) -> void:
	_combo_label.text = "Combo x%d" % new_combo


func _on_level_changed(new_level: int) -> void:
	_level_label.text = "Level %d" % new_level


func _on_high_score_changed(new_high_score: int) -> void:
	_high_score_label.text = "Best: %d" % new_high_score

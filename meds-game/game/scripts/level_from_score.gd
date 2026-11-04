extends Node
## Rule: level = 1 + score / points_per_level.

@export var score: IntVariable
@export var level: IntVariable
@export var points_per_level: int = 200


func _ready() -> void:
	score.value_changed.connect(_on_score_changed)


func _on_score_changed(new_score: int) -> void:
	level.set_value(1 + new_score / points_per_level, self)

extends Node
## Rule: the high score follows the score whenever it is beaten.
## Persistence is handled by MEDS (`save_to_device` on the high score resource).

@export var score: IntVariable
@export var high_score: IntVariable


func _ready() -> void:
	score.value_changed.connect(_on_score_changed)


func _on_score_changed(new_score: int) -> void:
	if new_score > high_score.value:
		high_score.set_value(new_score, self)

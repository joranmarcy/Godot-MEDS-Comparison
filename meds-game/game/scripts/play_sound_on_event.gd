extends AudioStreamPlayer
## Plays this sound whenever `event` is raised.
## Optionally raises the pitch by `pitch_step` per point `pitch_variable` is above its initial value.

@export var event: Event
@export var pitch_variable: IntVariable
@export var pitch_step: float = 0.0


func _ready() -> void:
	event.event_raised.connect(_on_event_raised)


func _on_event_raised() -> void:
	if pitch_variable != null:
		pitch_scale = 1.0 + pitch_step * (pitch_variable.value - pitch_variable.initial_value)
	play()

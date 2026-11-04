extends Node
## Rule: when `event` is raised, `health` loses `damage` points.

@export var event: Event
@export var health: IntVariable
@export var damage: IntVariable


func _ready() -> void:
	event.event_raised.connect(_on_event_raised)


func _on_event_raised() -> void:
	health.set_value(health.value - damage.value, self)

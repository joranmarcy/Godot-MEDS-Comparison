extends ColorRect
## Flashes the screen whenever `event` is raised.

@export var event: Event
@export var flash_color: Color = Color(1, 0.2, 0.2, 0.35)
@export var duration: float = 0.25


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(flash_color, 0.0)
	event.event_raised.connect(_on_event_raised)


func _on_event_raised() -> void:
	color = flash_color
	create_tween().tween_property(self, "color:a", 0.0, duration)

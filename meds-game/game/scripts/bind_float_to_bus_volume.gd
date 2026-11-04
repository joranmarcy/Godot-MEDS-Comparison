extends Node
## Applies a 0..1 FloatVariable to an audio bus volume (muted at 0).

@export var variable: FloatVariable
@export var bus: StringName = &"Master"


func _ready() -> void:
	variable.value_changed.connect(_on_value_changed)
	_on_value_changed(variable.value)


func _on_value_changed(new_value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus)
	if bus_index < 0:
		push_warning("Unknown audio bus: %s" % bus)
		return
	AudioServer.set_bus_mute(bus_index, new_value <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(new_value, 0.0001)))

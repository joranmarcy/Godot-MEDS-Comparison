extends CanvasItem
## Binds this node's visibility to a BoolVariable.

@export var variable: BoolVariable
@export var invert: bool = false


func _ready() -> void:
	variable.value_changed.connect(_on_value_changed)
	_on_value_changed(variable.value)


func _on_value_changed(new_value: bool) -> void:
	visible = new_value != invert

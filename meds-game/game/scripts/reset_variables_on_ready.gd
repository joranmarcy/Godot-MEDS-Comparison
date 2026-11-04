extends Node
## Resets the listed variables to their `initial_value` when the scene starts.
##
## Variables are Resources: they outlive scene reloads while still referenced,
## so the session start is made explicit and visible here. Place this node first
## in the scene so it runs before the other `_ready()` callbacks.

@export var variables: Array[BaseVariable] = []


func _ready() -> void:
	for variable in variables:
		if variable != null:
			variable.call("set_value", variable.get("initial_value"), self)

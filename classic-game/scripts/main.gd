extends Node2D


func _ready() -> void:
	# The autoload survives scene reloads, so its state must be reset by hand.
	GameState.start_game()

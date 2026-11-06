extends CanvasLayer
## Pause menu with volume sliders ("pause" action: Esc, gamepad Start or the on-screen pause button).
##
## Every slider is wired by hand to its Settings property, in both directions.

@onready var _root: Control = $Root
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _sfx_preview: AudioStreamPlayer = $SfxPreview


func _ready() -> void:
	_root.hide()
	_music_slider.value = Settings.music_volume
	_sfx_slider.value = Settings.sfx_volume
	_music_slider.value_changed.connect(_on_music_slider_changed)
	_sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	_sfx_slider.drag_ended.connect(_on_sfx_drag_ended)
	Settings.music_volume_changed.connect(_music_slider.set_value_no_signal)
	Settings.sfx_volume_changed.connect(_sfx_slider.set_value_no_signal)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_set_open(not _root.visible)
		get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	_root.visible = open
	get_tree().paused = open
	if open:
		_music_slider.grab_focus()
	else:
		get_viewport().gui_release_focus()


func _on_music_slider_changed(new_value: float) -> void:
	Settings.music_volume = new_value


func _on_sfx_slider_changed(new_value: float) -> void:
	Settings.sfx_volume = new_value


func _on_sfx_drag_ended(_value_changed: bool) -> void:
	_sfx_preview.play()

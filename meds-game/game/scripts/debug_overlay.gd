extends CanvasLayer
## Generic in-game debug overlay ("toggle_debug_overlay" action: F1, or the button in the pause menu).
## Works in exported builds too, including on phones.
##
## It knows nothing about the game: drag any MEDS variable or event into the
## arrays in the inspector and it is displayed. Recently changed values are
## highlighted, and every event raise is logged with a timestamp.

const MAX_LOG_LINES := 8

@export var variables: Array[BaseVariable] = []
@export var events: Array[Event] = []
@export var highlight_seconds: float = 0.6
@export var highlight_color: Color = Color(1.0, 0.85, 0.3)

@onready var _panel: Control = $Panel
@onready var _label: RichTextLabel = %OverlayLabel

var _changed_at: Dictionary = {}
var _log: PackedStringArray = []


func _ready() -> void:
	_panel.hide()
	for variable in variables:
		if variable != null:
			variable.connect("value_changed", _on_variable_changed.bind(variable))
	for event in events:
		if event != null:
			event.event_raised.connect(_on_event_raised.bind(event))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug_overlay"):
		_panel.visible = not _panel.visible


func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	var now := Time.get_ticks_msec()
	var lines := PackedStringArray(["[b]VARIABLES[/b] (generic, from resources)"])
	for variable in variables:
		if variable == null:
			continue
		var line := "%s: %s" % [_display_name(variable), str(variable.get("value"))]
		var changed_at: int = _changed_at.get(variable, -100000)
		if now - changed_at < int(highlight_seconds * 1000.0):
			line = "[color=#%s]%s[/color]" % [highlight_color.to_html(false), line]
		lines.append(line)
	lines.append("")
	lines.append("[b]EVENTS[/b]")
	lines.append_array(_log)
	_label.text = "\n".join(lines)


func _on_variable_changed(_new_value: Variant, variable: BaseVariable) -> void:
	_changed_at[variable] = Time.get_ticks_msec()


func _on_event_raised(event: Event) -> void:
	_log.append("%7.2fs  %s" % [Time.get_ticks_msec() / 1000.0, _display_name(event)])
	if _log.size() > MAX_LOG_LINES:
		_log.remove_at(0)


func _display_name(resource: Resource) -> String:
	if resource.resource_path.is_empty():
		return resource.resource_name
	return resource.resource_path.get_file().get_basename()

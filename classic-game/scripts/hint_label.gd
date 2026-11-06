extends Label
## Shows `touch_text` instead of the keyboard hint on phones and tablets.

@export_multiline var touch_text: String


func _ready() -> void:
	# Not DisplayServer.is_touchscreen_available(): it is also true on desktop when mouse-to-touch emulation is on.
	var is_mobile := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	if is_mobile and not touch_text.is_empty():
		text = touch_text

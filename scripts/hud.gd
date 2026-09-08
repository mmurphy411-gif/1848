extends CanvasLayer
## The sack total is the only player HUD element.

var label := Label.new()

func _ready() -> void:
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	label.offset_left = -160
	label.offset_top = -54
	label.offset_right = -28
	label.offset_bottom = -28
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.94, 0.90, 0.79))
	var sack := get_node("/root/Sack")
	sack.changed.connect(_update)
	_update(sack.ounces)

func _update(ounces: float) -> void:
	label.text = "%.2f oz" % ounces

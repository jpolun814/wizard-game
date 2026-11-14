class_name KeyCap
extends PanelContainer

## A keyboard key, drawn as a keycap on the book's parchment, the way a mouse button is drawn on a spell's page.

func _init(key_name: String) -> void:
	size_flags_vertical = Control.SIZE_SHRINK_CENTER  # a cap, not a bar as tall as the heading beside it
	var cap := StyleBoxFlat.new()
	cap.bg_color = Color("#e9d7bb")  # parchment-toned, like the mouse
	cap.border_color = Color(0.08, 0.04, 0.08)
	cap.set_border_width_all(2)
	cap.set_corner_radius_all(3)
	cap.content_margin_left = 6.0
	cap.content_margin_right = 6.0
	cap.content_margin_top = 2.0
	cap.content_margin_bottom = 2.0
	add_theme_stylebox_override("panel", cap)
	var label := Label.new()
	label.text = key_name
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.08, 0.04, 0.08))
	add_child(label)

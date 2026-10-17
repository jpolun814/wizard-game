class_name FloatText
extends Label

## A short piece of text that pops up in the world, rises and fades: damage numbers, "Resisted", the name of a
## spell that was just cast. It uses the game's chunky display font with a dark outline so it reads over anything.

const LIFE := 0.8

static var _font: Font


## Shows text centred on a world point. size scales the text: 1 is a normal damage number.
static func spawn(parent: Node, at: Vector2, text: String, colour: Color, size := 1.0) -> FloatText:
	if parent == null:
		return null
	var label := FloatText.new()
	label.text = text
	label.add_theme_font_override("font", font())
	label.add_theme_font_size_override("font_size", roundi(22 * size))
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.12))
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 50
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.size = Vector2(160, 30)
	label.position = at - Vector2(80, 15) + Vector2(randf_range(-6.0, 6.0), 0)
	label.scale = Vector2.ONE * 0.5
	label.pivot_offset = label.size * 0.5
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE * 0.62, 0.08)
	tween.tween_property(label, "scale", Vector2.ONE * 0.5, 0.1)
	tween.parallel().tween_property(label, "position:y", label.position.y - 26.0, LIFE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(label, "modulate:a", 0.0, LIFE * 0.5).set_delay(LIFE * 0.5)
	tween.tween_callback(label.queue_free)
	return label


## The display font, loaded once.
static func font() -> Font:
	if _font == null:
		var pixel: FontFile = load("res://fonts/Jersey15-Regular.ttf")
		pixel.antialiasing = TextServer.FONT_ANTIALIASING_NONE  # a pixel font stays crisp
		_font = pixel
	return _font

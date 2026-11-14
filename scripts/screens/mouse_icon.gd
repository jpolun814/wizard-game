class_name MouseIcon
extends Control

## A mouse seen from above (Kenney's Input Prompts, with the lit pixels of each button kept apart). The buttons in `mask` are
## lit in the school's colour, so the picture shows exactly which buttons a school needs.

const BODY: Texture2D = preload("res://art/ui/mouse/mouse.png")
const BUTTONS := {
	SpellData.LEFT: preload("res://art/ui/mouse/button_left.png"),
	SpellData.MIDDLE: preload("res://art/ui/mouse/button_middle.png"),
	SpellData.RIGHT: preload("res://art/ui/mouse/button_right.png"),
}
var mask := 0
var lit := Color.WHITE
var mouse_scale := 1.0

func _init(button_mask: int, lit_color: Color, size_up := 1.0) -> void:
	mask = button_mask
	lit = lit_color.darkened(0.3) if lit_color.get_luminance() > 0.7 else lit_color  # a pale colour would vanish on the white body
	mouse_scale = size_up
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	custom_minimum_size = Vector2(28, 36) * size_up

func _draw() -> void:
	var area := Rect2(Vector2.ZERO, custom_minimum_size)
	draw_texture_rect(BODY, area, false, Color("#e9d7bb"))  # parchment-toned, so the white does not glare
	for button: int in BUTTONS:
		if mask & button:
			draw_texture_rect(BUTTONS[button], area, false, lit)

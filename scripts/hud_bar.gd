class_name HudBar
extends Control

## A square bar in a dark iron frame, with its name and value written inside it. When the value drops, a pale chunk shows
## how much was lost and then drains away, so you can see how hard a hit was.

@export var fill := Color.WHITE
@export var title := ""

var _value := 1.0
var _max := 1.0
var _cap := 1.0  # the most the bar could ever show: what a hit takes off the most is drawn as a dark gap at its end
var _chip := 1.0  # the share shown by the draining chunk


func set_value(value: float, maximum: float, cap := -1.0) -> void:
	_value = value
	_max = maximum
	_cap = cap if cap > 0.0 else maximum


func _process(delta: float) -> void:
	var share := clampf(_value / _cap, 0.0, 1.0)
	_chip = share if share > _chip else move_toward(_chip, share, delta * 0.6)
	queue_redraw()


## The fill, a lighter line along its top, and the chunk just lost draining away behind it.
func _draw() -> void:
	var share := clampf(_value / _cap, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0b0710"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("#5c4a3c"), false, 2.0)
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("#1b1220"), false, 1.0)
	var inner := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	var most := clampf(_max / _cap, 0.0, 1.0)
	if most < 1.0:  # what hits have taken off the most: a dull red gap at the end
		var from := roundf(inner.size.x * most)
		draw_rect(Rect2(inner.position + Vector2(from, 0), Vector2(inner.size.x - from, inner.size.y)), Color(0.45, 0.06, 0.1, 0.6))
	if _chip > share:
		draw_rect(Rect2(inner.position, Vector2(roundf(inner.size.x * _chip), inner.size.y)), Color(0.95, 0.85, 0.75, 0.7))
	if share > 0.0:
		var width := roundf(inner.size.x * share)
		draw_rect(Rect2(inner.position, Vector2(width, inner.size.y)), fill)
		draw_rect(Rect2(inner.position, Vector2(width, 2)), fill.lightened(0.35))
		draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 2), Vector2(width, 2)), fill.darkened(0.35))
	var font := get_theme_default_font()
	if title != "":
		var text := "%s  %d / %d" % [title, roundi(_value), roundi(_max)]
		var font_size := int(size.y * 0.78)
		var at := Vector2(10, size.y * 0.5 + font_size * 0.32)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.03, 0.01, 0.04, 0.95))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#f3e6d2"))

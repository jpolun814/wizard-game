class_name MenuMark
extends Control

## The ink that marks the inscription the pointer or the keyboard is on: a small gilded diamond before the words and a rule of pixels
## under them, laid down in whole pixels of the book, so it looks written in the book and not placed over it.

var target := Rect2()  # the inscription's box, in the menu's own coordinates; empty when nothing is marked
var cell := 4  # one pixel of the book, on screen
var _clock := 0.0

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _draw() -> void:
	if target.size == Vector2.ZERO:
		return
	var step := float(cell)
	var left := floorf(target.position.x / step) * step
	var base := floorf((target.end.y - step * 1.5) / step) * step
	var wide := floorf(target.size.x / step) * step
	var red := Color(0.431, 0.078, 0.125)
	var glow := 0.75 + sin(_clock * 3.0) * 0.25
	# the rule: a line of pixels with a tick up at each end
	draw_rect(Rect2(left, base, wide, step), Color(red, 0.85))
	draw_rect(Rect2(left, base - step, step, step), Color(red, 0.85))
	draw_rect(Rect2(left + wide - step, base - step, step, step), Color(red, 0.85))
	# a gold leaf in the middle of the rule
	var mid := floorf((left + wide * 0.5) / step) * step
	draw_rect(Rect2(mid - step, base, step * 3, step), Color(Menu.GLOW, glow))
	draw_rect(Rect2(mid, base - step, step, step), Color(Menu.GLOW, glow))
	draw_rect(Rect2(mid, base + step, step, step), Color(Menu.GLOW, glow))

class_name MenuInk
extends Control

## The stroke being drawn, glowing, and fading when it is let go.

var _points := PackedVector2Array()
var _fade := 0.0
var _letting_go := false
var _flare := 0.0
var cell := Spellbook.CELL   # screen pixels to one pixel of the book's art, as for `MenuSign`

func set_stroke(points: PackedVector2Array) -> void:
	_points = points.duplicate()
	_fade = 1.0
	_letting_go = false
	queue_redraw()

func let_go() -> void:
	_letting_go = true

func flare() -> void:
	_flare = 1.0

func _process(delta: float) -> void:
	if _letting_go and _fade > 0.0:
		_fade = maxf(_fade - delta * (2.0 if _flare > 0.0 else 1.2), 0.0)
		queue_redraw()
	if _flare > 0.0:
		_flare = maxf(_flare - delta * 2.0, 0.0)

func _draw() -> void:
	if _points.size() < 2 or _fade <= 0.0:
		return
	var core := PixelInk.along(_points, cell)
	var inner := PixelInk.bleed(core)
	PixelInk.fill(self, PixelInk.bleed(inner), cell, Color(Menu.GLOW, 0.28 * _fade), inner)
	PixelInk.fill(self, inner, cell, Color(Menu.GLOW, 0.6 * _fade), core)
	PixelInk.fill(self, core, cell, Color(1.0, 0.95, 0.75, _fade))

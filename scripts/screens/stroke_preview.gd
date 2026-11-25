class_name StrokePreview
extends Control

## A gesture's shape, inked on a page by a pen that traces it again and again: a line with a fine second line beside it, an arrowhead on the tip of the ink as it
## is drawn, a dot where it starts. A spell that must start on the ground has a hatched line of earth under it.
## It is drawn in whole pixels, on the grid of the book's own art (`PixelInk`, one cell is `Spellbook.CELL` screen pixels), with no smoothing, so the pen's line is
## made of the same pixels as the page it is on. With `framed` it sits in a scrolled ornament drawn in the ink of the writing (`art/ui/book_frame.png`).

const FRAME := preload("res://art/ui/book_frame.png")
const FRAME_ROOM := 24   # pixels of the frame picture, at every side, that the ornament keeps for itself
const CELL := Spellbook.CELL

var points := PackedVector2Array()
var ground := NAN
var framed := false

# The stroke is drawn out again and again, as if the wizard were casting it: it traces itself, then rests with its arrow.
var _clock := 0.0


func _init(pts: PackedVector2Array, ground_y := NAN, side := 48.0, in_frame := false) -> void:
	points = pts
	ground = ground_y
	framed = in_frame
	custom_minimum_size = FRAME.get_size() * CELL if framed else Vector2.ONE * side
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## The first share of a stroke, measured along its length, so the pen moves at an even speed however few or
## unevenly spaced its points are.
func _traced(path: PackedVector2Array, share: float) -> PackedVector2Array:
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	var left := total * share
	var out := PackedVector2Array([path[0]])
	for i in path.size() - 1:
		var step := path[i].distance_to(path[i + 1])
		if step >= left:
			out.append(path[i].lerp(path[i + 1], left / maxf(step, 0.001)))
			return out
		out.append(path[i + 1])
		left -= step
	return out


func _draw() -> void:
	if framed:
		draw_texture_rect(FRAME, Rect2(Vector2.ZERO, FRAME.get_size() * CELL), false)
	if points.size() < 2:
		return
	var bounds := GestureTemplates.bounds(points)
	var extent := maxf(maxf(bounds.size.x, bounds.size.y), 1.0)
	var middle := bounds.get_center()
	var room := (minf(size.x, size.y) - FRAME_ROOM * 2.0 * CELL) if framed else (minf(size.x, size.y) - 14.0)
	var scale_to := room / extent
	var to_pic := func(p: Vector2) -> Vector2:
		return (p - middle) * scale_to + size * 0.5
	var drawn := PackedVector2Array()
	for p in points:
		drawn.append(to_pic.call(p))
	if not is_nan(ground):
		var gy: float = to_pic.call(Vector2(middle.x, ground)).y + 3.0
		var left := (FRAME_ROOM + 2.0) * CELL if framed else 6.0
		var earth := {}
		PixelInk.line_between(Vector2(left, gy), Vector2(size.x - left, gy), CELL, earth)
		PixelInk.fill(self, earth, CELL, Spellbook.SUBTLE)
		var hatch := {}
		for x in range(int(left) + 4, int(size.x - left), int(CELL * 3.0)):
			PixelInk.line_between(Vector2(x, gy + CELL), Vector2(x - CELL * 2.0, gy + CELL * 3.0), CELL, hatch)
		PixelInk.fill(self, hatch, CELL, Spellbook.PAPER_DARK, earth)
	# The ink.
	var length := 0.0
	for i in drawn.size() - 1:
		length += drawn[i].distance_to(drawn[i + 1])
	var duration := clampf(length / 260.0, 0.3, 1.5)  # a short, simple stroke is drawn quickly, a long one slowly
	var shown := clampf(fmod(_clock, duration + 0.8) / duration, 0.0, 1.0)  # it traces itself, then rests
	var traced := _traced(drawn, shown)
	var line := PixelInk.along(traced, CELL)
	PixelInk.fill(self, PixelInk.bleed(line), CELL, Color(Spellbook.INK, 0.16))   # the ink bleeds a cell into the paper, faintly
	PixelInk.fill(self, PixelInk.shifted(line, Vector2i(1, -1)), CELL, Color(Spellbook.HEADING, 0.5), line)   # and a fainter second pass in red, a cell up and across
	PixelInk.fill(self, line, CELL, Spellbook.INK)
	PixelInk.fill(self, PixelInk.block(drawn[0], 1, CELL), CELL, Spellbook.INK)   # the dot where it starts
	# The arrowhead rides the pen: it sits on the tip of the ink the whole time and points the way the pen is travelling
	# there (along the last stretch drawn), so it stays right on loops and spirals too.
	var tip := traced[traced.size() - 1]
	var back := traced[0]
	var walked := 0.0
	for i in range(traced.size() - 1, 0, -1):
		walked += traced[i].distance_to(traced[i - 1])
		back = traced[i - 1]
		if walked >= 14.0:
			break
	var heading := (tip - back).normalized()
	if walked >= 3.0:
		var base := tip - heading * 8.0
		var head := {}
		PixelInk.line_between(tip, base + heading.orthogonal() * 4.0, CELL, head)
		PixelInk.line_between(tip, base - heading.orthogonal() * 4.0, CELL, head)
		PixelInk.fill(self, head, CELL, Spellbook.INK)

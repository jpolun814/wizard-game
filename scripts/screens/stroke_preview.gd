class_name StrokePreview
extends Control

## A gesture's shape, drawn as a hand would ink it: a smooth stroke with a fine second line beside it, an arrowhead
## on the tip of the ink as it is drawn, a dot where it starts. A spell that must start on the ground has a hatched line of earth under it.

var points := PackedVector2Array()
var ground := NAN

# The stroke is drawn out again and again, as if the wizard were casting it: it traces itself, then rests with its arrow.
var _clock := 0.0

func _init(pts: PackedVector2Array, ground_y := NAN, side := 48.0) -> void:
	points = pts
	ground = ground_y
	custom_minimum_size = Vector2.ONE * side

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
	if points.size() < 2:
		return
	var bounds := GestureTemplates.bounds(points)
	var extent := maxf(maxf(bounds.size.x, bounds.size.y), 1.0)
	var middle := bounds.get_center()
	var box := size.x
	var scale_to := (box - 14.0) / extent
	var to_pic := func(p: Vector2) -> Vector2:
		return (p - middle) * scale_to + Vector2.ONE * box * 0.5
	var drawn := PackedVector2Array()
	for p in points:
		drawn.append(to_pic.call(p))
	if not is_nan(ground):
		var gy: float = to_pic.call(Vector2(middle.x, ground)).y + 3.0
		draw_line(Vector2(6.0, gy), Vector2(box - 6.0, gy), Spellbook.SUBTLE, 1.5, true)
		for x in range(10, int(box) - 6, 6):
			draw_line(Vector2(x, gy), Vector2(x - 4.0, gy + 5.0), Spellbook.PAPER_DARK, 1.0, true)
	# The ink: a soft wash underneath, then the line itself and a fainter second pass for a hand-drawn edge.
	var length := 0.0
	for i in drawn.size() - 1:
		length += drawn[i].distance_to(drawn[i + 1])
	var duration := clampf(length / 260.0, 0.3, 1.5)  # a short, simple stroke is drawn quickly, a long one slowly
	var shown := clampf(fmod(_clock, duration + 0.8) / duration, 0.0, 1.0)  # it traces itself, then rests
	var traced := _traced(drawn, shown)
	draw_polyline(traced, Color(Spellbook.INK, 0.18), 5.0, true)
	draw_polyline(traced, Spellbook.INK, 2.2, true)
	var offset := PackedVector2Array()
	for p in traced:
		offset.append(p + Vector2(0.8, -0.6))
	draw_polyline(offset, Color(Spellbook.HEADING, 0.55), 1.0, true)
	draw_circle(drawn[0], 3.0, Spellbook.INK)
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
		var base := tip - heading * 7.0
		draw_line(tip, base + heading.orthogonal() * 3.5, Spellbook.INK, 2.2, true)
		draw_line(tip, base - heading.orthogonal() * 3.5, Spellbook.INK, 2.2, true)

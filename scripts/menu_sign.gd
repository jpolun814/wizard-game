class_name MenuSign
extends Control

## A sign, as a picture in ink: drawn whole, or drawn out stroke by stroke again and again to show how.

var gesture := ""
var animated := false
var _clock := 0.0
var _flare := 0.0

func restart() -> void:
	_clock = 0.0
	queue_redraw()

func flare() -> void:
	_flare = 1.0

func _process(delta: float) -> void:
	if animated and visible:
		_clock += delta
		queue_redraw()
	if _flare > 0.0:
		_flare = maxf(_flare - delta * 2.0, 0.0)
		queue_redraw()

func _draw() -> void:
	var points := PackedVector2Array(Menu.SHAPES[gesture]) if Menu.SHAPES.has(gesture) else GestureTemplates.preview_points(gesture)
	if points.size() < 2:
		return
	var box := Rect2(points[0], Vector2.ZERO)
	for point in points:
		box = box.expand(point)
	var fit := minf(size.x * 0.84 / maxf(box.size.x, 1.0), size.y * 0.84 / maxf(box.size.y, 1.0))
	var fitted := PackedVector2Array()
	for point in points:
		fitted.append((point - box.get_center()) * fit + size * 0.5)
	var shown := fitted
	var head := fitted[fitted.size() - 1]
	if animated:
		var share := clampf(fposmod(_clock, 3.2) / 2.2, 0.0, 1.0)  # drawn out over two seconds, held a moment, then again
		shown = _part(fitted, share)
		head = shown[shown.size() - 1]
	var width := 4.0 if animated else 3.0
	if shown.size() >= 2:
		draw_polyline(shown, Color(Menu.INK, 0.82), width, true)
	if animated:
		draw_circle(head, 6.0, Color(Menu.GLOW, 0.35))
		draw_circle(head, 3.0, Color(1.0, 0.92, 0.6, 0.9))
	if _flare > 0.0:
		draw_polyline(fitted, Color(Menu.GLOW, _flare * 0.8), width + 8.0 * _flare, true)
		draw_polyline(fitted, Color(1.0, 0.95, 0.75, _flare), width, true)

## The first share of a line, by its length.
static func _part(line: PackedVector2Array, share: float) -> PackedVector2Array:
	var left := UnistrokeRecognizer.path_length(line) * share
	var out := PackedVector2Array([line[0]])
	for k in range(1, line.size()):
		var step := line[k - 1].distance_to(line[k])
		if step >= left:
			out.append(line[k - 1].lerp(line[k], left / maxf(step, 0.001)))
			return out
		out.append(line[k])
		left -= step
	return out

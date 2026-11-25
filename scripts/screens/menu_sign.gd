class_name MenuSign
extends Control

## A sign, as a picture in ink: drawn whole, or drawn out stroke by stroke again and again to show how. It is laid in whole pixels on the grid of the book's own
## art (`PixelInk`; `cell` is the size of one, which the menu sets to the pixel of the book it is drawn on), as the strokes on a spell's page are.

var gesture := ""
var animated := false
var cell := Spellbook.CELL   # screen pixels to one pixel of the art
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
	if shown.size() >= 2:
		var line := PixelInk.along(shown, cell)
		if animated:
			PixelInk.fill(self, PixelInk.bleed(line), cell, Color(Menu.INK, 0.38))   # the drawn-out sign is a cell broader
		else:
			line = PixelInk.thick(line)   # the little signs beside the buttons are two cells wide, to hold their own against the lettering
		PixelInk.fill(self, line, cell, Color(Menu.INK, 0.82))
	if animated:
		var dot := PixelInk.block(head, 1, cell)   # the pen: a small block of light, with a halo a cell wide
		PixelInk.fill(self, PixelInk.bleed(dot), cell, Color(Menu.GLOW, 0.35))
		PixelInk.fill(self, dot, cell, Color(1.0, 0.92, 0.6, 0.9))
	if _flare > 0.0:
		var whole := PixelInk.along(fitted, cell)
		var halo := PixelInk.bleed(whole)
		PixelInk.fill(self, PixelInk.bleed(halo), cell, Color(Menu.GLOW, _flare * 0.35), halo)
		PixelInk.fill(self, halo, cell, Color(Menu.GLOW, _flare * 0.8), whole)
		PixelInk.fill(self, whole, cell, Color(1.0, 0.95, 0.75, _flare))

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

class_name WaterPixels
extends RefCounted

## Water drawn from real pixel art (art/fx/water_*.png, made by tools/wizard_parts/water.py in the colors of the ponds) instead of shapes filled in with code: a stream
## is a chain of short tiles laid along a path, each turned to the way the path runs, and the Geyser's dome and mound are sprites.

const STREAM := preload("res://art/fx/water_stream.png")
const CREST := preload("res://art/fx/water_crest.png")
const MOUND := preload("res://art/fx/water_mound.png")
const TILE_LONG := 8.0
const MAX_WIDTH := 48.0
const WIDTHS := 12     # the stream tiles come in widths of 4, 8 ... 48
const FRAMES := 4
const FPS := 10.0
const CREST_SIZE := Vector2(80.0, 32.0)
const MOUND_WIDTHS := [24, 48, 72]


## Lays a stream along a path. `widths` and `alphas` say how wide (pixels across) and how solid it is at each point of the path. `both` lights both sides (a column
## of water standing up) and otherwise the upper side is the lit one (a jet flying along).
static func stream(canvas: CanvasItem, points: PackedVector2Array, widths: PackedFloat32Array, alphas: PackedFloat32Array, age: float, both := false) -> void:
	if points.size() < 2:
		return
	var frame := int(age * FPS) % FRAMES
	var carried := 0.0
	for k in points.size() - 1:
		var from := points[k]
		var way := points[k + 1] - from
		var length := way.length()
		if length < 0.001:
			continue
		var angle := way.angle()
		var flip := -1.0 if cos(angle) < 0.0 and not both else 1.0
		var along := carried
		while along < length:
			var t := along / length
			var width := lerpf(widths[k], widths[k + 1], t)
			var alpha := lerpf(alphas[k], alphas[k + 1], t)
			var row := clampi(roundi(width / 4.0) - 1, 0, WIDTHS - 1) + (WIDTHS if both else 0)
			var w := float((row % WIDTHS) + 1) * 4.0
			var source := Rect2(frame * TILE_LONG, row * MAX_WIDTH + (MAX_WIDTH - w) * 0.5, TILE_LONG, w)
			canvas.draw_set_transform((from + way * t).round(), angle, Vector2(1.0, flip))
			canvas.draw_texture_rect_region(STREAM, Rect2(Vector2(-TILE_LONG * 0.5 - 1.0, -w * 0.5), Vector2(TILE_LONG + 2.0, w)), Rect2(source.position, Vector2(TILE_LONG, w)), Color(1.0, 1.0, 1.0, alpha))
			along += TILE_LONG - 2.0
		carried = along - length
	canvas.draw_set_transform(Vector2.ZERO)


## The dome at the head of a column of water, its middle at `top`.
static func crest(canvas: CanvasItem, top: Vector2, age: float, alpha: float) -> void:
	var frame := int(age * 6.0) % 2
	canvas.draw_texture_rect_region(CREST, Rect2((top - Vector2(CREST_SIZE.x * 0.5, CREST_SIZE.y * 0.65)).round(), CREST_SIZE), Rect2(frame * CREST_SIZE.x, 0.0, CREST_SIZE.x, CREST_SIZE.y), Color(1.0, 1.0, 1.0, alpha))


## Water welling up on the ground, standing on `foot`: the size of mound nearest to `width`.
static func mound(canvas: CanvasItem, foot: Vector2, width: float, alpha: float) -> void:
	var best := 0
	for k in MOUND_WIDTHS.size():
		if absf(MOUND_WIDTHS[k] - width) < absf(MOUND_WIDTHS[best] - width):
			best = k
	var x := 0
	for k in best:
		x += MOUND_WIDTHS[k]
	var w: int = MOUND_WIDTHS[best]
	canvas.draw_texture_rect_region(MOUND, Rect2((foot + Vector2(-w * 0.5, -13.0)).round(), Vector2(w, 14.0)), Rect2(x, 0.0, w, 14.0), Color(1.0, 1.0, 1.0, alpha))

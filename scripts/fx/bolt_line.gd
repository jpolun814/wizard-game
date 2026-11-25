class_name BoltLine
extends RefCounted

## A bolt or a beam laid along a line from art drawn for it (`tools/make_bolt_art.py`): pieces 48 px long, each running from the middle of its left edge to the middle
## of its right, set end to end and turned along the line. Used by Jolt (lightning) and the Eldritch Blast.

const PIECE := 48.0
const BOLTS := preload("res://art/fx/bolt_segments.png")
const BEAMS := preload("res://art/fx/beam_segments.png")


## Lay the pieces of `sheet` (a BOLTS or BEAMS) from one point to another. They flash and fade over `life` seconds.
static func lay(parent: Node, from: Vector2, tip: Vector2, sheet: Texture2D, life := 0.3) -> void:
	var length := from.distance_to(tip)
	if length < 2.0:
		return
	var way := (tip - from) / length
	var variants := int(sheet.get_width() / PIECE)
	var count := maxi(1, ceili(length / PIECE))
	var fit := length / (count * PIECE)  # the last stretch is squeezed or stretched a little so the line ends exactly on its tip
	var last := -1
	for i in count:
		var variant := Dice.looks.randi() % variants
		if variant == last:
			variant = (variant + 1) % variants  # (no two pieces the same one after another)
		last = variant
		var piece := Sprite2D.new()
		var cut := AtlasTexture.new()
		cut.atlas = sheet
		cut.region = Rect2(variant * PIECE, 0.0, PIECE, PIECE)
		piece.texture = cut
		piece.material = Fx.additive()
		piece.z_index = 6
		piece.global_position = from + way * (PIECE * fit * (i + 0.5))
		piece.rotation = way.angle()
		piece.scale = Vector2(fit, 1.0 if Dice.looks.randf() < 0.5 else -1.0)
		parent.add_child(piece)
		var fade := piece.create_tween()
		fade.tween_property(piece, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
		fade.tween_callback(piece.queue_free)

class_name Wreck
extends Node2D

## A wreck on the floor of the ocean (chapter 20): a galleon broken in two on a bank of sand (CraftPix's sunken ship, darkened by
## tools/prepare_ocean_art.py). In the broken-open hull of its stern is an air pocket (AirPocket): a hollow the water has not filled, lit faintly,
## with bubbles rising from it, where a wizard can breathe. A page lies here. It is scenery and the pocket: nothing in it is solid.
## Its origin is the floor under the middle of it.

const SHIP := preload("res://art/props/shipwreck.png")
const BURIED := 60.0  # how far the bank of sand under the ship sinks into the floor, so it meets any floor
const HOLD := 92.0    # how far the broken hold of the stern lies from the middle of the picture: the air pocket is there

var seed_value := 0
var clip: Array = []  # outlines of the open air, in world pixels: when given, the ship is cut to them, so the floor hides what is buried
var pocket: AirPocket


func _ready() -> void:
	z_index = -1  # behind the wizards, in front of the water
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var side := -1.0 if rng.randf() < 0.5 else 1.0  # the stern lies to the right, or the wreck is turned and it lies to the left
	scale.x = side
	_lay_ship()
	pocket = AirPocket.new()
	pocket.position = Vector2(HOLD, 0.0)
	add_child(pocket)
	var light := PointLight2D.new()  # the hollow glows a little: air, lit by what little reaches it
	light.texture = Fx.tex("light_01")
	light.texture_scale = 300.0 / Fx.TEX_SIZE
	light.color = Color(0.7, 0.9, 1.0)
	light.energy = 0.55
	light.position = pocket.position + Vector2(0.0, -pocket.size.y * 0.5)
	add_child(light)
	var bubbles := Fx.trail(Color(0.85, 0.95, 1.0, 0.7), 8, 2.2, 36.0, Vector2(0, -40), "circle_05", 5.0)
	bubbles.position = pocket.position + Vector2(0.0, -8.0)
	bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = 40.0
	bubbles.emitting = true
	add_child(bubbles)


## The ship and its bank of sand, cut to the open water when there are outlines to cut it to, so that wherever the floor under it rises or falls the
## rock covers the part that is buried and nothing shows below the floor.
func _lay_ship() -> void:
	var corner := Vector2(-SHIP.get_width() * 0.5, BURIED - SHIP.get_height())
	if clip.is_empty():
		var whole := Sprite2D.new()
		whole.texture = SHIP
		whole.centered = false
		whole.position = corner
		add_child(whole)
		return
	var box := PackedVector2Array()
	var window := Rect2()
	for point in [corner, corner + Vector2(SHIP.get_width(), 0.0), corner + Vector2(SHIP.get_size()), corner + Vector2(0.0, SHIP.get_height())]:
		var at := to_global(point)
		box.append(at)
		window = Rect2(at, Vector2.ZERO) if box.size() == 1 else window.expand(at)
	for outline: PackedVector2Array in clip:
		var bounds := Rect2(outline[0], Vector2.ZERO)
		for point in outline:
			bounds = bounds.expand(point)
		if not bounds.intersects(window):
			continue
		for part: PackedVector2Array in Geometry2D.intersect_polygons(box, outline):
			var piece := Polygon2D.new()
			var local := PackedVector2Array()
			for point in part:
				local.append(to_local(point))
			piece.polygon = local
			piece.texture = SHIP
			piece.texture_offset = -corner
			add_child(piece)

class_name Wreck
extends Node2D

## A wreck on the floor of the ocean (chapter 20): a galleon broken in two on a bank of sand (CraftPix's sunken ship, darkened by
## tools/prepare_ocean_art.py). It is a thing in the water, not only a picture (owner, 2026-11-12): the hull of the bow is solid and its slanting
## side can be stood on, the deck of the stern is a platform a wizard swims up through and stands on, and the stern's high back is solid. In the hold
## under that deck is an air pocket (AirPocket): a hollow the water has not filled, lit faintly, with bubbles rising from it, where a wizard can breathe.
## A page lies on the floor between the two halves. Its origin is the floor under the middle of it.

const SHIP := preload("res://art/props/shipwreck.png")
const BURIED := 60.0  # how far the bank of sand under the ship sinks into the floor, so it meets any floor
const ORIGIN := Vector2(288.0, 193.0)  # the point of the picture that is the wreck's origin: the middle, on the floor
const HOLD := Vector2(100.0, 0.0)  # the middle of the floor of the hold under the stern deck, from the origin: the air pocket is there
const HOLD_SIZE := Vector2(116.0, 84.0)
# The solid parts, in the picture's own pixels: the bow's hull (its top is the slanting side a wizard can walk down), and the stern's high back. Each
# goes straight down from its outer end into the floor (to SUNK, under the picture's floor line), not along the hull's curve: a wedge of water between an
# overhanging hull and the floor caught swimmers, who could not stroke up out of it and drowned.
const SUNK := 300.0
const BOW := [Vector2(12, 52), Vector2(32, 54), Vector2(80, 72), Vector2(120, 82), Vector2(170, 95), Vector2(215, 110), Vector2(248, 136), Vector2(262, 152),
		Vector2(268, SUNK), Vector2(12, SUNK)]
const STERN := [Vector2(452, 98), Vector2(515, 80), Vector2(545, 72), Vector2(550, 98), Vector2(550, SUNK), Vector2(452, SUNK)]
const DECK := [Vector2(336, 128), Vector2(452, 102)]  # the stern's deck, from its broken end to the back: a one-way platform

var seed_value := 0
var clip: Array = []  # outlines of the open air, in world pixels: when given, the ship is cut to them, so the floor hides what is buried
var pocket: AirPocket


## True when a point lies in or under a wreck: on the floor across its length, up to its decks.
static func covers(tree: SceneTree, point: Vector2) -> bool:
	for wreck: Node2D in tree.get_nodes_in_group("wrecks"):
		var local := point - wreck.global_position
		if absf(local.x) < ORIGIN.x and local.y > -ORIGIN.y + 40.0 and local.y < 80.0:
			return true
	return false


func _ready() -> void:
	add_to_group("wrecks")
	z_index = -1  # behind the wizards, in front of the water
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var side := -1.0 if rng.randf() < 0.5 else 1.0  # the stern lies to the right, or the wreck is turned and it lies to the left
	var look := Node2D.new()  # only the picture is turned by a scale: the solid parts are turned point by point, as physics wants
	look.scale.x = side
	add_child(look)
	_lay_ship(look)
	_build_hull(side)
	pocket = AirPocket.new()
	pocket.size = HOLD_SIZE
	pocket.position = Vector2(HOLD.x * side, HOLD.y)
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
func _lay_ship(look: Node2D) -> void:
	var corner := Vector2(-SHIP.get_width() * 0.5, BURIED - SHIP.get_height())
	if clip.is_empty():
		var whole := Sprite2D.new()
		whole.texture = SHIP
		whole.centered = false
		whole.position = corner
		look.add_child(whole)
		return
	var box := PackedVector2Array()
	var window := Rect2()
	for point in [corner, corner + Vector2(SHIP.get_width(), 0.0), corner + Vector2(SHIP.get_size()), corner + Vector2(0.0, SHIP.get_height())]:
		var at := look.to_global(point)
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
				local.append(look.to_local(point))
			piece.polygon = local
			piece.texture = SHIP
			piece.texture_offset = -corner
			look.add_child(piece)


## The solid parts of the wreck: the bow's hull and the stern's back, which stop everything as ground does, and the stern's deck, which is stood on
## from above and passed up through from below. The points are the picture's, turned to the side the wreck lies.
func _build_hull(side: float) -> void:
	var hull := StaticBody2D.new()
	hull.collision_layer = 1
	hull.collision_mask = 0
	add_child(hull)
	for outline: Array in [BOW, STERN]:
		var shape := CollisionPolygon2D.new()
		var points := PackedVector2Array()
		for point: Vector2 in outline:
			points.append(_placed(point, side))
		if side < 0.0:
			points.reverse()  # (turned over, the outline would run the other way round)
		shape.polygon = points
		hull.add_child(shape)
	var deck := StaticBody2D.new()
	deck.collision_layer = 16  # the platforms: a one-way layer
	deck.collision_mask = 0
	add_child(deck)
	var a := _placed(DECK[0], side)
	var b := _placed(DECK[1], side)
	var plank := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(a.distance_to(b), 8.0)
	plank.shape = rect
	plank.position = (a + b) * 0.5 + Vector2(0.0, 4.0)
	plank.rotation = (b - a).angle() if side > 0.0 else (a - b).angle()
	plank.one_way_collision = true
	plank.one_way_collision_margin = 6.0
	deck.add_child(plank)


func _placed(point: Vector2, side: float) -> Vector2:
	var local := point - ORIGIN
	return Vector2(local.x * side, local.y)

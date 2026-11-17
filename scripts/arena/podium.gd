class_name Podium
extends Node2D

## The marble stairs the spellbook's pedestal stands on, in the waiting room and in the cut-scene that follows it: a landing three columns wide and seven low
## steps down each side (12 px high, 16 px deep), one picture (tools/wizard_parts/props.py podium). With `solid` it can be walked: the collision is a smooth
## ramp along the steps' middles, so a wizard walks up and down it without jumping. `top_at` says how high the stone is at an x position.

const TILE := 32
const TOP_ROWS := 3  # how many tiles high the landing is
const HEIGHT := 96.0  # the landing's height
const LANDING_HALF := 48.0  # half the landing's width
const RAMP := 112.0  # how far each side runs, from the landing's edge to the floor
const MARBLE := preload("res://art/tiles/podium_marble.png")  # 352 x 96: the landing in the middle and the steps either side of it

var center_x := 0.0
var floor_y := 0.0


func _init(x := 0.0, floor := 0.0, solid := false) -> void:
	center_x = x
	floor_y = floor
	z_index = 0
	var stone := Sprite2D.new()
	stone.texture = MARBLE
	stone.centered = false
	stone.position = Vector2(center_x - MARBLE.get_width() * 0.5, floor_y - HEIGHT)
	add_child(stone)
	if solid:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var ramp := ConvexPolygonShape2D.new()
		ramp.points = PackedVector2Array([
			Vector2(center_x - LANDING_HALF - RAMP, floor_y), Vector2(center_x - LANDING_HALF, floor_y - HEIGHT),
			Vector2(center_x + LANDING_HALF, floor_y - HEIGHT), Vector2(center_x + LANDING_HALF + RAMP, floor_y),
		])
		shape.shape = ramp
		body.add_child(shape)
		add_child(body)


## The y of the top of the stone at an x position, for the stairs with their middle at center and the floor at floor_y.
static func top_at(x: float, center: float, floor: float) -> float:
	var past := clampf(absf(x - center) - LANDING_HALF, 0.0, RAMP)
	return floor - HEIGHT * (1.0 - past / RAMP)

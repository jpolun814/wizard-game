class_name CanopyBridge
extends Node2D

## A rope bridge of planks hung between the high ledges of two neighbouring great trees of the jungle, so the treetops can be crossed without
## going down. Its origin is the left end of the planks, at the height of the ledges' tops. It is one-way, like the ledges: jump up through
## it, land on top, and S drops through.

const PLANK := preload("res://art/props/plank.png")

var width := 96.0


func _ready() -> void:
	z_index = 1
	var planks := Sprite2D.new()
	planks.texture = PLANK
	planks.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	planks.region_enabled = true
	planks.region_rect = Rect2(0, 0, width, PLANK.get_height())
	planks.centered = false
	planks.position = Vector2(0.0, -2.0)
	add_child(planks)
	var body := StaticBody2D.new()
	body.collision_layer = 16
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 10.0)
	shape.shape = rect
	shape.position = Vector2(width * 0.5, 5.0)
	shape.one_way_collision = true
	shape.one_way_collision_margin = 6.0
	body.add_child(shape)
	add_child(body)

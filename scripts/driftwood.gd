class_name Driftwood
extends StaticBody2D

## A piece of wreckage floating at the waterline of the ocean (chapter 20): a one-way platform. A wizard swims up through it and stands on it, out of the
## water and breathing, and S drops them back through. It never sinks and cannot burn (it is wet). The picture bobs for looks only: the surface a wizard
## stands on stays where it is, so a landing is always the same and the wizards' plans of the way hold. Its origin is the middle of its top.

const PLANK := preload("res://art/props/plank.png")
const TINT := Color(0.5, 0.42, 0.36)  # old, dark, soaked wood

var width := 96.0
var phase := 0.0
var _boards: Sprite2D
var _t := 0.0


func _ready() -> void:
	add_to_group("driftwood")
	collision_layer = 16  # the platforms: a one-way layer
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 8.0)
	shape.shape = rect
	shape.position = Vector2(0.0, 4.0)
	shape.one_way_collision = true
	shape.one_way_collision_margin = 6.0
	add_child(shape)
	_boards = Sprite2D.new()
	_boards.texture = PLANK
	_boards.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_boards.region_enabled = true
	_boards.region_rect = Rect2(0, 0, width, PLANK.get_height())
	_boards.centered = false
	_boards.position = Vector2(-width * 0.5, -2.0)
	_boards.modulate = TINT
	add_child(_boards)
	z_index = 0


func _process(delta: float) -> void:
	_t += delta
	_boards.position.y = -2.0 + sin(_t * 1.3 + phase) * 2.0  # it rides the swell, to the eye alone
	_boards.rotation = sin(_t * 0.9 + phase) * 0.02

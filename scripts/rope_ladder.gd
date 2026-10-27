class_name RopeLadder
extends Node2D

## A rope ladder hanging through a hatch from one floor of the castle to the one above, climbed like a vine (W climbs, S goes down, a
## sideways key or Space lets go). Its origin is the middle of the hatch on the lower floor.

const GRAB_WIDTH := 22.0
const TEXTURE := preload("res://art/props/rope_ladder.png")

var height := 352.0  # from the lower floor up to the upper one

var _top := Vector2.ZERO
var _bottom := Vector2.ZERO


func _ready() -> void:
	add_to_group("climbables")
	z_index = 1
	var sprite := Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, TEXTURE.get_width(), height + 56.0)
	sprite.centered = false
	sprite.position = Vector2(-TEXTURE.get_width() * 0.5, -height - 56.0)
	add_child(sprite)
	_top = global_position + Vector2(0, -height - 24.0)  # the climber lets go with their feet just over the upper floor
	_bottom = global_position


## True when a point (the climber's hands) is on the ladder: close enough across, and between its top and the lower floor.
func can_grab(point: Vector2) -> bool:
	return absf(point.x - _top.x) <= GRAB_WIDTH and point.y >= _top.y - 4.0 and point.y <= _bottom.y + 12.0


func vine_x() -> float:
	return _top.x

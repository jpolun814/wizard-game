class_name GameCamera
extends Camera2D

## The camera that follows the player. Big impacts shake it for a moment; the shake fades quickly so it never
## gets in the way of drawing a gesture.

const DECAY := 6.0       # how fast a shake dies away, per second
const MAX_OFFSET := 9.0  # the farthest a full-strength shake moves the view, in pixels

var _trauma := 0.0
var _base_offset := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	_base_offset = offset
	add_to_group("game_camera")


## Shakes the view. amount runs from 0 (nothing) to 1 (the biggest shake); shakes add up but never pass 1.
func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


## How far the screen is moving right now, in pixels: the same amount a stroke drawn on the ground is nudged by.
static func shake_px(tree: SceneTree) -> float:
	var camera := tree.get_first_node_in_group("game_camera") as GameCamera
	return camera._trauma * camera._trauma * MAX_OFFSET if camera else 0.0


## Shakes the camera in the current scene, if there is one. Call it from anywhere.
static func shake_scene(tree: SceneTree, amount: float) -> void:
	var camera := tree.get_first_node_in_group("game_camera") as GameCamera
	if camera:
		camera.shake(amount)


func _process(delta: float) -> void:
	_t += delta
	_trauma = maxf(_trauma - DECAY * delta * 0.25, 0.0)
	# Squaring the trauma makes small shakes subtle and big ones strong.
	var strength := _trauma * _trauma * MAX_OFFSET
	offset = _base_offset + Vector2(sin(_t * 47.0) + sin(_t * 23.0) * 0.5, cos(_t * 41.0) + cos(_t * 19.0) * 0.5) * strength * 0.67

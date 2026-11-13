class_name GameCamera
extends Camera2D

## The camera that follows the player. Big impacts shake it for a moment; the shake fades quickly so it never
## gets in the way of drawing a gesture.

const DECAY := 6.0       # how fast a shake dies away, per second
const MAX_OFFSET := 9.0  # the farthest a full-strength shake moves the view, in pixels
const QUAKE_GAIN := 1.7  # how much farther it moves while an Earthquake lasts: the ground is shaking, not only the screen, so a stroke is thrown about more

var _trauma := 0.0
var _base_offset := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	_base_offset = offset
	add_to_group("game_camera")


## Where the view rests, relative to the wizard it follows (a shake moves it about this).
func set_rest_offset(rest: Vector2) -> void:
	_base_offset = rest


## The rest offset now.
func rest_offset() -> Vector2:
	return _base_offset


## Shakes the view. amount runs from 0 (nothing) to 1 (the biggest shake); shakes add up but never pass 1.
func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


## How far the screen is moving right now, in pixels: the same amount a stroke drawn on the ground is nudged by.
static func shake_px(tree: SceneTree) -> float:
	var camera := tree.get_first_node_in_group("game_camera") as GameCamera
	return camera._trauma * camera._trauma * MAX_OFFSET * gain(tree) if camera else 0.0


## 1 normally, and more while an Earthquake lasts.
static func gain(tree: SceneTree) -> float:
	return QUAKE_GAIN if Earthquake.is_shaking(tree) else 1.0


## Shakes the camera in the current scene, if there is one, and the screen every AI wizard would have (Eyes): a shake that reaches a person's
## screen reaches theirs too, and their hand shakes with it as a person's does (WizardBrain._shaken). Call it from anywhere.
static func shake_scene(tree: SceneTree, amount: float) -> void:
	var camera := tree.get_first_node_in_group("game_camera") as GameCamera
	if camera:
		camera.shake(amount)
	for wizard: Wizard in tree.get_nodes_in_group("wizards"):
		if wizard.eyes != null:
			wizard.eyes.shake(amount)


## Shakes this machine's camera alone: for something only the person here feels (their own wizard hurt).
static func shake_scene_camera(tree: SceneTree, amount: float) -> void:
	var camera := tree.get_first_node_in_group("game_camera") as GameCamera
	if camera:
		camera.shake(amount)


## Shakes each screen only as much as its wizard is near the thing that shook: fully at its feet, not at all from `reach` away. The camera
## follows the player; an AI wizard's own screen (Eyes) follows it.
static func shake_near(tree: SceneTree, at: Vector2, amount: float, reach: float) -> void:
	var player := tree.get_first_node_in_group("player") as Node2D
	var camera := tree.get_first_node_in_group("game_camera") as GameCamera
	if camera and player != null:
		camera.shake(amount * _nearness(player.global_position, at, reach))
	for wizard: Wizard in tree.get_nodes_in_group("wizards"):
		if wizard.eyes != null:
			wizard.eyes.shake(amount * _nearness(wizard.global_position, at, reach))


static func _nearness(from: Vector2, at: Vector2, reach: float) -> float:
	return clampf(1.0 - from.distance_to(at) / reach, 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	_trauma = maxf(_trauma - DECAY * delta * 0.25, 0.0)
	# Squaring the trauma makes small shakes subtle and big ones strong.
	var strength := _trauma * _trauma * MAX_OFFSET * gain(get_tree())
	offset = _base_offset + Vector2(sin(_t * 47.0) + sin(_t * 23.0) * 0.5, cos(_t * 41.0) + cos(_t * 19.0) * 0.5) * strength * 0.67

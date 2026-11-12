class_name Eyes
extends RefCounted

## What a wizard's player could see: the screen a person would have, and nothing past it.
##
## A person sees the world through a camera that follows their wizard: a 1280 x 720 window at the game's zoom, with the
## view resting above the feet and catching up smoothly. A brain's wizard is held to the same window, so that it sees
## only what a person in its place could: nothing off the screen, nothing through smoke or an eclipse, nothing in the
## dark that no light falls on, no one faded from sight by Sneak. The world is seen side on, cut through, so a person sees
## into the rooms and tunnels on their screen past the walls between: so does a brain (whether a spell can reach is
## another matter, and the brain asks that of the ground itself). The same view drags a stroke being drawn, as the camera drags a
## person's: the hand draws on the screen, and the screen moves with the wizard (see Wizard.start_drawing).
##
## The view follows the wizard exactly as Godot's Camera2D does with position smoothing (the wizard scene's camera:
## smoothing 7, run in the physics step), and keeps inside the same limits as the person's camera in that world.

const WINDOW := Vector2(1280.0, 720.0)  # the game's default window: what the AI's screen is (owner, 2026-11-09)
const ZOOM := 1.5
const REST := Vector2(0.0, -150.0)      # where the view rests over the feet (the wizard scene's camera offset)
const SMOOTHING := 7.0
const HALF := WINDOW / ZOOM * 0.5       # half the world a screen shows: about 427 x 240 px
const SEEN_UNLIT := 0.12                # an unlit place at least this bright is made out; in darker, only what a light falls on
const LIGHT_REACH := 0.8                # how much of a light's glow lights a thing well enough to be seen
const LIGHTS_EVERY := 30                # physics frames between looks for the lights in the world

static var _lights: Array = []
static var _lights_frame := -1000

var wizard: Wizard
var _at := Vector2.ZERO  # the camera's own position (before the rest offset), smoothed
var _started := false
var _followed := -100  # the physics frame the view last followed the wizard on


func _init(owner: Wizard) -> void:
	wizard = owner


## One physics step: the view catches up with the wizard as the camera would.
func follow(delta: float) -> void:
	_followed = Engine.get_physics_frames()
	var target := wizard.global_position
	if not _started or target.distance_to(_at) > 2000.0:  # the first step, or a jump to a new world: the camera starts there
		_at = target
		_started = true
		return
	_at += (target - _at) * minf(SMOOTHING * delta, 1.0)


## How far the view will slide over the next stretch of time if the wizard keeps going as it is (falling under gravity, when in the air): the drag a
## stroke drawn over that time will take. The view lags behind the wizard, so it starts slowly and catches up.
func slide_over(seconds: float, velocity: Vector2, gravity: float) -> Vector2:
	var step := 1.0 / 60.0
	center()  # (brings a view that has not been following up to date)
	var view := _at - wizard.global_position  # the camera relative to where the wizard is now
	var start := view
	var t := 0.0
	while t < seconds:
		t += step
		var body := Vector2(velocity.x * t, velocity.y * t + 0.5 * gravity * t * t)
		view += (body - view) * minf(SMOOTHING * step, 1.0)
	return view - start


## The middle of the screen, in the world.
func center() -> Vector2:
	if Engine.get_physics_frames() - _followed > 2:
		_at = wizard.global_position  # a wizard that is not being moved by its own steps (held still, or placed by hand): its view is where it is
	var middle := _at + _rest()
	var camera := _camera()
	if camera == null:
		return middle
	# A camera keeps its view inside its limits: near the edge of the world the view stops and the wizard walks on to the side of it.
	var left := float(camera.limit_left) + HALF.x
	var right := float(camera.limit_right) - HALF.x
	var top := float(camera.limit_top) + HALF.y
	var bottom := float(camera.limit_bottom) - HALF.y
	middle.x = (left + right) * 0.5 if left > right else clampf(middle.x, left, right)
	middle.y = (top + bottom) * 0.5 if top > bottom else clampf(middle.y, top, bottom)
	return middle


## The part of the world on the screen.
func rect() -> Rect2:
	return Rect2(center() - HALF, HALF * 2.0)


## True when a point is on the screen.
func on_screen(point: Vector2, margin := 0.0) -> bool:
	return rect().grow(-margin).has_point(point)


## True when a point on the screen is not hidden from the wizard's eyes by ground, a wall, smoke or the dark of an eclipse.
func sees_point(point: Vector2) -> bool:
	if not on_screen(point):
		return false
	var from := wizard.center()
	if SpellTargets.sight_blocked(wizard.get_tree(), from, point):
		return false
	return light_level() >= SEEN_UNLIT or lit(point)


## True when a light (a flare, a fire, a page, a glowing crystal...) shines on a point.
func lit(point: Vector2) -> bool:
	return lit_by(lights_near(Rect2(point, Vector2.ZERO)), point)


## The lights that shine on any part of an area, each as [where, how far it reaches]: found once, for many points to be asked of (see lit_by).
func lights_near(area: Rect2) -> Array:
	var out: Array = []
	for light: PointLight2D in _lights_now():
		if is_instance_valid(light) and light.enabled and light.is_visible_in_tree() and light.texture != null:
			var reach := light.texture_scale * float(light.texture.get_width()) * 0.5 * LIGHT_REACH
			if area.grow(reach).has_point(light.global_position):
				out.append([light.global_position, reach])
	return out


## True when one of these lights (from lights_near) shines on a point.
static func lit_by(lights: Array, point: Vector2) -> bool:
	for light: Array in lights:
		if (light[0] as Vector2).distance_to(point) < float(light[1]):
			return true
	return false


## How bright the unlit world looks on this wizard's screen: the world's tint where it stands, or a room's darkness.
func light_level() -> float:
	var tree := wizard.get_tree()
	var world := tree.get_first_node_in_group(&"world")
	if world != null and world.has_method("light_level_at"):
		return world.light_level_at(wizard.center())
	for node in tree.get_nodes_in_group("darkness"):
		if node is CanvasModulate and node.visible:
			return (node as CanvasModulate).color.get_luminance()
	return 1.0


func _lights_now() -> Array:
	var frame := Engine.get_physics_frames()
	if frame - _lights_frame >= LIGHTS_EVERY or frame < _lights_frame:
		_lights_frame = frame
		_lights = wizard.get_tree().root.find_children("*", "PointLight2D", true, false)
	return _lights


## True when another wizard can be made out: on the screen, in plain sight, and not faded from sight (unless a hex's star floats over them,
## or they are close enough to be bumped into).
func sees_wizard(other: Wizard) -> bool:
	if other == null or not is_instance_valid(other) or other.dead:
		return false
	if not other.is_seen_from(wizard.center()):
		return false
	return sees_point(other.center()) or sees_point(other.global_position + Vector2(0.0, -6.0))


## True when a thing (a shot, a creature, a page) can be seen.
func sees_node(node: Node2D) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	return sees_point(SpellTargets.center_of(node) if node is CollisionObject2D else node.global_position)


func _rest() -> Vector2:
	var camera := _camera()
	return camera.rest_offset() if camera != null else REST


## The person's camera in this world, whose limits and rest the view shares (every wizard's screen has the same edges in one world).
func _camera() -> GameCamera:
	if not is_instance_valid(wizard) or not wizard.is_inside_tree():
		return null
	return wizard.get_tree().get_first_node_in_group("game_camera") as GameCamera

class_name MagicLayer
extends AnimatedSprite2D

## The layer over a wizard made of parts that holds the gem of its weapon, the glow, and every spell effect drawn in its frames. The art draws it in four grays and a
## shader (magic_ramp.gdshader) turns them into the colors of a spell, so the player does not choose the color: the spell does. It is a sprite of its own, laid over
## the body's, and it keeps whatever animation and frame the body is on (the moment they change: a frame behind and the gem leaves the staff).

var _body: AnimatedSprite2D
var _ramp := Color(-1.0, 0.0, 0.0)


func _init() -> void:
	name = "Magic"
	var shaded := ShaderMaterial.new()
	shaded.shader = load("res://scripts/fx/magic_ramp.gdshader")
	material = shaded
	visible = false
	speed_scale = 0.0  # it never plays on its own: it is put on the body's frame each time that changes (a body held still, in ice, must not leave the gem behind)


## Lays this layer over a body, showing the magic of a weapon.
func attach(body: AnimatedSprite2D, weapon: String) -> void:
	if _body != body:
		_body = body
		body.frame_changed.connect(_follow)
		body.animation_changed.connect(_follow)
	sprite_frames = PartFrames.magic(weapon)
	offset = body.offset
	scale = Vector2.ONE if get_parent() == body else body.scale  # (a child already takes its parent's scale)
	visible = true
	_follow()


func detach() -> void:
	visible = false


func _follow() -> void:
	if not visible or _body == null:
		return
	var anim := _body.animation
	if not PartFrames.ensure(sprite_frames, anim):
		return
	animation = anim
	set_frame_and_progress(_body.frame, _body.frame_progress)


## Colors the layer for a spell: the one color the spell has, from which the four of the ramp are made.
func paint(color: Color) -> void:
	if color == _ramp:
		return
	_ramp = color
	var colors := PartFrames.ramp(color)
	var shaded := material as ShaderMaterial
	shaded.set_shader_parameter("near_white", colors[0])
	shaded.set_shader_parameter("light", colors[1])
	shaded.set_shader_parameter("mid", colors[2])
	shaded.set_shader_parameter("deep", colors[3])


## Does as the body does that is not an animation: faces the way it faces, stands where it stands, and fades as it fades (but does not flash red with it).
func mirror(body: AnimatedSprite2D) -> void:
	flip_h = body.flip_h
	position = Vector2.ZERO if get_parent() == body else body.position
	modulate = Color(1.0, 1.0, 1.0, body.modulate.a)


## The part of the picture from the top that shows (see the shader): all of it, or cut off at the waist while the wizard is stuck in the ground.
func set_keep(amount: float) -> void:
	(material as ShaderMaterial).set_shader_parameter("keep", amount)

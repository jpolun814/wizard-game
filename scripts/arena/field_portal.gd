class_name FieldPortal
extends Portal

## One of the portal world's portals. It tells the field when someone steps in. It opens the way the sheet's closing frames run backwards, and
## closes with them over its last moments.

signal entered(portal: FieldPortal, body: Node2D)

const HEARD_WITHIN := 1400.0  # how far from the camera a sound can still be heard (Sfx.MAX_DISTANCE)
const CLOSE_SECONDS := 8.0 / 12.0  # the closing frames, at twelve a second

var tint := Color.WHITE
var lifetime := 30.0
var age := 0.0  # seconds since it opened: the field sets it each frame
var lift := 0.0  # how far above the ground it hangs
var _closing := false
var _backing: AnimatedSprite2D  # a dark copy of the ring under it, drawn the ordinary way, which hides what is behind the glow


func _ready() -> void:
	super()
	collision_mask = 6  # the player and the foes
	_ring.modulate = ring_colour(tint)
	_ring.modulate = ring_colour(tint) * 1.35  # brighter, and over a dark copy of itself (below), so that it is not see-through
	_backing = AnimatedSprite2D.new()
	_backing.sprite_frames = _ring.sprite_frames
	_backing.scale = _ring.scale
	_backing.position = _ring.position
	_backing.modulate = Color(tint.r * 0.3, tint.g * 0.3, tint.b * 0.3, 0.95)
	_backing.z_index = _ring.z_index
	add_child(_backing)
	move_child(_backing, _ring.get_index())  # under the ring
	body_entered.connect(func(body: Node2D) -> void: entered.emit(self, body))
	add_to_group("field_portals")


## It opens from nothing, unless it was already open when this machine first saw it.
func open() -> void:
	_ring.play("appearing" if age < 0.5 else "open")
	if age < 0.5:
		_sound_of_opening()


## The portal hums open, quieter the farther it is from the camera, and not at all from beyond where a sound can be heard.
func _sound_of_opening() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var far := camera.get_screen_center_position().distance_to(global_position)
	if far < HEARD_WITHIN:
		Sfx.play("portal_open", global_position, -6.0 - 12.0 * far / HEARD_WITHIN)


func _process(delta: float) -> void:
	super(delta)
	if _backing.animation != _ring.animation:
		_backing.play(_ring.animation)
	_backing.frame = _ring.frame
	_backing.pause()
	if not _closing and age >= lifetime - CLOSE_SECONDS:
		_closing = true
		_ring.play("closing")


## True once it has begun to close, so nobody is sent to come out of it.
func is_closing() -> bool:
	return _closing


## Seconds it has left open.
func remaining() -> float:
	return lifetime - age


## The ring's picture is violet, so a colour laid over it is evened out first: green would otherwise come out brown, and red the same as orange.
static func ring_colour(wanted: Color) -> Color:
	return Color(wanted.r / 0.55, wanted.g / 0.4, wanted.b / 0.85) * 0.9

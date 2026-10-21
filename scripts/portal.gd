class_name Portal
extends Area2D

## The way on after a wave: a stone archway whose ring of violet light opens up, then swirls, for the player to walk
## into. Pixel art from LetargicDev's Portals, drawn three times its size.

const RY := 28.0  # half the height of the way through; the arena stands the portal this far (and a bit) off the ground
const SINK := 10.0  # the archway's foot is pushed this far into the ground, so the ground hides it

var _t := 0.0


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 52)
	shape.shape = rect
	add_child(shape)
	collision_mask = 4  # the player only
	var arch := AnimatedSprite2D.new()
	var frames := PixelFx.frames("portal_open", 14.0, false).duplicate(true)
	frames.add_animation("loop")
	frames.set_animation_speed("loop", 10.0)
	for frame in PixelFx.frames("portal_loop", 10.0, true).get_frame_count("default"):
		frames.add_frame("loop", PixelFx.frames("portal_loop", 10.0, true).get_frame_texture("default", frame))
	arch.sprite_frames = frames
	arch.scale = Vector2.ONE * 3.0
	arch.modulate = Color(0.7, 0.66, 0.78)  # the violet light, greyed down to sit with the dark stone
	arch.z_index = -2  # behind the ground and the props on it, so the archway sits in the earth rather than on it
	arch.position = Vector2(0, RY + 4.0 - 48.0 + SINK)  # its foot sunk into the ground
	arch.animation_finished.connect(func() -> void: arch.play("loop"))
	add_child(arch)
	arch.play("default")


func _process(delta: float) -> void:
	_t += delta

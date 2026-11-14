class_name LikenessMark
extends Node2D

## The magic mirror of the waiting room, floating over the floating slab, that stands for the wizard maker. Standing before it brings up the page that
## gives the words (see LikenessGuide), as the places of the tutorial do.

const STRIP := preload("res://art/props/magic_mirror.png")  # the frames side by side (see tools/prepare_mirror.py)
const FRAME := Vector2i(18, 32)
const FRAMES := 24
const COLOUR := Color("#b890ff")
const SCALE := 3.0  # whole pixels: a little taller than a wizard
const HOVER := 72.0  # how high the middle of the mirror floats over the slab
const REACH := Vector2(44.0, 48.0)  # how near, across and up, the middle of a wizard must be to its middle for the page to show

var _t := 0.0
var _mirror: AnimatedSprite2D


## True when a wizard whose middle is at a point is before the mirror, near enough to be given the words.
func is_near(point: Vector2) -> bool:
	var at := global_position + Vector2(0.0, -HOVER)
	return absf(point.x - at.x) < REACH.x and absf(point.y - at.y) < REACH.y


func _ready() -> void:
	z_index = -1  # the wizard stands before it
	var frames := SpriteFrames.new()
	frames.add_animation("shine")
	frames.set_animation_speed("shine", 8.0)
	for k in FRAMES:
		var cut := AtlasTexture.new()
		cut.atlas = STRIP
		cut.region = Rect2(k * FRAME.x, 0, FRAME.x, FRAME.y)
		frames.add_frame("shine", cut)
	_mirror = AnimatedSprite2D.new()
	_mirror.sprite_frames = frames
	_mirror.scale = Vector2.ONE * SCALE
	_mirror.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_mirror)
	_mirror.play("shine")


func _process(delta: float) -> void:
	_t += delta
	_mirror.position = Vector2(0.0, -HOVER + roundf(3.0 * sin(_t * 1.6)))  # it floats, and drifts a little
	queue_redraw()


func _draw() -> void:
	var strength := 0.2 + 0.05 * sin(_t * 2.0)
	Fx.draw_glow(self, Vector2(0.0, -HOVER), 70.0, Color(COLOUR.r, COLOUR.g, COLOUR.b, strength))

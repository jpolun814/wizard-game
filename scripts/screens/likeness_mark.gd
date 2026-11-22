class_name LikenessMark
extends Node2D

## The magic mirror of the waiting room, floating over the floating slab, that stands for the wizard maker. Standing before it brings up the page that
## gives the words (see LikenessGuide), as the places of the tutorial do.

const STRIP := preload("res://art/props/magic_mirror.png")  # the frames side by side (see tools/prepare_mirror.py)
const FRAME := Vector2i(18, 32)
const FRAMES := 24
const COLOR := Color("#b890ff")
const SCALE := 3.0  # whole pixels: a little taller than a wizard
const HOVER := 72.0  # how high the middle of the mirror floats over the slab
const REACH := Vector2(44.0, 48.0)  # how near, across and up, the middle of a wizard must be to its middle for the page to show

var _t := 0.0
var _mirror: AnimatedSprite2D
var _glass: Polygon2D  # the oval of the glass: what is drawn inside it is cut to it
var _view: SubViewport  # looks at the world in front of the glass from where the glass hangs
var _camera: Camera2D
var _reflection: Sprite2D


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
	_glass = Polygon2D.new()
	var oval := PackedVector2Array()
	for k in 28:
		var a := TAU * k / 28.0
		oval.append(Vector2(cos(a) * 19.0, sin(a) * 37.0))
	_glass.polygon = oval
	_glass.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(_glass)
	_view = SubViewport.new()  # the glass shows what is before it: the world seen from its place, so that whatever steps in front appears in it
	_view.size = Vector2i(40, 76)
	_view.world_2d = get_viewport().world_2d
	_view.canvas_cull_mask = 0xFFFFFFF9  # (the mirror is on the second layer, so that it does not see itself; the status bubbles are on the third: it shows the wizard, not what ails them)
	_view.transparent_bg = true  # (only what stands before the glass is in it: the violet of the glass shows behind)
	_view.disable_3d = true
	_view.snap_2d_transforms_to_pixel = true
	_camera = Camera2D.new()
	_camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS  # (as the engine would make it anyway, with physics interpolation on)
	_view.add_child(_camera)
	add_child(_view)
	_reflection = Sprite2D.new()
	_reflection.texture = _view.get_texture()
	_reflection.position = Vector2(0.0, -16.0)  # seen a little higher up in the glass, and facing the way the wizard does
	_reflection.modulate = Color(0.72, 0.62, 1.0, 0.9)  # seen through the violet glass
	_reflection.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glass.add_child(_reflection)
	for each: CanvasItem in [self, _mirror, _glass]:
		each.visibility_layer = 2


func _process(delta: float) -> void:
	_t += delta
	_mirror.position = Vector2(0.0, -HOVER + roundf(3.0 * sin(_t * 1.6)))  # it floats, and drifts a little
	_glass.position = _mirror.position
	_camera.global_position = _glass.global_position
	queue_redraw()


func _draw() -> void:
	var strength := 0.2 + 0.05 * sin(_t * 2.0)
	Fx.draw_glow(self, Vector2(0.0, -HOVER), 70.0, Color(COLOR.r, COLOR.g, COLOR.b, strength))

class_name Portal
extends Area2D

## The way into a run: a purple ring that swirls, for the player to walk into. Pixel art from the Purple Portal
## sprite sheet, drawn at two times its size.

const RY := 28.0  # half the height of the way through; the arena stands the portal this far (and a bit) off the ground

var _t := 0.0
var _ring: AnimatedSprite2D  # the purple ring: closed, then opening, then open


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 52)
	shape.shape = rect
	add_child(shape)
	collision_mask = 4  # the player only
	_ring = AnimatedSprite2D.new()
	_ring.sprite_frames = _states()
	_ring.scale = Vector2.ONE * 2.0  # two times its size, like the other effects
	_ring.material = Fx.additive()  # adds its light to what is behind it, so it glows
	_ring.modulate = Color(1.3, 1.05, 1.6)  # a brighter violet
	_ring.position = Vector2(0, -16.0)  # its base sits on the ground it stands on
	_ring.z_index = -1  # behind the ground and anything on it
	_ring.animation_finished.connect(_on_animation_finished)
	add_child(_ring)
	_ring.play("closed")


## The portal opens, and stays open until the player walks through.
func open() -> void:
	_ring.play("opening")


func _on_animation_finished() -> void:
	if _ring.animation == "opening":
		_ring.play("open")


## The ring's three states, made from the sheet's frames: closed (a thin line), opening (it grows into a ring, the
## reverse of closing), and open (the ring swirls on).
static func _states() -> SpriteFrames:
	var strip: SpriteFrames = PixelFx.frames("portal_purple", 12.0, false)
	var out := SpriteFrames.new()
	out.remove_animation("default")
	_add_run(out, "closed", strip, 8, 8, false)
	_add_run(out, "opening", strip, 8, 15, false)
	_add_run(out, "open", strip, 0, 7, true)
	return out


static func _add_run(out: SpriteFrames, name: String, strip: SpriteFrames, first: int, last: int, loop: bool) -> void:
	out.add_animation(name)
	out.set_animation_speed(name, 12.0)
	out.set_animation_loop(name, loop)
	for i in range(first, last + 1):
		out.add_frame(name, strip.get_frame_texture("default", i))


func _process(delta: float) -> void:
	_t += delta

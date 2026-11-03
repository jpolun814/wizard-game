class_name PixelFx

## Pixel-art effect animations from art/fx (one horizontal strip each, cut by tools/prepare_gothic_art.py): a
## fireball, an ice spear, a lightning strike, a column of fire, explosions and smoke. play() drops a one-off effect
## into the world; sprite() makes one to attach to something, such as a projectile.

static var _cache := {}


## The frames of an effect strip, built once and shared.
static func frames(effect: String, fps := 14.0, loop := false, first := 0, last := -1) -> SpriteFrames:
	var key := "%s/%s/%s/%d/%d" % [effect, fps, loop, first, last]
	if _cache.has(key):
		return _cache[key]
	var info: Dictionary = PixelArt.FX[effect]
	var size: Vector2 = info["size"]
	var count: int = info["frames"]
	var strip: Texture2D = load("res://art/fx/%s.png" % effect)
	var out := SpriteFrames.new()
	out.set_animation_speed("default", fps)
	out.set_animation_loop("default", loop)
	for i in range(first, (count - 1 if last < 0 else last) + 1):
		var frame := AtlasTexture.new()
		frame.atlas = strip
		frame.region = Rect2(i * size.x, 0, size.x, size.y)
		out.add_frame("default", frame)
	_cache[key] = out
	return out


## An animated effect, ready to add to the tree. It plays at once.
static func sprite(effect: String, fps := 14.0, loop := true, first := 0, last := -1) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames(effect, fps, loop, first, last)
	s.autoplay = "default"
	return s


## A one-off effect at a point in the world, removed when it has played. "bottom" stands it on the point (for
## things that rise off the ground) instead of centring it there.
static func play(parent: Node, at: Vector2, effect: String, fps := 16.0, scale := 1.0, tint := Color.WHITE,
		bottom := false, flip := false, glow := false) -> AnimatedSprite2D:
	var s := sprite(effect, fps, false)
	s.global_position = at
	s.scale = Vector2(scale, scale)
	s.modulate = tint
	s.flip_h = flip
	s.z_index = 6
	if bottom:
		s.offset = Vector2(0, -PixelArt.FX[effect]["size"].y * 0.5)
	if glow:
		s.material = Fx.additive()
	s.animation_finished.connect(s.queue_free)
	parent.add_child(s)
	return s


## The frames of a strip of square frames (as wide as the strip is tall), such as pimen's fire, built once and shared.
static func square_frames(effect: String, fps := 14.0, loop := false) -> SpriteFrames:
	var key := "square/%s/%s/%s" % [effect, fps, loop]
	if _cache.has(key):
		return _cache[key]
	var strip: Texture2D = load("res://art/fx/%s.png" % effect)
	var side := strip.get_height()
	var out := SpriteFrames.new()
	out.set_animation_speed("default", fps)
	out.set_animation_loop("default", loop)
	for i in int(strip.get_width() / float(side)):
		var frame := AtlasTexture.new()
		frame.atlas = strip
		frame.region = Rect2(i * side, 0, side, side)
		out.add_frame("default", frame)
	_cache[key] = out
	return out


## A one-off effect from a strip of square frames at a point in the world, turned to a heading, removed when it has played.
static func play_square(parent: Node, at: Vector2, effect: String, fps := 16.0, scale := 1.0, turn := 0.0) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = square_frames(effect, fps)
	s.global_position = at
	s.rotation = turn
	s.scale = Vector2(scale, scale)
	s.z_index = 6
	s.animation_finished.connect(s.queue_free)
	parent.add_child(s)
	s.play("default")
	return s


## One frame of the pixel fire the flames are cut from, for the embers that fly off fire.
static func ember() -> Texture2D:
	return frames("flame").get_frame_texture("default", 20)

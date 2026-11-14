class_name Fx
extends RefCounted

## Shared visual effects for spells and hits, built from Kenney's particle textures (art/particles). Each helper
## makes a short-lived effect and cleans it up when it is done.

## Particle textures are 128 px; these turn a wanted size in pixels into a particle scale.
const TEX_SIZE := 128.0

static var _textures := {}


## A particle texture from art/particles, by name (for example "flame_05" or "smoke_01").
static func tex(texture_name: String) -> Texture2D:
	if not _textures.has(texture_name):
		_textures[texture_name] = load("res://art/particles/%s.png" % texture_name)
	return _textures[texture_name]


## Fades a colour from solid to transparent over a particle's life.
static func fade_ramp(color: Color) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray([color, Color(color.r, color.g, color.b, 0.0)])
	return g


## A colour that starts white-hot, turns to the colour, and fades out. Fire and magic burn like this.
static func hot_ramp(color: Color) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 0.92, 1), color, Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	return g


## Particles that add light to whatever is behind them, so overlapping sparks glow.
static func additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## One burst of sparks at a point, cleaned up when it finishes. Glowing bursts add light; the others are solid
## little stars, so they read on bright backgrounds too.
static func burst(parent: Node, pos: Vector2, color: Color, amount := 18, speed := 140.0, lifetime := 0.5, glow := false, texture := "") -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 160)
	p.damping_min = 30.0
	p.damping_max = 80.0
	p.texture = tex(texture if texture != "" else ("circle_05" if glow else "star_04"))
	p.scale_amount_min = 8.0 / TEX_SIZE
	p.scale_amount_max = 18.0 / TEX_SIZE
	p.color_ramp = hot_ramp(color) if glow else fade_ramp(color)
	p.material = additive() if glow else null
	p.global_position = pos
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.emitting = true
	return p


## Continuous sparks that leave a trail in the world. Add it to a moving node with local_coords off,
## so the particles stay where they were released.
static func trail(color: Color, amount := 60, lifetime := 0.35, spread := 20.0, gravity := Vector2.ZERO, texture := "circle_05", size := 7.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = Vector2.ZERO
	p.spread = spread
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 40.0
	p.gravity = gravity
	p.scale_amount_min = size * 0.6 / TEX_SIZE
	p.scale_amount_max = size * 1.4 / TEX_SIZE
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = shrink
	p.texture = tex(texture)
	p.color_ramp = fade_ramp(color)
	p.material = additive()
	p.emitting = true
	return p


## A single sprite that grows, turns and fades out: an impact flash, a shockwave ring, a puff.
## size is its width in pixels at the start; grow is how much bigger it ends.
static func pop(parent: Node, pos: Vector2, texture: String, color: Color, size := 40.0, life := 0.3, grow := 1.8, spin := 0.0, glow := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(texture)
	s.global_position = pos
	s.modulate = color
	s.rotation = randf() * TAU if spin != 0.0 else 0.0
	s.scale = Vector2.ONE * size / TEX_SIZE
	if glow:
		s.material = additive()
	s.z_index = 5
	parent.add_child(s)
	var tween := s.create_tween()
	tween.set_parallel(true)
	tween.tween_property(s, "scale", s.scale * grow, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(s, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	if spin != 0.0:
		tween.tween_property(s, "rotation", s.rotation + spin * life, life)
	tween.chain().tween_callback(s.queue_free)
	return s


## A bright flash with a ring around it, for anything that hits hard.
static func impact(parent: Node, pos: Vector2, color: Color, size := 40.0) -> void:
	pop(parent, pos, "circle_05", Color(color.r, color.g, color.b, 0.9), size, 0.22, 1.6)
	pop(parent, pos, "circle_02", Color(color.r, color.g, color.b, 0.8), size * 0.5, 0.3, 2.4)
	burst(parent, pos, color, 10, 160.0, 0.35, true, "star_04")


## Puffs of smoke rising and spreading. Not glowing, so they darken what is behind them.
static func smoke(parent: Node, pos: Vector2, color: Color, amount := 6, size := 26.0, rise := 40.0) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = amount
	p.lifetime = 0.9
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = rise * 0.4
	p.initial_velocity_max = rise
	p.gravity = Vector2(0, -20)
	p.damping_min = 20.0
	p.damping_max = 40.0
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -60.0
	p.angular_velocity_max = 60.0
	p.texture = tex("smoke_04")
	p.scale_amount_min = size * 0.6 / TEX_SIZE
	p.scale_amount_max = size / TEX_SIZE
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.6))
	grow.add_point(Vector2(1, 1.4))
	p.scale_amount_curve = grow
	p.color_ramp = fade_ramp(color)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.emitting = true


## Bits of rock and earth thrown up that fall back down.
static func debris(parent: Node, pos: Vector2, color: Color, amount := 10, speed := 220.0) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.8
	p.direction = Vector2.UP
	p.spread = 55.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 700)
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.texture = tex("dirt_02")
	p.scale_amount_min = 8.0 / TEX_SIZE
	p.scale_amount_max = 16.0 / TEX_SIZE
	p.color_ramp = fade_ramp(color)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.emitting = true


## Concentric circles that read as a glowing orb. Call from a _draw().
static func draw_orb(canvas: CanvasItem, radius: float, color: Color, core := Color.WHITE) -> void:
	canvas.draw_texture_rect(tex("circle_05"), Rect2(-Vector2.ONE * radius * 3.0, Vector2.ONE * radius * 6.0), false, Color(color.r, color.g, color.b, 0.55))
	canvas.draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.85))
	canvas.draw_circle(Vector2.ZERO, radius * 0.5, Color(core.r, core.g, core.b, 0.95))


## Draws a glow texture centred on a point from inside a _draw(). The canvas should use additive blending.
static func draw_glow(canvas: CanvasItem, at: Vector2, radius: float, color: Color, texture := "circle_05") -> void:
	canvas.draw_texture_rect(tex(texture), Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, color)

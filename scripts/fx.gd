class_name Fx
extends RefCounted

## Shared particle helpers for spell effects and hits. Everything is built in code,
## so a new effect is just a few settings.

static var _dot: GradientTexture2D


## A soft round dot, used as the particle image so sparks look like glowing motes, not squares.
static func dot_texture() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 32
		_dot.height = 32
	return _dot


## Fades a colour from solid to transparent over a particle's life.
static func fade_ramp(color: Color) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray([color, Color(color.r, color.g, color.b, 0.0)])
	return g


## Particles that add light to whatever is behind them, so overlapping sparks glow.
static func additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## One burst of sparks at a point, cleaned up when it finishes.
static func burst(parent: Node, pos: Vector2, color: Color, amount := 18, speed := 140.0, lifetime := 0.5, glow := false) -> CPUParticles2D:
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
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.texture = dot_texture() if glow else null  # crisp square sparks unless asked for a soft glow
	p.color_ramp = fade_ramp(color)
	p.material = additive() if glow else null
	p.global_position = pos
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.emitting = true
	return p


## Continuous sparks that leave a trail in the world. Add it to a moving node with local_coords off,
## so the particles stay where they were released.
static func trail(color: Color, amount := 60, lifetime := 0.35, spread := 20.0, gravity := Vector2.ZERO) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = Vector2.ZERO
	p.spread = spread
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 40.0
	p.gravity = gravity
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.texture = dot_texture()
	p.color_ramp = fade_ramp(color)
	p.material = additive()
	p.emitting = true
	return p


## Concentric circles that read as a glowing orb. Call from a _draw().
static func draw_orb(canvas: CanvasItem, radius: float, color: Color, core := Color.WHITE) -> void:
	canvas.draw_circle(Vector2.ZERO, radius * 2.2, Color(color.r, color.g, color.b, 0.10))
	canvas.draw_circle(Vector2.ZERO, radius * 1.5, Color(color.r, color.g, color.b, 0.22))
	canvas.draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.75))
	canvas.draw_circle(Vector2.ZERO, radius * 0.5, Color(core.r, core.g, core.b, 0.95))

class_name BookAura
extends Node2D

## What shows the book is no ordinary book: a violet glow that breathes behind it and violet smoke curling up off its top. Its origin is the
## middle of the book. The lectern wears it, and so does the book the winner carries.

var _clock := 0.0
var _glow: Node2D


func _ready() -> void:
	var height := Lectern.book_height()
	_glow = Node2D.new()
	_glow.material = Fx.additive()
	_glow.draw.connect(func() -> void:
		var breathe := 1.0 + 0.12 * sin(_clock * 2.2)
		Fx.draw_glow(_glow, Vector2.ZERO, 78.0 * breathe, Color(0.6, 0.22, 1.0, 0.6))
		Fx.draw_glow(_glow, Vector2.ZERO, 44.0 * breathe, Color(0.75, 0.45, 1.0, 0.45)))
	add_child(_glow)
	var smoke := CPUParticles2D.new()
	smoke.amount = 22
	smoke.lifetime = 2.2
	smoke.position = Vector2(0.0, -height * 0.5)
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(15.0, 2.0)
	smoke.direction = Vector2.UP
	smoke.spread = 30.0
	smoke.initial_velocity_min = 8.0
	smoke.initial_velocity_max = 20.0
	smoke.gravity = Vector2(0.0, -6.0)
	smoke.angle_min = -180.0
	smoke.angle_max = 180.0
	smoke.angular_velocity_min = -30.0
	smoke.angular_velocity_max = 30.0
	smoke.texture = Fx.tex("smoke_04")
	smoke.scale_amount_min = 22.0 / Fx.TEX_SIZE
	smoke.scale_amount_max = 40.0 / Fx.TEX_SIZE
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.5))
	smoke.scale_amount_curve = grow
	smoke.color_ramp = Fx.fade_ramp(Color(0.7, 0.35, 1.0, 0.9))
	smoke.material = Fx.additive()  # it glows, as magic does
	smoke.z_index = 2
	add_child(smoke)


func _process(delta: float) -> void:
	_clock += delta
	_glow.queue_redraw()

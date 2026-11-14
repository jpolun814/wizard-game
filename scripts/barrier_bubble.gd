class_name BarrierBubble
extends Node2D

## The Barrier as it is seen round a wizard: a faint pale bubble of air with wind turning round it and sparkles along its rim. It is told how long it has left and
## fades out over its last moments. It is made once, hidden, and lives as long as the wizard does.

const RADIUS := 50.0
const FADE_OVER := 0.4  # it fades out over this many seconds

var _left := 0.0
var _bubble: AnimatedSprite2D
var _swirl: Sprite2D  # the wind turning round the Barrier
var _sparkles: CPUParticles2D


## Builds it round the middle of a wizard's body.
func _init(middle: Vector2 = Vector2.ZERO) -> void:
	position = middle
	z_index = 2
	# The bubble itself, drawn twice its size round the wizard's middle.
	_bubble = PixelFx.sprite("shield", 10.0)
	_bubble.scale = Vector2.ONE * 2.0
	_bubble.material = Fx.additive()
	_bubble.visible = false
	add_child(_bubble)
	# Air, not force: wind swirls round the wizard inside a faint pale bubble.
	_swirl = Sprite2D.new()
	_swirl.texture = Fx.tex("twirl_01")
	_swirl.scale = Vector2.ONE * (RADIUS * 2.2 / Fx.TEX_SIZE)
	_swirl.material = Fx.additive()
	_swirl.visible = false
	add_child(_swirl)
	# Sparkles along the rim of the Barrier, only while it's up. They sit at the wizard's own depth, not over it.
	_sparkles = CPUParticles2D.new()
	_sparkles.z_index = -2
	_sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_sparkles.emission_sphere_radius = RADIUS
	_sparkles.amount = 14
	_sparkles.lifetime = 0.5
	_sparkles.direction = Vector2.ZERO
	_sparkles.spread = 180.0
	_sparkles.initial_velocity_min = 0.0
	_sparkles.initial_velocity_max = 4.0
	_sparkles.orbit_velocity_min = 0.6
	_sparkles.orbit_velocity_max = 1.0
	_sparkles.gravity = Vector2.ZERO
	_sparkles.scale_amount_min = 0.12
	_sparkles.scale_amount_max = 0.22
	_sparkles.texture = Fx.tex("trace_01")
	_sparkles.color_ramp = Fx.fade_ramp(Color(0.9, 0.96, 1.0))
	_sparkles.material = Fx.additive()
	_sparkles.emitting = false
	add_child(_sparkles)


## How many seconds the Barrier has left (zero when it is down), as the wizard has it each frame.
func show_for(seconds_left: float) -> void:
	_left = seconds_left
	_sparkles.emitting = seconds_left > 0.0
	queue_redraw()


func _draw() -> void:
	var fade := clampf(_left / FADE_OVER, 0.0, 1.0)
	_bubble.visible = _left > 0.0
	_bubble.modulate = Color(0.85, 0.93, 1.0, 0.22 * fade)
	_swirl.visible = _left > 0.0
	_swirl.rotation = -Time.get_ticks_msec() * 0.004
	_swirl.modulate = Color(0.9, 0.96, 1.0, 0.8 * fade)

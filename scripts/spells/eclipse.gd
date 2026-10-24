class_name Eclipse
extends Node2D

## Eclipse: darkness settles over the area you drew the crescent in. Anyone inside sees only what is close to them, so
## enemies in it lose sight of you beyond a few steps. A flare lights its patch of the dark and cuts through.

const LIFE := 10.0
const SIGHT := 90.0  # how far you can see inside an eclipse
const COLOR := Color(0.05, 0.0, 0.12)

var radius := 110.0  # set from how big the crescent was drawn
var _age := 0.0


func _ready() -> void:
	radius = clampf(radius, 70.0, 200.0)
	add_to_group("eclipses")
	add_to_group("lasting")
	z_index = 8
	# Dark wisps turning slowly inside it.
	var wisps := CPUParticles2D.new()
	wisps.amount = 18
	wisps.lifetime = 3.0
	wisps.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	wisps.emission_sphere_radius = radius * 0.8
	wisps.direction = Vector2.UP
	wisps.spread = 180.0
	wisps.initial_velocity_min = 4.0
	wisps.initial_velocity_max = 14.0
	wisps.gravity = Vector2.ZERO
	wisps.tangential_accel_min = 10.0
	wisps.tangential_accel_max = 30.0
	wisps.texture = Fx.tex("smoke_04")
	wisps.scale_amount_min = radius * 0.5 / Fx.TEX_SIZE
	wisps.scale_amount_max = radius * 0.9 / Fx.TEX_SIZE
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.1, 0.0, 0.2, 0.0), Color(0.1, 0.0, 0.2, 0.5), Color(0.1, 0.0, 0.2, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	wisps.color_ramp = ramp
	add_child(wisps)
	wisps.emitting = true
	Sfx.play("gravity", global_position, -8.0)


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= LIFE:
		queue_free()


## True when a point is in the dark.
func covers(point: Vector2) -> bool:
	return _age > 0.3 and point.distance_to(global_position) <= radius


func _draw() -> void:
	var grow := clampf(_age / 0.5, 0.0, 1.0) * clampf((LIFE - _age) / 1.0, 0.0, 1.0)
	draw_texture_rect(Fx.tex("circle_05"), Rect2(-Vector2.ONE * radius * 1.2, Vector2.ONE * radius * 2.4), false, Color(COLOR.r, COLOR.g, COLOR.b, 0.62 * grow))

class_name Silence
extends Node2D

## Silence: a ring of the world where no sound is made. Whoever stands in it can cast nothing, spell or chant, until they step out or it
## fades.

const RADIUS := 130.0
const LIFE := 12.0

var _age := 0.0
var _ring: Sprite2D


## True when a point is inside any ring of silence.
static func covers(tree: SceneTree, point: Vector2) -> bool:
	for silence: Silence in tree.get_nodes_in_group("silences"):
		if silence.global_position.distance_to(point) <= RADIUS:
			return true
	return false


func _ready() -> void:
	add_to_group("silences")
	add_to_group("lasting")
	z_index = 2
	_ring = Sprite2D.new()
	_ring.texture = Fx.tex("circle_03")
	_ring.scale = Vector2.ONE * (RADIUS * 2.0 / Fx.TEX_SIZE)
	_ring.modulate = Color(0.55, 0.4, 0.8, 0.8)
	add_child(_ring)
	var motes := CPUParticles2D.new()  # dark motes sinking slowly, as dust settles in a held breath
	motes.amount = 22
	motes.lifetime = 2.4
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = RADIUS * 0.85
	motes.direction = Vector2.DOWN
	motes.spread = 30.0
	motes.initial_velocity_min = 4.0
	motes.initial_velocity_max = 14.0
	motes.gravity = Vector2.ZERO
	motes.texture = Fx.tex("smoke_01")
	motes.scale_amount_min = 8.0 / Fx.TEX_SIZE
	motes.scale_amount_max = 18.0 / Fx.TEX_SIZE
	motes.color_ramp = Fx.fade_ramp(Color(0.25, 0.15, 0.4, 0.55))
	motes.local_coords = false
	add_child(motes)
	Sfx.play("gravity", global_position, -8.0)


func _physics_process(delta: float) -> void:
	_age += delta
	_ring.modulate.a = 0.8 * clampf(minf(_age / 0.4, (LIFE - _age) / 1.0), 0.0, 1.0)
	if _age >= LIFE:
		queue_free()


func danger_at(_point: Vector2) -> bool:
	return false

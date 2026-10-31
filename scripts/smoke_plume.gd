class_name SmokePlume
extends Node2D

## A great column of smoke rising from a volcano's crater. It is dense and has a plain edge, so a wizard can see where the smoke ends: no one
## sees through more than DEPTH of it. A wizard standing in the smoke sees only as far as DEPTH inside it, and no one sees past it from either
## side until they are that far in. It thins and goes when the volcano is done. Its origin is the foot of the column, in the crater.

const WIDTH := 200.0    # across the column
const HEIGHT := 520.0   # how far up it rises
const DEPTH := 80.0     # how much smoke a line of sight can pass through
const RISE_SECONDS := 5.0   # how long the smoke takes to climb to the top of the column, from the crater up
const THIN_SECONDS := 6.0

var _age := 0.0
var _thinning := -1.0   # counts down once the volcano is done
var _puffs: CPUParticles2D


func _ready() -> void:
	add_to_group("lasting")
	add_to_group("sight_blockers")
	add_to_group("smoke_plumes")
	SmokeVeil.ensure(get_tree())
	z_index = 3
	_puffs = CPUParticles2D.new()
	_puffs.amount = 260
	_puffs.lifetime = 5.0
	_puffs.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_puffs.emission_rect_extents = Vector2(WIDTH * 0.5 - 40.0, 6.0)
	_puffs.direction = Vector2.UP
	_puffs.spread = 4.0  # nearly straight up, so the column keeps its edges
	_puffs.initial_velocity_min = HEIGHT / 5.0 * 0.9
	_puffs.initial_velocity_max = HEIGHT / 5.0 * 1.0
	_puffs.gravity = Vector2.ZERO
	_puffs.angle_min = -180.0
	_puffs.angle_max = 180.0
	_puffs.angular_velocity_min = -20.0
	_puffs.angular_velocity_max = 20.0
	_puffs.texture = Fx.tex("smoke_04")
	_puffs.scale_amount_min = 110.0 / Fx.TEX_SIZE
	_puffs.scale_amount_max = 150.0 / Fx.TEX_SIZE
	var fade := Gradient.new()
	fade.set_color(0, Color(0.1, 0.09, 0.1, 0.0))
	fade.add_point(0.02, Color(0.1, 0.09, 0.1, 1.0))
	fade.add_point(0.85, Color(0.14, 0.12, 0.13, 1.0))
	fade.set_color(1, Color(0.14, 0.12, 0.13, 0.0))
	_puffs.color_ramp = fade
	add_child(_puffs)


func _physics_process(delta: float) -> void:
	_age += delta
	if _thinning < 0.0:
		return
	_thinning -= delta
	_puffs.emitting = false
	_puffs.modulate.a = clampf(_thinning / THIN_SECONDS, 0.0, 1.0)
	if _thinning <= 0.0:
		queue_free()


## The volcano is done: the smoke stops coming and the column thins away.
func release() -> void:
	if _thinning < 0.0:
		_thinning = THIN_SECONDS


## How much smoke lies on the line from one point to another: the length of it inside the column. A thinning column has less and less.
func smoke_along(from: Vector2, to: Vector2) -> float:
	if _thinning >= 0.0 and _thinning < THIN_SECONDS * 0.5:
		return 0.0
	var tall := HEIGHT * clampf(_age / RISE_SECONDS, 0.0, 1.0)  # the smoke has only climbed so far
	var box := Rect2(global_position + Vector2(-WIDTH * 0.5, -tall), Vector2(WIDTH, tall))
	var low := 0.0  # the stretch of the line, from 0 at its start to 1 at its end, that is inside the box
	var high := 1.0
	var along := to - from
	for axis in 2:
		if absf(along[axis]) < 0.0001:
			if from[axis] < box.position[axis] or from[axis] > box.end[axis]:
				return 0.0
			continue
		var near := (box.position[axis] - from[axis]) / along[axis]
		var far := (box.end[axis] - from[axis]) / along[axis]
		low = maxf(low, minf(near, far))
		high = minf(high, maxf(near, far))
		if low >= high:
			return 0.0
	return (high - low) * along.length()


## True when more than DEPTH of smoke lies on the line from one point to another.
func blocks(from: Vector2, to: Vector2) -> bool:
	return smoke_along(from, to) > DEPTH

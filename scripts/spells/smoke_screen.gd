class_name SmokeScreen
extends Node2D

## Smoke Screen: a wavy line drawn upward, and a bank of smoke billows along it. No one can see through it: enemies
## on one side lose sight of whoever is on the other. Wind clears it (a Tornado, a Gust), and so does a flood.

const LIFE := 12.0
const REACH := 48.0  # how far the smoke spreads past the line you drew
const THICKNESS := 34.0  # how close to the drawn line a sight line must pass to be cut
const FADE := 0.7    # how long it takes to thin away when the wind takes it

var line := PackedVector2Array()  # the drawn line, in world points; set before the smoke enters the tree
var _age := 0.0
var _region := Rect2()  # the box the smoke fills
var _thinning := -1.0   # counts down once the wind has taken it
var _emitter: CPUParticles2D


func _ready() -> void:
	add_to_group("clouds")
	add_to_group("lasting")
	add_to_group("sight_blockers")
	_region = GestureTemplates.bounds(line).grow(REACH)
	global_position = _region.get_center()
	_emitter = CPUParticles2D.new()
	var local := PackedVector2Array()
	for p in line:
		local.append(p - global_position)
	_emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	_emitter.emission_points = local
	_emitter.amount = clampi(int(UnistrokeRecognizer.path_length(line) / 2.0), 40, 220)
	_emitter.lifetime = 3.0
	_emitter.direction = Vector2.UP
	_emitter.spread = 120.0
	_emitter.initial_velocity_min = 8.0
	_emitter.initial_velocity_max = 26.0
	_emitter.gravity = Vector2(0, -6)
	_emitter.angle_min = -180.0
	_emitter.angle_max = 180.0
	_emitter.angular_velocity_min = -30.0
	_emitter.angular_velocity_max = 30.0
	_emitter.texture = Fx.tex("smoke_01")
	_emitter.scale_amount_min = 52.0 / Fx.TEX_SIZE
	_emitter.scale_amount_max = 96.0 / Fx.TEX_SIZE
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.52, 0.5, 0.56, 0.0), Color(0.52, 0.5, 0.56, 0.8), Color(0.52, 0.5, 0.56, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	_emitter.color_ramp = ramp
	_emitter.z_index = 3
	add_child(_emitter)
	_emitter.emitting = true
	Sfx.play("fire_hit", global_position, -8.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _thinning >= 0.0:
		_thinning -= delta
		modulate.a = clampf(_thinning / FADE, 0.0, 1.0)
		if _thinning < 0.0:
			queue_free()
		return
	if _age >= LIFE - 2.0:
		_emitter.emitting = false
	if _age >= LIFE:
		queue_free()


## True when the smoke is between two points: a line of sight that passes through the bank, which is a band along the
## line you drew, is cut. A box round the whole line would block far more than the smoke fills.
func blocks(from: Vector2, to: Vector2) -> bool:
	if _thinning >= 0.0 or _age < 0.3:
		return false
	if not _region.intersects(Rect2(from, Vector2.ZERO).expand(to).grow(THICKNESS)):
		return false  # a quick way out: the sight line never comes near the smoke
	for i in line.size() - 1:
		if _segment_gap(from, to, line[i], line[i + 1]) <= THICKNESS:
			return true
	return false


## The shortest distance between two line segments.
func _segment_gap(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
		return 0.0
	var gap := Geometry2D.get_closest_point_to_segment(a, c, d).distance_to(a)
	gap = minf(gap, Geometry2D.get_closest_point_to_segment(b, c, d).distance_to(b))
	gap = minf(gap, Geometry2D.get_closest_point_to_segment(c, a, b).distance_to(c))
	return minf(gap, Geometry2D.get_closest_point_to_segment(d, a, b).distance_to(d))


## The wind takes it: it thins away.
func dissipate() -> void:
	if _thinning < 0.0:
		_thinning = FADE
		_emitter.emitting = false


## The left and right edges of the smoke, for a wind that has to be at it.
func span() -> Vector2:
	return Vector2(_region.position.x, _region.end.x)

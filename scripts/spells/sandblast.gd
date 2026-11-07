class_name Sandblast
extends Node2D

## Sandblast: a cone drawn like Fire Breath's, its point at the caster and its mouth the way the grit should fly. A short, hard gust of sand and grit that
## scours whoever stands in the cone and is stopped by the ground and by stone. It does not last: it is one blast.

const DURATION := 0.45
const TICK := 0.15
const HARM := 4
const KNOCK := 180.0
const BODY_RADIUS := 28.0
const MIN_REACH := 100.0
const MAX_REACH := 230.0
const MIN_SPREAD := 0.35
const MAX_SPREAD := 1.1

var caster_node: Wizard
var aim := 0.0
var spread := 0.6
var reach := 150.0
var _age := 0.0
var _tick := 0.0
var _mouth := Vector2.ZERO


func _ready() -> void:
	add_to_group("danger")
	spread = clampf(spread, MIN_SPREAD, MAX_SPREAD)
	reach = clampf(reach, MIN_REACH, MAX_REACH)
	if is_instance_valid(caster_node):
		if absf(cos(aim)) > 0.2:
			caster_node.facing = signf(cos(aim))
		_mouth = caster_node.mouth()
	global_position = _mouth
	add_child(_stream(30, "dirt_02", Color("#d2b27a"), 16.0, 28.0, reach * 1.6, reach * 2.6))  # chunks of grit
	add_child(_stream(16, "smoke_04", Color(0.82, 0.68, 0.45, 0.85), 40.0, 70.0, reach * 1.0, reach * 1.8))  # and the dust they raise
	Sfx.play("stones", _mouth, -2.0)


## A stream of particles out of the caster's mouth, spread across the cone, for as long as the blast lasts.
func _stream(amount: int, texture: String, color: Color, small: float, big: float, slow: float, fast: float) -> CPUParticles2D:
	var stream := CPUParticles2D.new()
	stream.amount = amount
	stream.lifetime = 0.4
	stream.local_coords = false
	stream.direction = Vector2.from_angle(aim)
	stream.spread = rad_to_deg(spread * 0.5)
	stream.initial_velocity_min = slow
	stream.initial_velocity_max = fast
	stream.damping_min = 100.0
	stream.damping_max = 200.0
	stream.gravity = Vector2(0, 160)
	stream.scale_amount_min = small / Fx.TEX_SIZE
	stream.scale_amount_max = big / Fx.TEX_SIZE
	stream.texture = Fx.tex(texture)
	stream.color_ramp = Fx.fade_ramp(color)
	stream.emitting = true
	return stream


func _physics_process(delta: float) -> void:
	_age += delta
	_tick -= delta
	if _tick <= 0.0 and _age < DURATION:
		_tick = TICK
		_scour()
	if _age >= DURATION + 0.4:
		queue_free()


## Hurts whoever is in the cone and in the open to it (the ground and stone stop the grit), and pushes it back a little.
func _scour() -> void:
	for body in SpellTargets.all(get_tree()):
		if body == caster_node:
			continue
		var at := SpellTargets.center_of(body)
		if not _in_cone(at) or _blocked(at):
			continue
		SpellTargets.hurt(body, HARM, "Earth", false, false, self)
		if body.is_in_group("mobs"):
			body.knock_back(Vector2.from_angle(aim) * KNOCK)


func _in_cone(point: Vector2) -> bool:
	var to := point - _mouth
	var body_slack := atan2(BODY_RADIUS, maxf(to.length(), BODY_RADIUS))  # a body has size: it is in the cone if any of it is
	return to.length() <= reach and absf(angle_difference(aim, to.angle())) <= spread * 0.5 + body_slack


func _blocked(point: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(_mouth, point)
	query.collision_mask = 1  # ground and stone
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func danger_at(point: Vector2) -> bool:
	return _age < DURATION and _in_cone(point)

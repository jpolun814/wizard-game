class_name Jolt
extends Node2D

## Jolt: a bolt of lightning that leaves the staff along the stroke and strikes the first thing in its way at once. Ground and stone stop it. It is lightning, and
## so it is in the group "lightning", which is all the world needs to know to strike a wet body harder (`Damage`). Whoever it strikes is hurried on for a moment.

const RANGE := 520.0
const HARM := 14
const WIDTH := 18.0
const HASTE_SECONDS := 1.5
const COLOR := Color("#ffe85a")

var caster: Wizard
var aim := 0.0


## This spell is one cast, and so one source of harm: it cannot hit the same wizard again for a moment, and another spell can (see Wizard.take_damage).
func hit_source() -> Object:
	return self


func _ready() -> void:
	add_to_group("lightning")
	var from: Vector2 = caster.launch_tip() if is_instance_valid(caster) else global_position
	var way := Vector2.from_angle(aim)
	var along := _first_wall(from, way)
	var target: Node2D = null
	for body in SpellTargets.all(get_tree()):
		if body == caster:
			continue
		var to: Vector2 = SpellTargets.center_of(body) - from
		var ahead := to.dot(way)
		if ahead < 0.0 or ahead > along:
			continue
		if absf(to.cross(way)) <= WIDTH + (16.0 if body.is_in_group("wizards") else 14.0):
			along = ahead
			target = body
	var tip := from + way * along
	_show_bolt(from, tip)
	if target != null:
		SpellTargets.hurt(target, HARM, "Fire", false, false, self)
		if is_instance_valid(target) and target is Wizard and not target.dead:
			target.grant_haste(HASTE_SECONDS)  # the jolt sets them off
		Fx.burst(get_parent(), tip, COLOR, 14, 170.0, 0.4, true)
		Fx.impact(get_parent(), tip, COLOR, 34.0)
	else:
		Fx.burst(get_parent(), tip, COLOR, 6, 80.0, 0.3, true)
	Sfx.cue("Jolt", "zap", from, -2.0)
	get_tree().create_timer(0.5).timeout.connect(queue_free)


## How far along the line the ground or a wall stops it, or its whole reach.
func _first_wall(from: Vector2, way: Vector2) -> float:
	var query := PhysicsRayQueryParameters2D.create(from, from + way * RANGE)
	query.collision_mask = 1  # ground and stone
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return from.distance_to(hit["position"]) if not hit.is_empty() else RANGE


## The bolt: forked lightning, drawn for the game, laid from the staff to where it struck, with a glow at its start.
func _show_bolt(from: Vector2, tip: Vector2) -> void:
	BoltLine.lay(get_parent(), from, tip, BoltLine.BOLTS, 0.28)
	ScreenFlash.strike(get_tree(), tip, 0.4)
	Fx.pop(get_parent(), from, "circle_05", COLOR, 36.0, 0.2, 1.4)


func danger_at(_point: Vector2) -> bool:
	return false

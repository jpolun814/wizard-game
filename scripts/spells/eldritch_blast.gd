class_name EldritchBlast
extends Node2D

## Eldritch Blast: a beam of crackling dark energy that leaves the caster along the arrow and strikes the first thing in its way at once. Ground and stone
## stop it; it reaches only so far. It is not a shot that can be turned or dodged once loosed: the cover to take is a wall, or the distance.

const RANGE := 640.0
const HARM := 16
const WIDTH := 20.0        # how near the line of the beam a body must be to be struck
const COLOR := Color("#9a6ad0")

var caster: Wizard
var aim := 0.0


func _ready() -> void:
	var from: Vector2 = caster.launch_tip() if is_instance_valid(caster) else global_position  # the beam leaves the gem of the staff
	var way := Vector2.from_angle(aim)
	var stop := _first_wall(from, way)
	var target: Node2D = null
	var along := stop
	for body in SpellTargets.all(get_tree()):
		if body == caster:
			continue
		var to: Vector2 = SpellTargets.center_of(body) - from
		var ahead := to.dot(way)
		if ahead < 0.0 or ahead > along:
			continue
		if absf(to.cross(way)) <= WIDTH + _body_radius(body):
			along = ahead
			target = body
	var tip := from + way * along
	_show_beam(from, tip)
	if target != null:
		SpellTargets.hurt(target, HARM, "Shadow", false, false, self)
		Fx.burst(get_parent(), tip, COLOR, 14, 160.0, 0.4, true)
		Fx.impact(get_parent(), tip, COLOR, 36.0)
	else:
		Fx.burst(get_parent(), tip, COLOR, 6, 80.0, 0.3, true)
	Sfx.cue("Eldritch Blast", "blast", from, -2.0)
	get_tree().create_timer(0.5).timeout.connect(queue_free)


## How far along the beam the ground or a wall stops it, or its whole reach.
func _first_wall(from: Vector2, way: Vector2) -> float:
	var query := PhysicsRayQueryParameters2D.create(from, from + way * RANGE)
	query.collision_mask = 1  # ground and stone
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return from.distance_to(hit["position"]) if not hit.is_empty() else RANGE


func _body_radius(body: Node2D) -> float:
	return 16.0 if body.is_in_group("wizards") else 14.0


## The beam: a rope of dark energy, drawn for the game, laid from the staff to where it struck, with a glow at its start.
func _show_beam(from: Vector2, tip: Vector2) -> void:
	BoltLine.lay(get_parent(), from, tip, BoltLine.BEAMS, 0.4)
	Fx.pop(get_parent(), from, "circle_05", COLOR, 40.0, 0.25, 1.4)


func danger_at(_point: Vector2) -> bool:
	return false

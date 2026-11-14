class_name Leech
extends Node2D

## Leech: a red tether from the caster to the wizard the stroke ran at. While it holds, every spell the caster casts costs the caster only half its
## stamina, and the other half is taken from the one on the tether. It breaks when the two lose sight of each other, when they are too far apart, when
## either is beaten, after a long while, or when the caster casts Leech again. Blood spells (they cost maximum stamina) are not split.
## Like every spell it has no side: the tether is a rope between two bodies, and the caster is the one holding it.

const REACH := 460.0       # the farthest a wizard can be and be picked, and the farthest the tether holds
const AIM_CONE := 0.55     # radians either side of the stroke that a wizard may lie in to be picked
const LONGEST := 24.0      # seconds it lasts at most
const SHARE := 0.5         # the share of a spell's cost that falls on the one on the tether
const BEAD := 16.0         # the gap between the beads of the tether

var caster: Wizard
var target: Wizard
var _age := 0.0


## The wizard a Leech stroke aimed at: the nearest in the way it points, in sight and within reach. Null when the stroke ran at no one.
static func pick(tree: SceneTree, from: Wizard, aim: float) -> Wizard:
	var best: Wizard = null
	var best_gap := REACH
	var start := from.center()
	for wizard: Wizard in SpellTargets.wizards(tree):
		if wizard == from:
			continue
		var to := wizard.center() - start
		var gap := to.length()
		if gap >= best_gap or absf(angle_difference(to.angle(), aim)) > AIM_CONE:
			continue
		if sees(tree, start, wizard.center(), from.get_world_2d()):
			best_gap = gap
			best = wizard
	return best


## True when nothing solid and no smoke lies between two points.
static func sees(tree: SceneTree, a: Vector2, b: Vector2, world: World2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(a, b)
	query.collision_mask = 1
	if not world.direct_space_state.intersect_ray(query).is_empty():
		return false
	return not SpellTargets.sight_blocked(tree, a, b)


## The tether this wizard holds, if any.
static func held_by(tree: SceneTree, wizard: Wizard) -> Leech:
	for leech: Leech in tree.get_nodes_in_group("leeches"):
		if leech.caster == wizard and not leech.is_queued_for_deletion():
			return leech
	return null


## Called on every machine each time a wizard casts a spell that costs stamina: whoever is on the tether pays their half. The caster's own
## half is paid by `cost_after` on the machine that drives them. A wizard on a tether who is a likeness here pays nothing; their own machine does.
static func charge_target(tree: SceneTree, wizard: Wizard, cost: float) -> void:
	var leech := held_by(tree, wizard)
	if leech != null and is_instance_valid(leech.target):
		leech.target.drain(cost * SHARE)
		Fx.burst(leech.get_parent(), leech.target.center(), SpellData.SCHOOL_COLORS["Blood"], 6, 70.0, 0.4, true)


## What the caster pays of a spell's cost: all of it, or the half left to them when they hold a tether.
static func cost_after(tree: SceneTree, wizard: Wizard, cost: float) -> float:
	return cost * (1.0 - SHARE) if held_by(tree, wizard) != null else cost


func _ready() -> void:
	add_to_group("leeches")
	z_index = 7
	for other: Leech in get_tree().get_nodes_in_group("leeches"):
		if other != self and other.caster == caster:
			other.queue_free()  # one tether at a time
	Sfx.play("blood_cast", caster.center(), -4.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LONGEST or not is_instance_valid(caster) or not is_instance_valid(target) or caster.dead or target.dead:
		_snap()
		return
	var a := caster.center()
	var b := target.center()
	if a.distance_to(b) > REACH or not sees(get_tree(), a, b, get_world_2d()):
		_snap()
		return
	queue_redraw()


func _snap() -> void:
	if is_queued_for_deletion():
		return
	if is_instance_valid(caster) and is_instance_valid(target):
		Fx.burst(get_parent(), (caster.center() + target.center()) * 0.5, SpellData.SCHOOL_COLORS["Blood"], 8, 90.0, 0.4, true)
	queue_free()


func _draw() -> void:
	if not is_instance_valid(caster) or not is_instance_valid(target):
		return
	var a := to_local(caster.center())
	var b := to_local(target.center())
	var gap := a.distance_to(b)
	var beads := maxi(1, int(gap / BEAD))
	var texture := Fx.tex("circle_05")
	var color: Color = SpellData.SCHOOL_COLORS["Blood"].lightened(0.15)
	for k in beads + 1:
		var along := float(k) / float(beads)
		var sway := sin(_age * 6.0 + float(k) * 0.9) * 2.5
		var at := a.lerp(b, along) + Vector2(0.0, sway)
		var size := 6.0 + 2.0 * sin(_age * 9.0 - float(k) * 0.7)  # a pulse runs along it, from the target to the caster
		draw_texture_rect(texture, Rect2(at - Vector2(size, size) * 0.5, Vector2(size, size)), false, color)

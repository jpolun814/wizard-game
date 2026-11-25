class_name Hemorrhage
extends Node2D

## Hemorrhage: a crescent drawn like a cut, over someone. The wound will not close: it bleeds for a while, a little at a time. It cuts whoever is nearest to the
## stroke, whether friend or foe: no spell has a side.

const SECONDS := 8.0
const TICK := 1.0
const HARM := 5
const REACH := 80.0
const TREMOR := 9.0  # how far a drained hand wanders from the line it draws, in pixels

var target: Node2D  # set by the arena, which finds who was cut
var _age := 0.0
var _clock := 0.0
var _drip: CPUParticles2D


## The hand a wizard draws with: a brain's own, or the arena's for the person.
func _arena_caster(wizard: Wizard) -> Caster:
	if wizard.caster != null:
		return wizard.caster
	var arena := wizard.get_parent()
	return arena.caster if arena != null and "caster" in arena and wizard.is_person() else null


## Whoever is under the cut: anyone whose middle lies inside the shape that was drawn (a little more than the box of it), the one nearest its middle; or,
## failing that, whoever is closest to its middle, if near enough.
static func nearest_under(tree: SceneTree, point: Vector2, extent := Vector2.ZERO) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	var inside := Rect2(point - extent * 0.5 - Vector2(24.0, 24.0), extent + Vector2(48.0, 48.0))
	for body in SpellTargets.all(tree):
		var at := SpellTargets.center_of(body)
		var distance := at.distance_to(point)
		if distance < best_distance and (distance < REACH or inside.has_point(at)):
			best_distance = distance
			best = body
	return best


## The wound a body is bleeding from, if any.
static func on(tree: SceneTree, body: Node) -> Hemorrhage:
	for wound: Hemorrhage in tree.get_nodes_in_group("wounds"):
		if wound.target == body:
			return wound
	return null


## Seconds the wound has left to bleed.
func left() -> float:
	return maxf(SECONDS - _age, 0.0)


func _ready() -> void:
	add_to_group("wounds")
	add_to_group("lasting")
	z_index = 9
	_drip = Fx.trail(Color("#c4162f"), 22, 0.8, 24.0, Vector2(0, 360), "circle_05", 11.0)
	_drip.material = null
	add_child(_drip)
	Sfx.cue("Hemorrhage", "blood", global_position, -4.0)
	Fx.pop(get_parent(), global_position, "slash_01", Color("#c4162f"), 90.0, 0.35, 1.3, 0.0, false)  # the cut
	Fx.burst(get_parent(), global_position, Color("#c4162f"), 16, 130.0, 0.5, false)


func _physics_process(delta: float) -> void:
	_age += delta
	if not SpellTargets.affects(target) or _age >= SECONDS:
		if is_instance_valid(target) and target is Wizard:
			var hand: Caster = _arena_caster(target)
			if hand != null:
				hand.tremor = 0.0
		queue_free()
		return
	global_position = SpellTargets.center_of(target) + Vector2(0, 8)
	if target is Wizard:
		target.drained_time = 0.3  # drained as it bleeds: slower, and an unsteady hand
		var hand: Caster = _arena_caster(target)
		if hand != null:
			hand.tremor = TREMOR
	_clock -= delta
	if _clock <= 0.0:
		_clock = TICK
		SpellTargets.hurt(target, HARM, "Blood", false, false, self)
		Fx.burst(get_parent(), global_position, Color("#c4162f"), 9, 90.0, 0.5, false)


## This spell is one cast, and so one source of harm: it cannot hit the same wizard again for a moment, and another spell can (see Wizard.take_damage).
func hit_source() -> Object:
	return self

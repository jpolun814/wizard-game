extends Node

## A wizard is a wizard: Push, Geyser, Burst, Tornado, Tide Surf and a damaging shot do the same to the one a person plays and to one the brain plays.
## Each spell is cast at the same spot twice, at each of them in turn, and how far each was thrown and how much each lost are compared.
##
##     godot --headless --path . --fixed-fps 60 tests/parity_check.tscn
## It prints PASS or FAIL for each spell and exits with code 1 if any failed.

const WATCH := 1.6        # seconds each cast is followed for
const TOLERANCE := 0.15   # how far apart the two may be, as a share of the larger, plus a few pixels
const CHANCE_TOLERANCE := 0.6  # the same, for a spell whose throw is by chance
const REST := 1.5          # seconds a body is left to come to rest after a cast
const SLACK := 25.0       # pixels (or stamina) of difference that no share is asked of

var _failures := 0


## A brain that decides nothing: the body is driven the way a brain drives it, and stands where it is put. What is left to compare is the body.
class QuietBrain extends WizardBrain:
	func think(_delta: float) -> void:
		wizard.walk(0.0)



func _ready() -> void:
	World.random_start = false
	World.next_seed = 8
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var tree := get_tree()
	var person: Wizard = world.player
	var brain_wizard: Wizard = null
	var caster: Wizard = null
	for found: Wizard in tree.get_nodes_in_group("wizards"):
		if found == person:
			continue
		if brain_wizard == null:
			brain_wizard = found
		elif caster == null:
			caster = found
		else:
			found.set_physics_process(false)
			found.global_position = Vector2(-9000.0, -9000.0)
	for mob in tree.get_nodes_in_group("mobs"):
		mob.set_physics_process(false)
		mob.global_position = Vector2(-9000.0, -9000.0)
	for page in tree.get_nodes_in_group("pages"):
		page.queue_free()
	brain_wizard.brain = QuietBrain.new(brain_wizard)
	caster.brain = QuietBrain.new(caster)
	var spot: Vector2 = person.global_position
	world.set_process(false)  # or it carries the person back from the place it is put away to the place it began
	for spell in ["Push", "Geyser", "Burst", "Tornado", "Tide Surf", "Ignite"]:
		var seen := {}
		for body: Wizard in [person, brain_wizard, person, brain_wizard]:  # the first pair settles the world, the second pair is compared
			await _set_down(body, [person, brain_wizard, caster], spot, caster)
			seen[body] = await _cast_at(world, spell, body, caster)  # the last cast at each is what is kept
		_compare(spell, seen[person], seen[brain_wizard])
	print("a wizard is a wizard" if _failures == 0 else "%d FAILED" % _failures)
	tree.quit(1 if _failures > 0 else 0)


## Stands the one that will be cast at on the spot, still and healthy, and the rest well away (the caster a little way to the left).
func _set_down(body: Wizard, all: Array, spot: Vector2, caster: Wizard) -> void:
	for other: Wizard in all:
		other.global_position = Vector2(-9000.0, -9000.0 - 400.0 * all.find(other))
		other.velocity = Vector2.ZERO
		other.set_physics_process(other == body or other == caster)  # those put away stay put
	body.global_position = spot
	body.velocity = Vector2.ZERO
	body.stamina = 200.0
	body.max_stamina = 200.0
	if body != caster:
		caster.global_position = spot + Vector2(-260.0, 0.0)
		caster.velocity = Vector2.ZERO
	for i in 40:
		await get_tree().physics_frame


## Casts a spell at a wizard and follows it: {"rise": the most it was lifted, "side": the most it was thrown sideways, "lost": the stamina it lost}.
func _cast_at(world: World, spell: String, target: Wizard, caster: Wizard) -> Dictionary:
	seed(7)  # the same chance for each of them (a tornado flings to either side by chance)
	var start := target.global_position
	var before := target.max_stamina + target.stamina
	var middle := target.center()
	match spell:
		"Push":
			world.spawn_spell(spell, "angled", middle + Vector2(-40.0, 0.0), 0.0, {"radius": 90.0}, caster)
		"Geyser":
			var geyser := Geyser.new()
			geyser.position = start
			world.add_child(geyser)
		"Burst":
			world.spawn_spell(spell, "positional", middle + Vector2(-50.0, 0.0), 0.0, {}, caster)
		"Tornado":
			var tornado := Tornado.new()
			tornado.position = start
			world.add_child(tornado)
		"Tide Surf":
			world.spawn_spell(spell, "directional", middle, 0.0, {}, target)
		_:  # a shot from the caster, straight at it
			world.spawn_spell(spell, "directional", caster.center(), (middle - caster.center()).angle(), {"length": 200.0}, caster)
	var rise := 0.0
	var side := 0.0
	for i in int(WATCH * 60.0):
		await get_tree().physics_frame
		rise = maxf(rise, start.y - target.global_position.y)
		side = maxf(side, absf(target.global_position.x - start.x))
	for effect in get_tree().get_nodes_in_group("lasting"):
		effect.queue_free()
	target.surf_time = 0.0  # a surf would otherwise carry it on after the next one is set down
	for i in int(REST * 60.0):  # a push has to run out before the body is put away, or it runs out when it is put back
		await get_tree().physics_frame
	return {"rise": rise, "side": side, "lost": before - (target.max_stamina + target.stamina)}


func _compare(spell: String, person: Dictionary, brain: Dictionary) -> void:
	var same := true
	var tolerance := CHANCE_TOLERANCE if spell == "Tornado" else TOLERANCE  # it flings each to either side and as high as it likes, by chance
	for key: String in person:
		var a: float = person[key]
		var b: float = brain[key]
		same = same and absf(a - b) <= maxf(1.0 if key == "lost" else SLACK, tolerance * maxf(absf(a), absf(b)))
	if spell == "Ignite":  # a shot that missed would match by doing nothing to either
		same = same and person["lost"] > 0.0
	_verdict(same, "%s: a person's wizard %s, the brain's %s" % [spell, _show(person), _show(brain)])


func _show(measure: Dictionary) -> String:
	return "rose %.0f, went %.0f aside, lost %.0f" % [measure["rise"], measure["side"], measure["lost"]]


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

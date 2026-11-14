extends Node

## Stamina comes back at once when a wizard stops moving their body: walking and jumping do not make it wait afterwards, but a spell does (a second).
##
##     godot --headless --fixed-fps 60 --path . tests/checks/regen_check.tscn
## It prints PASS or FAIL for each case and exits with code 1 if any failed.

var _failures := 0
var _walking := 0.0


## A wizard that walks as it is told and does nothing else.
class WalkBrain extends WizardBrain:
	var owner_check: Node

	func think(_delta: float) -> void:
		wizard.walk(owner_check._walking)


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 8
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var tester: Wizard = null
	for found: Wizard in get_tree().get_nodes_in_group("wizards"):
		if found == world.player:
			continue
		if tester == null:
			tester = found
		else:
			found.set_physics_process(false)
			found.global_position = Vector2(-9000.0, -9000.0)
	world.player.set_physics_process(false)
	world.player.global_position = Vector2(-9000.0, -9300.0)
	world.set_process(false)
	var brain := WalkBrain.new(tester)
	brain.owner_check = self
	tester.brain = brain
	for k in 40:
		await get_tree().physics_frame
	tester.max_stamina = 200.0
	# Walking: the stamina does not come back, and it only goes down a little.
	tester.stamina = 100.0
	_walking = 200.0
	await _frames(60)
	_check(tester.stamina <= 100.0, "while it walks the stamina does not come back (%.1f)" % tester.stamina)
	# Stopping: it comes back at once, without waiting a second.
	_walking = 0.0
	await _frames(12)
	var at_stop := tester.stamina
	await _frames(30)
	_check(tester.stamina - at_stop > 6.0, "half a second after it stops, the stamina is coming back (+%.1f)" % (tester.stamina - at_stop))
	# A jump does not make it wait either.
	tester.stamina = 100.0
	tester.request_jump()
	await _frames(70)
	var landed := tester.stamina
	await _frames(30)
	_check(tester.stamina - landed > 6.0, "after a jump it does not wait (+%.1f)" % (tester.stamina - landed))
	# A spell does make it wait.
	tester.stamina = 100.0
	tester.spend(10.0)
	await _frames(30)
	_check(tester.stamina <= 90.5, "after a spell the stamina waits (%.1f)" % tester.stamina)
	await _frames(60)
	_check(tester.stamina > 91.0, "and then comes back (%.1f)" % tester.stamina)
	print("stamina comes back as it should" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame


func _check(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

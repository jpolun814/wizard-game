extends Check
## In the air a wizard keeps the sideways speed it had: the keys only nudge it, and a blow carries it on. On the ground a wizard still starts and
## stops at once, and a shove dies away quickly.
##
##     godot --headless --path . --fixed-fps 60 tests/checks/air_momentum_check.tscn
## It prints PASS or FAIL for each thing and exits with code 1 if any failed.


## A brain that decides nothing: the test drives the body the way a brain does.
class QuietBrain extends WizardBrain:
	func think(_delta: float) -> void:
		pass


var _wizard: Wizard
var _spot: Vector2


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 8
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var person: Wizard = world.player
	_wizard = null
	for found: Wizard in get_tree().get_nodes_in_group("wizards"):
		if found == person:
			continue
		if _wizard == null:
			_wizard = found
		else:
			found.set_physics_process(false)
			found.global_position = Vector2(-9000.0, -9000.0)
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.set_physics_process(false)
		mob.global_position = Vector2(-9000.0, -9000.0)
	for page in get_tree().get_nodes_in_group("pages"):
		page.queue_free()
	_spot = person.global_position  # where the person began: open ground
	person.set_physics_process(false)
	person.global_position = Vector2(-9000.0, -9500.0)
	world.set_process(false)  # or it carries the person back to the place it began
	_wizard.brain = QuietBrain.new(_wizard)
	await _on_ground_at_rest()

	# On the ground nothing changed: a key starts the walk at once and letting go stops it at once.
	_wizard.walk(Wizard.SPEED)
	await _frames(6)
	_verdict(_wizard.velocity.x > 290.0, "on the ground a key sets the full walking speed at once (%.0f)" % _wizard.velocity.x)
	_wizard.walk(0.0)
	await _frames(6)
	_verdict(absf(_wizard.velocity.x) < 1.0, "on the ground letting go of the key stops the wizard at once (%.0f)" % _wizard.velocity.x)

	# A standing jump with the key held in the air: the keys nudge, they do not set the speed.
	await _on_ground_at_rest()
	var start_x := _wizard.global_position.x
	_wizard.request_jump()
	await _frames(4)
	_wizard.walk(Wizard.SPEED)
	await _frames(10)
	_verdict(_wizard.velocity.x > 290.0, "a standing jump, the key held 10 frames in the air: a jump they chose is steered as freely as walking (%.0f)" % _wizard.velocity.x)
	await _land()
	_wizard.walk(0.0)
	var drift := _wizard.global_position.x - start_x
	_verdict(drift > 150.0, "a standing jump with the key held the whole way carries a full stride to the side (%.0f px)" % drift)

	# A running jump, then the other key: the speed it already had carries it on.
	await _on_ground_at_rest()
	_wizard.walk(Wizard.SPEED)
	await _frames(12)
	_wizard.request_jump()
	await _frames(4)
	_wizard.walk(-Wizard.SPEED)
	await _frames(30)
	_verdict(_wizard.velocity.x < -250.0, "a running jump, the opposite key held half a second: they turn about in the air at once (%.0f)" % _wizard.velocity.x)
	await _land()
	_wizard.walk(0.0)

	# A blow in the air: the keys cannot turn it round. The same throw is made twice, once with nothing held and once with the opposite key held.
	var free := await _throw(0.0)
	var held := await _throw(-Wizard.SPEED)
	_verdict(free > 150.0, "a throw to the right with no key held carries well to the right (%.0f px)" % free)
	_verdict(held > 100.0 and held > 0.4 * free, "the same throw with left held the whole way still lands well to the right (%.0f px against %.0f)" % [held, free])

	# A pull in the air is no stronger than it ever was: one the ground would have shed leaves a wizard in the air where it was.
	await _on_ground_at_rest()
	_wizard.request_jump()
	await _frames(6)
	for i in 20:
		_wizard.pull(Vector2(1000.0, 0.0), 1.0 / 60.0)
		await get_tree().physics_frame
	_verdict(absf(_wizard.velocity.x) < 60.0, "a pull of 1000 on a wizard in the air does not move it (%.0f)" % _wizard.velocity.x)
	await _land()
	_wizard.walk(0.0)

	# On the ground a shove still dies away at once.
	await _on_ground_at_rest()
	start_x = _wizard.global_position.x
	_wizard.push(Vector2(500.0, 0.0))
	await _frames(60)
	var slid := _wizard.global_position.x - start_x
	_verdict(slid > 20.0 and slid < 150.0, "a shove on the ground slides the wizard a short way and stops (%.0f px)" % slid)

	print("the air keeps its speed" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## The wizard is stood on the ground at the spot, still and well.
func _on_ground_at_rest() -> void:
	_wizard.global_position = _spot
	_wizard.velocity = Vector2.ZERO
	_wizard.stamina = 200.0
	_wizard.max_stamina = 200.0
	_wizard.walk(0.0)
	await _frames(60)


## Waits until the wizard has come down.
func _land() -> void:
	for i in 300:
		await get_tree().physics_frame
		if _wizard.is_on_floor():
			return



## Throws the wizard up and to the right with the given key held, and says how far to the right it came down.
func _throw(key: float) -> float:
	await _on_ground_at_rest()
	var start_x := _wizard.global_position.x
	_wizard.push(Vector2(500.0, -500.0))
	await _frames(4)  # off the ground: a key held on the ground would be the speed it takes off with
	_wizard.walk(key)
	await _frames(10)
	await _land()
	_wizard.walk(0.0)
	return _wizard.global_position.x - start_x

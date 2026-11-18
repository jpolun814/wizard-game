extends Check
## The status bubbles round a wizard (StatusBubbles): one for each state, in the order the states began, a clock ring that empties, and a held breath that turns
## into choking when its air is gone.
##
##     godot --headless --path . --fixed-fps 60 tests/checks/bubbles_check.tscn

var _wizard: Wizard


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
	var spot := person.global_position
	person.set_physics_process(false)
	person.global_position = Vector2(-9000.0, -9500.0)
	world.set_process(false)
	_wizard.brain = null
	_wizard.global_position = spot
	await _frames(60)

	_reset()
	await _frames(3)
	_verdict(_wizard.bubbles.names().is_empty(), "a wizard in no state has no bubbles")
	_wizard.coat.oil()
	await _frames(3)
	_wizard.coat.soak()
	await _frames(3)
	_wizard.slow_time = 4.0
	await _frames(3)
	var order := _wizard.bubbles.names().duplicate()
	_verdict(order == ["oiled", "wet", "slowed"], "three states give three bubbles, in the order they began (%s)" % [order])
	_verdict(_wizard.bubbles.name_at(_wizard.bubbles.place_of(1)) == "wet", "the mouse over a bubble finds its state")
	_verdict(_wizard.bubbles.place_of(0).distance_to(_wizard.bubbles.place_of(1)) > 2.0 * StatusBubbles.RADIUS, "and no two bubbles touch")
	var full := _wizard.bubbles.ring_of("slowed")
	await _frames(120)
	_verdict(_wizard.bubbles.ring_of("slowed") < full - 0.2, "the clock ring empties (%.2f to %.2f)" % [full, _wizard.bubbles.ring_of("slowed")])
	_wizard.slow_time = 0.0
	await _frames(3)
	_verdict(not _wizard.bubbles.names().has("slowed"), "and the bubble goes when the state does")
	_reset()
	_wizard.lungs.smother(true)
	await _frames(3)
	_verdict(_wizard.bubbles.names().has("holding"), "a held breath is a bubble")
	_wizard.lungs.air = 0.0
	await _frames(3)
	_verdict(_wizard.bubbles.names().has("choking") and not _wizard.bubbles.names().has("holding"), "and with the air gone it becomes choking")
	_wizard.lungs.smother(false)
	print("status bubbles work" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _reset() -> void:
	_wizard.wet_time = 0.0
	_wizard.burning_time = 0.0
	_wizard.oiled_time = 0.0
	_wizard.slow_time = 0.0
	_wizard.max_stamina = 200.0
	_wizard.stamina = 200.0
	_wizard.lungs.air = Lungs.BREATH


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

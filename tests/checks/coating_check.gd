extends Check
## Water, flame and oil on a wizard's body (Coating): a wet wizard cannot be set alight and takes lightning hard, water puts a fire out, a flame burns a little
## at a time, and an oiled wizard burns twice as long.
##
##     godot --headless --path . --fixed-fps 60 tests/checks/coating_check.tscn

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
	_verdict(not _wizard.is_wet() and not _wizard.is_burning() and not _wizard.is_oiled(), "a wizard starts dry, cold and clean")

	# Flame sets a dry wizard alight, and it bites a little at a time.
	SpellTargets.hurt(_wizard, 3, "Fire")
	_verdict(_wizard.is_burning(), "a flame sets a dry wizard alight")
	var before := _wizard.max_stamina
	await _frames(90)
	_verdict(before - _wizard.max_stamina >= Coating.BURN_DAMAGE * 2, "the burn bites a little at a time (%.0f lost)" % (before - _wizard.max_stamina))
	await _frames(int(Coating.BURN_SECONDS * 60.0))
	_verdict(not _wizard.is_burning(), "and it burns out")

	# Water puts it out, and a wet wizard cannot be lit.
	_reset()
	SpellTargets.hurt(_wizard, 3, "Fire")
	_wizard.coat.soak()
	_verdict(_wizard.is_wet() and not _wizard.is_burning(), "water puts out a burning wizard and leaves them wet")
	_wizard.max_stamina = 200.0
	_wizard.stamina = 200.0
	_wizard.coat.ignite()
	_verdict(not _wizard.is_burning(), "a wet wizard cannot be set alight")
	_verdict(_wizard.coat.shocked(30) == 48, "lightning strikes a wet wizard harder (30 -> %d)" % _wizard.coat.shocked(30))
	_verdict(_wizard.coat.frozen_for(4.0) > 4.0, "ice holds a wet wizard longer (%.1f s)" % _wizard.coat.frozen_for(4.0))
	_verdict(Coating.CHILL_WET > 1.0, "and a snowstorm freezes a wet wizard sooner (x%.1f)" % Coating.CHILL_WET)

	# Oil makes a fire last twice as long, and burns off.
	_reset()
	_wizard.coat.oil()
	_wizard.coat.ignite()
	_verdict(_wizard.burning_time > Coating.BURN_SECONDS * 1.9 and not _wizard.is_oiled(), "an oiled wizard burns twice as long, and the oil goes (%.1f s)" % _wizard.burning_time)

	# A dry wizard is struck by lightning no harder.
	_reset()
	_verdict(_wizard.coat.shocked(30) == 30, "a dry wizard takes lightning as it comes")

	print("body coats work" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _reset() -> void:
	_wizard.wet_time = 0.0
	_wizard.burning_time = 0.0
	_wizard.oiled_time = 0.0
	_wizard.max_stamina = 200.0
	_wizard.stamina = 200.0


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

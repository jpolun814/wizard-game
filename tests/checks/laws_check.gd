extends Check
## The laws of the world work on EVERY body, not only a wizard's: a creature is soaked, set alight, oiled and shocked by the same rules, whoever or whatever did it.
## The kind of a blow decides what it does besides harm (heat lights, lightning shocks, force shatters ice), never the spell's name.
##
##     godot --headless --path . --fixed-fps 60 tests/checks/laws_check.tscn


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 8
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	world.set_process(false)
	var feet: Vector2 = world.player.global_position + Vector2(300.0, 0.0)
	var mob: Mob = world.add_mob("basic", feet)
	await get_tree().physics_frame
	await get_tree().create_timer(1.5).timeout
	_verdict(not mob.is_wet() and not mob.is_burning() and not mob.is_oiled(), "a creature starts dry, cold and clean")
	SpellTargets.hurt(mob, 1, "Fire")
	_verdict(mob.is_burning(), "heat sets a dry creature alight")
	var hp := mob.hp
	await get_tree().create_timer(1.2).timeout
	_verdict(mob.hp < hp, "and the burn bites it (%d -> %d)" % [hp, mob.hp])
	Substances.soak(mob)
	_verdict(mob.is_wet() and not mob.is_burning(), "water puts the flame out and leaves it wet")
	SpellTargets.hurt(mob, 1, "Fire")
	_verdict(not mob.is_burning(), "a wet creature cannot be set alight")
	var before := mob.hp
	var spark := Node.new()
	spark.add_to_group("lightning")
	SpellTargets.hurt(mob, 10, "Fire", false, false, spark)
	_verdict(before - mob.hp == 16, "lightning strikes a wet creature harder (%d of 10 dealt as 16)" % (before - mob.hp))
	mob.wet_time = 0.0
	Substances.oil(mob)
	_verdict(mob.is_oiled(), "oil clings to a creature")
	Substances.ignite(mob)
	_verdict(mob.burning_time > Substances.BURN_SECONDS * 1.5 and not mob.is_oiled(), "an oiled creature burns twice as long, and the oil burns away (%.1f s)" % mob.burning_time)
	# Any water that touches a creature soaks it, from any source: a stand-in that is no spell.
	mob.burning_time = 0.0
	var stand_in := Node2D.new()
	stand_in.set_script(preload("res://tests/checks/water_stand_in.gd"))
	world.add_child(stand_in)
	stand_in.global_position = mob.center()
	await get_tree().create_timer(0.5).timeout
	_verdict(mob.is_wet(), "water from no spell at all soaks a creature that stands in it")
	# Force shatters a body in ice: the kind of the blow, not the school.
	stand_in.queue_free()
	mob.wet_time = 0.0
	mob.freeze(4.0)
	_verdict(mob.is_frozen(), "a creature can be frozen")
	SpellTargets.hurt(mob, 10, "Earth")
	_verdict(not mob.is_frozen(), "force (Earth's, or Air's) shatters it out of the ice")
	# Moving air that is no spell puts a flare out, and a Barrier turns away a shot that is no spell.
	var flare := Flare.new()
	world.add_child(flare)
	flare.global_position = feet + Vector2(0.0, -300.0)
	var wind := Node2D.new()
	wind.set_script(preload("res://tests/checks/wind_stand_in.gd"))
	world.add_child(wind)
	wind.global_position = flare.global_position + Vector2(10.0, 0.0)
	await get_tree().create_timer(0.3).timeout
	_verdict(not is_instance_valid(flare) or flare.is_queued_for_deletion(), "wind from no spell at all puts a flare out")
	var shot := Node2D.new()
	shot.set_script(preload("res://tests/checks/shot_stand_in.gd"))
	world.add_child(shot)
	var wizard: Wizard = world.player
	wizard.raise_shield(5.0)
	_verdict(Elements.shield_turns(shot, wizard) and shot.turned, "a Barrier turns away a shot that is no spell at all")
	print("the laws work on every body" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

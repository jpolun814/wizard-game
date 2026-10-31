extends Node

## A Geyser's water is real liquid: on dry ground its first burst brings a little up, which falls and runs over the ground, and every burst after
## lifts it and lets it fall again without making more. Over a pool it lifts the pool's own water and gives it back.
##
##     godot --headless --fixed-fps 60 --path . tests/geyser_check.tscn
## It prints PASS or FAIL for each and exits with code 1 if any failed.

var _failures := 0


func _verdict(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


## All the liquid in the world's puddles made by spells.
func _loose_total() -> float:
	var sum := 0.0
	for pond: Pond in get_tree().get_nodes_in_group("ponds"):
		if pond.loose and pond.grid != null:
			sum += pond.grid.total()
	return sum


func _ready() -> void:
	World.random_start = false
	World.next_seed = 8
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var feet: Vector2 = world.player.global_position
	var space := world.get_world_2d()
	var spot := feet
	for dx in [-300.0, 300.0, -150.0, 150.0, 450.0, -450.0, 700.0, -700.0, 900.0, -900.0, 1200.0, -1200.0, 1600.0, -1600.0]:
		var probe := SpellTargets.solid_below(space, feet + Vector2(dx, -100.0))
		var level := SpellTargets.solid_below(space, probe + Vector2(200.0, -100.0)).y
		var near_water := false
		for pond: Pond in get_tree().get_nodes_in_group("ponds"):
			if probe.x > pond.global_position.x - 500.0 and probe.x < pond.global_position.x + pond.width + 500.0 and absf(probe.y - pond.global_position.y) < 400.0:
				near_water = true
		if not near_water and not is_equal_approx(probe.y, float(ArenaGen.GROUND_Y)) and absf(level - probe.y) < 40.0:
			spot = probe
			break
	world.player.global_position = spot + Vector2(-400.0, -40.0)
	world._ground.watch([spot], true)
	for k in 30:
		await get_tree().physics_frame
	_verdict(_loose_total() == 0.0, "there is no loose water to begin with")
	world.spawn_spell("Geyser", "shape", spot + Vector2(0.0, -20.0), 0.0, {"line": PackedVector2Array([spot + Vector2(-30.0, 0.0), spot + Vector2(0.0, -60.0), spot + Vector2(30.0, 0.0)])}, world.player)
	for k in int((Geyser.LIFE + 1.0) * 60.0):
		await get_tree().physics_frame
	var first := _loose_total()
	_verdict(absf(first - Geyser.SPRING) < 0.05, "the first burst on dry ground leaves its water on the ground (%.2f of %.2f)" % [first, Geyser.SPRING])
	for k in int((Geyser.LIFE + Geyser.REST) * 3.0 * 60.0):
		await get_tree().physics_frame
	var later := _loose_total()
	_verdict(absf(later - first) < 0.05, "and later bursts do not make more (%.2f)" % later)
	var wet_cells := 0
	for pond: Pond in get_tree().get_nodes_in_group("ponds"):
		if pond.loose:
			for m in pond.grid.mass:
				if m > LiquidGrid.MIN_MASS:
					wet_cells += 1
	_verdict(wet_cells >= 3, "the water has run out over the ground (%d wet cells)" % wet_cells)
	# Tide Surf brings up water too, and spills it where the ride ends.
	for node in get_tree().get_nodes_in_group("lasting"):
		if node is Geyser:
			while node._age < Geyser.LIFE or node._lifted > 0.0:  # (rests, with nothing in the air)
				await get_tree().physics_frame
			node.queue_free()
	await get_tree().physics_frame
	var water_before := _loose_total()
	world.player.global_position = spot + Vector2(-500.0, -60.0)
	world.player.velocity = Vector2.ZERO
	for k in 30:
		await get_tree().physics_frame
	var puddle0: Pond = get_tree().get_nodes_in_group("ponds")[0]
	var puddle_before: float = puddle0.grid.total()
	world.spawn_spell("Tide Surf", "directional", world.player.global_position, 0.0, {}, world.player)
	for k in int((TideSurf.SECONDS + 2.0) * 60.0):
		await get_tree().physics_frame
	var taken: float = puddle_before - puddle0.grid.total()  # (what the wave took up from the water it started in)
	var gained := _loose_total() - water_before
	_verdict(absf(gained + taken - TideSurf.WATER) < 0.1, "a ride on Tide Surf leaves the water it carried behind (%.2f spilt, %.2f of it taken from the water it started in, of %.2f)" % [gained + taken, taken, TideSurf.WATER])
	print("the geyser's water is real" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

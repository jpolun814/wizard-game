extends Check
## A Sinkhole opens in the ground of a world: the ground under it is lower after, and the ground beside it is as it was.
## With `-- out=DIR` (and no --headless) it also takes a picture of the pit.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/sinkhole_check.tscn
## It prints PASS or FAIL and exits with code 1 if any failed.



func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 8
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var feet: Vector2 = world.player.global_position
	var space := world.get_world_2d()
	var spot := feet
	for dx in [-300.0, 300.0, -150.0, 150.0, 450.0, -450.0, 700.0, -700.0, 900.0, -900.0, 1200.0, -1200.0, 1600.0, -1600.0, 2000.0, -2000.0, 2600.0, -2600.0]:
		var probe := SpellTargets.solid_below(space, feet + Vector2(dx, -100.0))
		var level := SpellTargets.solid_below(space, probe + Vector2(200.0, -100.0)).y
		var near_water := false
		for pond: Pond in get_tree().get_nodes_in_group("ponds"):
			if probe.x > pond.global_position.x - 400.0 and probe.x < pond.global_position.x + pond.width + 400.0 and absf(probe.y - pond.global_position.y) < 400.0:
				near_water = true
		var flat := true  # the ground under the whole of the U lies level, so that the pit's shape is the drawn shape
		for side in [-70.0, -35.0, 35.0, 70.0]:
			flat = flat and absf(SpellTargets.solid_below(space, probe + Vector2(side, -100.0)).y - probe.y) < 4.0
		if not near_water and flat and not is_equal_approx(probe.y, float(ArenaGen.GROUND_Y)) and absf(level - probe.y) < 40.0:
			spot = probe
			break
	var before := SpellTargets.solid_below(space, spot + Vector2(0.0, -60.0)).y
	world.player.global_position = spot + Vector2(-170.0, -40.0)
	world.player.velocity = Vector2.ZERO
	world._ground.watch([spot], true)
	for k in 30:
		await get_tree().physics_frame
	var pit_floor := Vector2i(floori(spot.x / float(ArenaGen.TILE)), floori((before + Sinkhole.DEPTH - 6.0) / float(ArenaGen.TILE)))
	_verdict(not world.nav.can_stand(pit_floor), "(before the pit the wizards cannot stand where its floor will be)")
	# The pit follows the line as it lies on the world: a U drawn down into the ground is as deep as it goes below the surface, and one drawn in
	# the air is let down onto the ground.
	var sunk := PackedVector2Array()
	var hung := PackedVector2Array()
	for k in 25:
		var u := float(k) / 24.0
		var dip := 1.0 - pow(absf(2.0 * u - 1.0), 2.0)
		sunk.append(Vector2(spot.x - 70.0 + 140.0 * u, before - 20.0 + 90.0 * dip))
		hung.append(Vector2(spot.x - 70.0 + 140.0 * u, before - 200.0 + 100.0 * dip))
	var into := Sinkhole.fit(space, sunk)
	_verdict(absf(float(into["depth"]) - 70.0) < 10.0 and absf(float(into["spot"].x) - spot.x) < 4.0, "a U drawn into the ground makes a pit as deep as it goes (%.0f px, drawn 70 below the surface)" % float(into["depth"]))
	var middle: float = into["profile"][8]
	var edge: float = into["profile"][0]
	_verdict(middle > 0.95 and edge < middle - 0.2, "and it is deepest in the middle, shallower at the edge (%.2f, %.2f)" % [middle, edge])
	var above := Sinkhole.fit(space, hung)
	_verdict(absf(float(above["depth"]) - 100.0) < 10.0, "a U drawn in the open air is let down onto the ground, as deep as it is tall (%.0f px, drawn 100 tall)" % float(above["depth"]))
	var began := Time.get_ticks_msec()
	world.spawn_spell("Sinkhole", "positional", spot + Vector2(0.0, -20.0), 0.0, {}, world.player)
	for k in int(Sinkhole.WARNING * 60.0) + 10:
		await get_tree().physics_frame
	var after := SpellTargets.solid_below(space, spot + Vector2(0.0, -60.0)).y
	_verdict(after > before + 60.0, "the ground under a Sinkhole is lower (%.0f px)" % (after - before))
	var beside := SpellTargets.solid_below(space, spot + Vector2(Sinkhole.HALF_WIDTH + 70.0, -100.0)).y
	_verdict(absf(beside - before) < 90.0, "and the ground beside it is as it was")
	for k in int(World.NAV_DELAY * 60.0) + 10:
		await get_tree().physics_frame
	# The wizards' map of the ways knows the pit: its floor can be stood on.
	var floor_tile := pit_floor
	_verdict(world.nav.can_stand(floor_tile), "the wizards' map has the floor of the pit to stand on (tile %s)" % floor_tile)
	var made: int = world.nav.version
	var timed := Time.get_ticks_usec()
	world.build_nav()
	print("INFO  the map of the ways was made %d time(s) so far; making it again takes %d ms" % [made, (Time.get_ticks_usec() - timed) / 1000])
	# A second pit dug close beside the first must not leave a thin wall of rock between them.
	for gap in [25.0, 60.0]:
		var level_y := before + 8.0
		var second := spot + Vector2(Sinkhole.HALF_WIDTH * 2.0 + gap, 0.0)
		second.y = SpellTargets.solid_below(space, second + Vector2(0.0, -100.0)).y
		world._ground.watch([second], true)
		world._ground.dig(second, Sinkhole.HALF_WIDTH, Sinkhole.DEPTH)
		var thinnest := INF
		var run := 0.0
		var seen_air := false
		for step in range(-40, 60):
			var x: float = spot.x - 100.0 + step * 6.0
			var wall := world._ground.solid_at(Vector2(x, level_y))
			if wall:
				run += 6.0
			else:
				if seen_air and run > 0.0:
					thinnest = minf(thinnest, run)
				run = 0.0
				seen_air = true
		_verdict(thinnest >= 48.0, "a pit dug %d px from another leaves no thin wall (thinnest %.0f px)" % [gap, thinnest if thinnest < INF else 0.0])
	print("INFO  the pit opened %d ms after it was cast" % (Time.get_ticks_msec() - began))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(argument.trim_prefix("out=") + "/sinkhole.png")
	print("the ground gives way" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)



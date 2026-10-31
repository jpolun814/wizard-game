extends Node

## A Sinkhole opens in the ground of a world: the ground under it is lower after, and the ground beside it is as it was.
## With `-- out=DIR` (and no --headless) it also takes a picture of the pit.
##
##     godot --headless --fixed-fps 60 --path . tests/sinkhole_check.tscn
## It prints PASS or FAIL and exits with code 1 if any failed.

var _failures := 0


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
	for dx in [-300.0, 300.0, -150.0, 150.0, 450.0, -450.0, 700.0, -700.0, 900.0, -900.0, 1200.0, -1200.0, 1600.0, -1600.0, 2000.0, -2000.0, 2600.0, -2600.0]:
		var probe := SpellTargets.solid_below(space, feet + Vector2(dx, -100.0))
		var level := SpellTargets.solid_below(space, probe + Vector2(200.0, -100.0)).y
		var near_water := false
		for pond: Pond in get_tree().get_nodes_in_group("ponds"):
			if probe.x > pond.global_position.x - 400.0 and probe.x < pond.global_position.x + pond.width + 400.0 and absf(probe.y - pond.global_position.y) < 400.0:
				near_water = true
		if not near_water and not is_equal_approx(probe.y, float(ArenaGen.GROUND_Y)) and absf(level - probe.y) < 40.0:
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
	world._build_nav()
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


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

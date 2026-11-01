extends Node

## A Sinkhole drawn as a U digs a pit of that shape in the ground of every kind of world, not only the first one tried.
##
##     godot --headless --fixed-fps 60 --path . tests/sinkhole_biomes_check.tscn -- seeds=0,1,4,5,13,2,3
## For each seed it finds open ground, casts a Sinkhole with a drawn U, and checks that the ground is lowest in the middle, near the
## walls at the sides, and in the order the U was drawn. It prints PASS or FAIL and exits with code 1 if any failed.

var _failures := 0
var _seen := {}


func _ready() -> void:
	var seeds := [0, 1, 2, 3, 4, 5, 6, 13]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("seeds="):
			seeds = []
			for part in argument.trim_prefix("seeds=").split(","):
				seeds.append(int(part))
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	var jump := Wizard.JUMP_VELOCITY * Wizard.JUMP_VELOCITY / (2.0 * gravity)
	_verdict(Sinkhole.DEEPEST < jump - 8.0, "the deepest pit can be jumped out of, so a wizard is never shut in one (%.0f px deep, a jump is %.0f)" % [Sinkhole.DEEPEST, jump])
	for seed_value: int in seeds:
		await _try(seed_value)
	print("every kind of ground gives way" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _try(seed_value: int) -> void:
	World.random_start = false
	World.next_seed = seed_value
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var biome := SurfaceGen.biome_at(world.graph.surface, world.graph.surface["start"])
	if _seen.has(biome):
		world.queue_free()
		await get_tree().process_frame
		return
	_seen[biome] = true
	var space := world.get_world_2d()
	var feet: Vector2 = world.player.global_position
	var spot := Vector2.ZERO
	for dx in [0.0, 300.0, -300.0, 500.0, -500.0, 800.0, -800.0, 1200.0, -1200.0, 1800.0, -1800.0, 2500.0, -2500.0]:
		var probe := SpellTargets.solid_below(space, feet + Vector2(dx, -100.0))
		var flat := true
		for side in [-130.0, -65.0, 65.0, 130.0]:
			flat = flat and absf(SpellTargets.solid_below(space, probe + Vector2(side, -100.0)).y - probe.y) < 24.0
		var in_pond := false
		for pond: Pond in get_tree().get_nodes_in_group("ponds"):
			if probe.x > pond.global_position.x - 300.0 and probe.x < pond.global_position.x + pond.width + 300.0 and absf(probe.y - pond.global_position.y) < 400.0:
				in_pond = true
		if flat and not in_pond:
			spot = probe
			break
	if spot == Vector2.ZERO:
		_verdict(false, "%s: found open flat ground (seed %d)" % [biome, seed_value])
		world.queue_free()
		await get_tree().process_frame
		return
	var drawn := PackedVector2Array()  # a lopsided U: steep on the left, a long slope on the right
	for k in 33:
		var u := float(k) / 32.0
		drawn.append(Vector2(spot.x - 80.0 + 160.0 * u, spot.y - 110.0 + 100.0 * (1.0 - pow(absf(2.0 * pow(u, 0.7) - 1.0), 2.0))))
	world._ground.watch([spot], true)
	for k in 20:
		await get_tree().physics_frame
	var before := SpellTargets.solid_below(space, spot + Vector2(0.0, -60.0)).y
	world.spawn_spell("Sinkhole", "positional", spot + Vector2(0.0, -20.0), 0.0, {"line": drawn}, world.player)
	for k in int(Sinkhole.WARNING * 60.0) + 20:
		await get_tree().physics_frame
	var floors := []
	for u in [0.1, 0.3, 0.5, 0.7, 0.9]:
		floors.append(SpellTargets.solid_below(space, Vector2(spot.x - 80.0 + 160.0 * u, before - 60.0)).y - before)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			world.player.global_position = spot + Vector2(-260.0, -60.0)
			world.player.max_stamina = 9999.0
			for k in 20:
				await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(argument.trim_prefix("out="))
			get_viewport().get_texture().get_image().save_png("%s/sink_%s.png" % [argument.trim_prefix("out="), biome])
	print("INFO  %s (seed %d) at %s (feet %s): the ground sank by %s" % [biome, seed_value, spot, feet, floors])
	_verdict(floors[2] > 50.0, "%s: the ground under the middle of the U sank" % biome)
	_verdict(floors[2] > floors[0] + 10.0 and floors[2] > floors[4] + 10.0, "%s: it sank most in the middle, less at the sides, as the U was drawn" % biome)
	var wall_open := not world._ground.solid_at(Vector2(spot.x - 80.0 + 160.0 * 0.1, before + 30.0))  # the left arm of this U is steep, so look at it from the side
	_verdict(wall_open and floors[4] > 8.0, "%s: and both sides are open too, so it is a pit and not a dimple" % biome)
	world.queue_free()
	await get_tree().process_frame


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

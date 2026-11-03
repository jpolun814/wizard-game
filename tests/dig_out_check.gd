extends Node

## The underground world is shut in by a roof of rock with sky past it, and a Sinkhole drawn at the underside of the roof digs up through it.
##
##     godot --headless --fixed-fps 60 --path . tests/dig_out_check.tscn
##     godot --fixed-fps 60 --path . tests/dig_out_check.tscn -- out=DIR     (pictures need a window)

var failed := false


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failed = true


func _ready() -> void:
	var out_dir := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			out_dir = argument.substr(4)
	var seed_value := -1
	for s in 400:
		MatchState.begin(s)
		if MatchState.biome_of(0) == "underground":
			seed_value = s
			break
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = seed_value
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	for k in 6:
		await get_tree().process_frame
	var ground: Terrain = world._ground
	var start: Vector2 = world.player.global_position
	var x := start.x
	ground.watch([Vector2(x, start.y - 600.0)], true)
	# Up from the floor of the cavern to the underside of its roof.
	var y := start.y
	while y > 0.0 and not ground.solid_at(Vector2(x, y)):
		y -= 8.0
	_check(y > 0.0, "there is a roof over the cavern (its underside at %.0f)" % y)
	var roof := y
	var sky_y := roof - float(WorldBuilder.ROOF_THICK + 2) * float(ArenaGen.TILE)
	_check(not ground.solid_at(Vector2(x, sky_y)), "and open sky past it (%.0f)" % sky_y)
	_check(ground.solid_at(Vector2(x, roof - 20.0)), "the roof is rock")
	world.player.global_position = Vector2(x, roof + 60.0)
	world.player.velocity = Vector2.ZERO
	ground.watch([Vector2(x, roof)], true)
	if out_dir != "" and DisplayServer.get_name() != "headless":
		for k in 10:
			await get_tree().process_frame
		DirAccess.make_dir_recursive_absolute(out_dir)
		get_viewport().get_texture().get_image().save_png(out_dir + "/roof_before.png")
	world.spawn_spell("Sinkhole", "positional", Vector2(x, roof + 6.0), 0.0, {}, world.player)
	for k in int(Sinkhole.WARNING * 60.0) + 40:
		await get_tree().physics_frame
	_check(not ground.solid_at(Vector2(x, roof - 20.0)), "after a Sinkhole at the roof the rock above is gone")
	_check(not ground.solid_at(Vector2(x, roof - float(WorldBuilder.ROOF_THICK) * float(ArenaGen.TILE) + 4.0)), "all the way through the roof")
	var far_y := start.y
	while far_y > 0.0 and not ground.solid_at(Vector2(x + 400.0, far_y)):
		far_y -= 8.0
	_check(far_y > 0.0 and ground.solid_at(Vector2(x + 400.0, far_y - 20.0)), "and the roof away from it is as it was")
	if out_dir != "" and DisplayServer.get_name() != "headless":
		for k in 30:
			world.player.global_position = Vector2(x, roof - 70.0)  # standing in the way out
			world.player.velocity = Vector2.ZERO
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out_dir + "/roof_after.png")
	print("the roof is dug through" if not failed else "dig out check FAILED")
	get_tree().quit(1 if failed else 0)

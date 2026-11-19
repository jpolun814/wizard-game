extends Node

## Tide Surf on a hill, once each way. `WORLD_SEED=4 ... -- out=DIR` (needs a window).


func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	var in_world := OS.get_cmdline_user_args().has("world")
	if in_world:
		World.random_start = false
		World.arrive_by_portal = false
		World.next_seed = int(OS.get_environment("WORLD_SEED")) if OS.get_environment("WORLD_SEED") != "" else 4
	var arena: Node = load("res://scenes/world.tscn" if in_world else "res://scenes/lab.tscn").instantiate()
	add_child(arena)
	for k in 40:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(out)
	var shift := -100.0  # the ramp at the left of the start
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("shift="):
			shift = float(arg.substr(6))
	var player: Wizard = arena.player
	player.ledger.learn_all()
	for side in [1.0, -1.0]:
		if in_world and side > 0.0:
			var column := 330
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("column="):
					column = int(arg.substr(7))
			var floors: PackedInt32Array = arena.graph.surface["floor"]
			var at := Vector2((column + 0.5) * 32.0, floors[column] * 32.0 - 60.0)
			arena._ground.watch([at] as Array[Vector2], true)
			for k in 15:
				await get_tree().physics_frame
			player.global_position = arena.landing(at)
		elif not in_world and side > 0.0:
			player.global_position = arena.landing(player.global_position + Vector2(shift, -40.0))
		player.velocity = Vector2.ZERO
		player.facing = side
		await get_tree().physics_frame
		arena.casting.by("Tide Surf", "caster", player.global_position, 0.0 if side > 0.0 else PI, {"accuracy": 0.9}, player)
		await get_tree().create_timer(0.7).timeout
		get_viewport().get_texture().get_image().save_png(out + "/slope_%da.png" % int(side))
		await get_tree().create_timer(0.35).timeout
		get_viewport().get_texture().get_image().save_png(out + "/slope_%d.png" % int(side))
		for node in get_tree().get_nodes_in_group("lasting"):
			if node is TideSurf:
				node.queue_free()
		player.surf_time = 0.0
		await get_tree().create_timer(0.8).timeout
	get_tree().quit()

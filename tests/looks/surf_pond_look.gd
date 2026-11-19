extends Node

## Tide Surf across the waiting room's pond: a run of frames, and what the wave reads of the water and the ground. `-- out=DIR` (needs a window).


func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	var room: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(room)
	for k in 60:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(out)
	var pond_span: Vector2i = room._at(Lab.POND)
	var player: Wizard = room.player
	player.ledger.learn_all()
	player.facing = 1.0
	player.global_position = room.landing(Vector2(ArenaGen.column_x(pond_span.x - 5), ArenaGen.GROUND_Y - 40.0))
	player.velocity = Vector2.ZERO
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		camera.reset_smoothing()
	await get_tree().create_timer(0.5).timeout
	room.casting.by("Tide Surf", "caster", player.global_position, 0.0, {"accuracy": 0.9}, player)
	for frame in 20:
		await get_tree().create_timer(0.1).timeout
		get_viewport().get_texture().get_image().save_png(out + "/pond_%02d.png" % frame)
		for node in get_tree().get_nodes_in_group("lasting"):
			if node is TideSurf and frame % 5 == 0:
				var ponds := get_tree().get_nodes_in_group("ponds")
				var water := INF
				for pond: Pond in ponds:
					if not pond.lava and pond.grid != null:
						water = minf(water, pond.grid.surface_at(player.global_position.x + 60.0))
				print("frame ", frame, " rider ", player.global_position, " water_at_front ", water, " floor ", node._floor)
	get_tree().quit()

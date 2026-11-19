extends Node

## Oil Slick and Mudslide on uneven ground in the waiting room: under the floating slab, on top of it, across its edge, and at the pond's slope. `-- out=DIR` (needs a window).


func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	var room: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(room)
	for k in 40:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(out)
	var tile := float(ArenaGen.TILE)
	var slab: Vector2i = room._at(Lab.CEILING)
	var slab_middle: float = (slab.x + slab.y) * 0.5
	var pond: Vector2i = room._at(Lab.POND)
	var pond_edge := float(pond.x) - 1.0
	var player: Wizard = room.player
	player.ledger.learn_all()
	player.facing = 1.0
	# (name, spell, x column, y offset above the ground, width)
	var shots := [
		["under_oil", "Oil Slick", slab_middle, ArenaGen.GROUND_Y - 10.0, 200.0],
		["under_mud", "Mudslide", slab_middle, ArenaGen.GROUND_Y - 10.0, 200.0],
		["top_oil", "Oil Slick", slab_middle, -3.0 * tile - 10.0, 200.0],
		["top_mud", "Mudslide", slab_middle, -3.0 * tile - 10.0, 200.0],
		["edge_oil", "Oil Slick", float(slab.y) - 1.0, -3.0 * tile - 10.0, 260.0],
		["edge_mud", "Mudslide", float(slab.y) - 1.0, -3.0 * tile - 10.0, 260.0],
		["high_mud", "Mudslide", slab_middle, -3.0 * tile + 10.0, 200.0],
		["pond_oil", "Oil Slick", pond_edge, ArenaGen.GROUND_Y - 10.0, 260.0],
		["pond_mud", "Mudslide", pond_edge, ArenaGen.GROUND_Y - 10.0, 260.0],
	]
	for shot in shots:
		for node in get_tree().get_nodes_in_group("lasting"):
			if node is OilSlick or node is Mudslide:
				node.queue_free()
		await get_tree().process_frame
		var x := ArenaGen.column_x(int(shot[2]))
		var at := Vector2(x, shot[3])
		player.global_position = room.landing(Vector2(x - 150.0, shot[3] - 20.0))
		var camera := get_viewport().get_camera_2d()
		if camera != null:
						camera.reset_smoothing()
		var line := PackedVector2Array([at + Vector2(-shot[4] * 0.5, 0.0), at + Vector2(shot[4] * 0.5, 0.0)])
		room.casting.by(shot[1], "shape", at, 0.0, {"accuracy": 0.9, "line": line}, player)
		await get_tree().create_timer(1.2).timeout
		print(shot[0], " player ", player.global_position, " camera ", camera.global_position if camera != null else Vector2.ZERO)
		get_viewport().get_texture().get_image().save_png(out + "/pool_%s.png" % shot[0])
	get_tree().quit()

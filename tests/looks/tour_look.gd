extends Node

## A walk along a whole open world: a picture at columns spread across it, and at its highest and lowest ground. `WORLD_SEED=4` is the snowy peaks.
## `-- out=DIR stops=20` (needs a window).


func _ready() -> void:
	var out := ""
	var stops := 20
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
		elif arg.begins_with("stops="):
			stops = int(arg.substr(6))
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = int(OS.get_environment("WORLD_SEED")) if OS.get_environment("WORLD_SEED") != "" else 4
	var arena: Node = load("res://scenes/world.tscn").instantiate()
	add_child(arena)
	for k in 30:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(out)
	var tile := float(ArenaGen.TILE)
	var surface: Dictionary = arena.graph.surface
	var floors: PackedInt32Array = surface["floor"]
	var player: Wizard = arena.player
	var columns: Array = []
	for k in stops:
		columns.append(int((k + 0.5) * floors.size() / stops))
	var high := 0
	var low := 0
	for c in floors.size():
		if floors[c] < floors[high]:
			high = c
		if floors[c] > floors[low]:
			low = c
	columns.append(high)
	columns.append(low)
	print("world ", floors.size(), " columns; highest floor row ", floors[high], " at ", high, "; lowest row ", floors[low], " at ", low)
	var n := 0
	for column: int in columns:
		var at := Vector2((column + 0.5) * tile, floors[column] * tile - 60.0)
		arena._ground.watch([at] as Array[Vector2], true)
		for k in 10:
			await get_tree().physics_frame
		at = arena.landing(at)
		at.y -= 20.0
		player.global_position = at
		player.velocity = Vector2.ZERO
		arena._dark.hide()
		arena._ground.watch([at] as Array[Vector2], true)
		var camera: Camera2D = arena.get_node("Player/Camera2D")
		camera.reset_smoothing()
		for k in 50:
			await get_tree().physics_frame
		player.global_position = at
		player.velocity = Vector2.ZERO
		for k in 20:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/tour_%02d_c%d_row%d.png" % [out, n, column, floors[column]])
		n += 1
	get_tree().quit()

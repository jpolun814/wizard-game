extends Node

## Prints where the pages of a world lie along it (in columns) and the gaps between neighbours, to see whether they bunch up.
##
##     godot --headless --fixed-fps 60 --path . tests/pages_spread_look.tscn -- seeds=4,10,17

func _ready() -> void:
	var seeds := [4]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("seeds="):
			seeds = []
			for part in argument.trim_prefix("seeds=").split(","):
				seeds.append(int(part))
	for seed_value: int in seeds:
		World.random_start = false
		World.next_seed = seed_value
		MatchState.hurry = 100.0
		var world: World = load("res://scenes/world.tscn").instantiate()
		add_child(world)
		for k in 6:
			await get_tree().process_frame
		var biome := SurfaceGen.biome_at(world.graph.surface, world.graph.surface["start"])
		var columns: Array = []
		for page in get_tree().get_nodes_in_group("pages"):
			columns.append(int(page.global_position.x / 32.0))
		columns.sort()
		var gaps: Array = []
		for k in range(1, columns.size()):
			gaps.append(columns[k] - columns[k - 1])
		print("seed %d (%s): %d pages at %s; gaps %s" % [seed_value, biome, columns.size(), columns, gaps])
		world.queue_free()
		await get_tree().process_frame
	get_tree().quit()

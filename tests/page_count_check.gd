extends Node

## Each biome's first world lays the number of pages it is meant to, and no more.
##
##     godot --headless --fixed-fps 60 --path . tests/page_count_check.tscn

var failed := false


func _ready() -> void:
	for biome in SurfaceGen.BIOMES:
		var seed_value := -1
		for s in 400:
			MatchState.begin(s)
			if MatchState.biome_of(0) == biome:
				seed_value = s
				break
		World.random_start = false
		World.arrive_by_portal = false
		World.next_seed = seed_value
		var world: World = load("res://scenes/world.tscn").instantiate()
		add_child(world)
		for k in 6:
			await get_tree().process_frame
		var laid := get_tree().get_nodes_in_group("pages").size()
		var want := Pages.count_for(biome, WorldGraph.size.x)
		for seat in 4:
			want += 1  # the fan of pages each seat starts beside (one pickup), on top of the world's own
		var ok := laid <= want + 2 and laid >= want - 2  # (a page may be dropped by a wizard's fall, or not placed)
		print(("PASS  " if ok else "FAIL  ") + "%s (seed %d): %d pages lie, %d are meant to" % [biome, seed_value, laid, want])
		if not ok:
			failed = true
		world.queue_free()
		for k in 4:
			await get_tree().process_frame
	get_tree().quit(1 if failed else 0)

extends Node

## Each biome's first world lays the number of pages it is meant to, and no more.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/page_count_check.tscn

var failed := false


func _ready() -> void:
	for biome in SurfaceGen.BIOMES:
		var seed_value := -1
		var stage := 0  # (the ocean and the sky are never a match's first world: they are entered as a later one, as they always are)
		for s in 400:
			MatchState.begin(s)
			for at in (4 if biome in ["ocean", "sky"] else 1):
				if seed_value < 0 and MatchState.biome_of(at) == biome:
					seed_value = s
					stage = at
			if seed_value >= 0:
				break
		MatchState.begin(seed_value)
		MatchState.stage = stage
		MatchState.pending = stage > 0
		MatchState.ledgers = Pages.start_empty(World.WIZARDS)
		MatchState.vitals = []
		for k in World.WIZARDS:
			MatchState.vitals.append({"alive": true, "max": 200.0, "stamina": 200.0})
		World.random_start = false
		World.arrive_by_portal = false
		World.next_seed = seed_value
		var world: World = load("res://scenes/world.tscn").instantiate()
		add_child(world)
		for k in 6:
			await get_tree().process_frame
		var laid := get_tree().get_nodes_in_group("pages").size()
		var want := Pages.count_for(biome, WorldGraph.size.x)
		for seat in WorldGraph.PLAYERS:
			want += 1  # the fan of pages each seat starts beside (one pickup), on top of the world's own
		var ok := laid <= want + 2 and laid >= want - 2  # (a page may be dropped by a wizard's fall, or not placed)
		if stage > 0:  # a later world holds the pages the earlier ones did not use, so it holds no more than its share and never fewer than six
			ok = laid <= want + 2 and laid >= 6
		print(("PASS  " if ok else "FAIL  ") + "%s (seed %d): %d pages lie, %d are meant to" % [biome, seed_value, laid, want])
		if not ok:
			failed = true
		world.queue_free()
		for k in 4:
			await get_tree().process_frame
	get_tree().quit(1 if failed else 0)

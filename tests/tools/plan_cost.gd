extends Node
## What the movement planning costs in a real world (docs/handoff/23_movement_planning.md, stage 2): plans from places to stand to pages, for wizards with the movement spells of a book.
##
##     godot --headless --path . tests/tools/plan_cost.tscn -- seed=10042159 [biome=castle] [plans=24] [spells=4] [show=1]

const MOVERS := ["Shadow Step", "Rocket Jump", "Updraft", "Geyser", "Push", "Liana", "Featherfall"]


func _ready() -> void:
	var seed_value := 10042159
	var plans := 24
	var held := 4
	var show := false
	var biome := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):
			seed_value = int(arg.substr(5))
		elif arg.begins_with("biome="):
			biome = arg.substr(6)
		elif arg.begins_with("plans="):
			plans = int(arg.substr(6))
		elif arg.begins_with("spells="):
			held = int(arg.substr(7))
		elif arg == "show=1":
			show = true
	MatchRecorder.silent = true
	World.random_start = false
	World.arrive_by_portal = false
	MatchState.begin(seed_value)
	while biome != "" and MatchState.biome_of(0) != biome:  # (the next seed whose first world is that one: a world that begins a match is what its seed says)
		seed_value += 1
		MatchState.begin(seed_value)
	World.next_seed = seed_value
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	var cells: TileGrid = world._cells
	var began := Time.get_ticks_usec()
	var map := MoveMap.new(cells, cells.size.y)
	print("map of %s: %d x %d, made in %.0f ms" % [MatchState.plan()["biome"], cells.size.x, cells.size.y, (Time.get_ticks_usec() - began) / 1000.0])
	var dice := Dice.of(["plan cost"])
	var goals: Array[Vector2i] = []
	for page: Node in get_tree().get_nodes_in_group("pages"):
		var tile := Vector2i(floori(page.global_position.x / ArenaGen.TILE), floori(page.global_position.y / ArenaGen.TILE))
		for down in range(-2, 8):
			if map.can_stand(tile + Vector2i(0, down)):
				goals.append(tile + Vector2i(0, down))
				break
	print("pages to go to: %d; wizards start at %d places" % [goals.size(), world.spawn_tiles.size()])
	if goals.is_empty():
		get_tree().quit()
		return
	var took: Array[float] = []
	var warm: Array[float] = []
	var longest := 0
	var found := 0
	var on_foot := 0
	for k in plans:
		var spells: Array[Spell] = []
		var bag := MOVERS.duplicate()
		for n in held:
			var pick: int = dice.randi() % bag.size()
			spells.append(SpellData.SPELLS[bag[pick]])
			bag.remove_at(pick)
		var from: Vector2i = world.spawn_tiles[dice.randi() % world.spawn_tiles.size()]
		if not map.can_stand(from):
			for down in range(-3, 4):
				if map.can_stand(from + Vector2i(0, down)):
					from += Vector2i(0, down)
					break
		var near := goals.duplicate()
		near.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_squared_to(from) < b.distance_squared_to(from))
		var to: Vector2i = near[dice.randi() % mini(4, near.size())]
		var plan := MovePlan.new(map, from, to, {"spells": spells})
		var started := Time.get_ticks_usec()
		plan.work()
		var ms := (Time.get_ticks_usec() - started) / 1000.0
		var walk := MovePlan.new(map, from, to, {"spells": []})
		walk.work()
		var again := MovePlan.new(map, from, to, {"spells": spells})
		started = Time.get_ticks_usec()
		again.work()
		warm.append((Time.get_ticks_usec() - started) / 1000.0)
		var slice := 0
		var most := MovePlan.new(MoveMap.new(cells, cells.size.y), from, to, {"spells": spells}) if k < 6 else null
		while most != null:  # in slices of 1 ms, on a map nobody has thought about yet: the longest one
			var at := Time.get_ticks_usec()
			var over := most.work(20)
			slice = maxi(slice, Time.get_ticks_usec() - at)
			if over:
				break
		longest = maxi(longest, slice)
		took.append(ms)
		found += 1 if plan.found else 0
		on_foot += 1 if walk.found else 0
		if show:
			var casts := PackedStringArray()
			for leg in plan.legs():
				for cast in leg.casts:
					casts.append("%s(%d,%d>%d,%d)" % [cast["spell"].spell_name, floori(cast["at"].x / 32.0), floori((cast["at"].y - 1.0) / 32.0), leg.to.x, leg.to.y])
			print("%s -> %s  %s in %.0f ms, %d places, %d flights, %.1f s (on foot %s): %s" % [from, to, ("walks" if plan.on_foot() else "found") if plan.found else "NONE", ms, plan.places, plan.flights, plan.cost() if plan.found else 0.0, "%.1f s" % walk.cost() if walk.found else "no way", ", ".join(casts)])
	warm.sort()
	print("thought of again: median %.0f ms, worst %.0f; the longest slice of those asked for 20 units of work: %.1f ms" % [warm[warm.size() / 2], warm[-1], longest / 1000.0])
	took.sort()
	print("edges kept %d" % map.edges.size())
	print("%d plans: %d found (%d on foot alone); ms: median %.0f, 90%% %.0f, worst %.0f, all %.0f" % [plans, found, on_foot, took[took.size() / 2], took[int(took.size() * 0.9)], took[-1], took.reduce(func(a: float, b: float) -> float: return a + b)])
	get_tree().quit()

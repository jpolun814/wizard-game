extends Node

## Nobody starts a match with a spell: the pages each wizard would have been dealt lie in a cluster of their own by their spawn in the first
## world. For each seed: every ledger is empty, each seat's five pages lie near its spawn (each page once in the whole world), and a body with no
## spell can walk to every one of them from the spawn.
##
##     godot --headless --fixed-fps 60 --path . tests/cluster_check.tscn -- seeds=0,1,4,5,13
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	var seeds: Array[int] = [0, 1, 4, 5, 13]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seeds="):
			seeds.clear()
			for part in arg.substr(6).split(","):
				seeds.append(int(part))
	World.random_start = false
	World.arrive_by_portal = false
	for seed_value in seeds:
		World.next_seed = seed_value
		var world: World = load("res://scenes/world.tscn").instantiate()
		add_child(world)
		await get_tree().process_frame
		await get_tree().process_frame
		await _check(world, seed_value)
		world.queue_free()
		await get_tree().process_frame
	print("every wizard starts with nothing, and finds their pages close by" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(world: World, seed_value: int) -> void:
	var biome := MatchState.biome_of(0)
	var tag := "seed %d (%s)" % [seed_value, biome]
	_verdict(world.ledgers.size() == World.WIZARDS and world.ledgers.all(func(l) -> bool: return l.pages.is_empty()), "%s: nobody holds a page at the start" % tag)
	var pickups: Array = []
	for node in world.get_children():
		if node is PagePickup:
			pickups.append(node)
	var clusters := pickups.slice(pickups.size() - World.WIZARDS)  # laid last: one fan of pages for each seat
	var elsewhere := pickups.slice(0, pickups.size() - World.WIZARDS)
	var places := world.places()
	var walks := []  # collected before any walking, which is slow and lets the world change
	for seat in World.WIZARDS:
		var mine := Pages.cluster_of(MatchState.seed_base, seat, World.WIZARDS)
		_verdict(mine.size() == 5, "%s: seat %d has five pages in its cluster" % [tag, seat])
		var fan: PagePickup = clusters[seat]
		_verdict(fan.fan and fan.spoils.size() == mine.size(), "%s: seat %d's pages lie together as one fan (%d)" % [tag, seat, fan.spoils.size()])
		for page in mine:
			_verdict(fan.spoils.count(page) == 1, "%s: %s lies once in seat %d's fan" % [tag, page, seat])
			if not page.begins_with("chant:"):
				_verdict(not elsewhere.any(func(p) -> bool: return p.page == page or p.spoils.has(page)) and not clusters.any(func(p) -> bool: return p.spoils.has(page) and p != fan), "%s: %s lies nowhere else" % [tag, page])
		var near: bool = absf(fan.global_position.x - places[seat].x) <= (WorldPages.CLUSTER_REACH + 1) * 32.0 and absf(fan.global_position.y - places[seat].y) <= 160.0
		_verdict(near, "%s: seat %d's pages lie within a short walk of its spawn" % [tag, seat])
		walks.append([places[seat], [fan], "%s seat %d" % [tag, seat]])
	for walk in walks:
		await _walk_to_all(world, walk[0], walk[1], walk[2])


## Stands the player at a spawn and walks them to each page, jumping when stuck, with no spell.
func _walk_to_all(world: World, spawn: Vector2, spots: Array, tag: String) -> void:
	var player: Wizard = world.player
	player.global_position = spawn
	player.velocity = Vector2.ZERO
	await get_tree().physics_frame
	var reached := 0
	for pickup in spots:
		var waited := 0.0
		var stalled := 0.0
		var last_x := player.global_position.x
		while waited < 14.0 and is_instance_valid(pickup) and not pickup.is_under(player):
			var dx: float = pickup.global_position.x - player.global_position.x
			Input.action_press("move_right" if dx > 0.0 else "move_left")
			Input.action_release("move_left" if dx > 0.0 else "move_right")
			await get_tree().physics_frame
			waited += get_physics_process_delta_time()
			stalled = stalled + get_physics_process_delta_time() if absf(player.global_position.x - last_x) < 1.0 else 0.0
			last_x = player.global_position.x
			if stalled > 0.3:
				Input.action_press("jump")
				await get_tree().physics_frame
				Input.action_release("jump")
		Input.action_release("move_left")
		Input.action_release("move_right")
		if not is_instance_valid(pickup) or pickup.is_under(player):
			reached += 1  # (a page already gone was read by that seat's own brain, which walked to it)
	_verdict(reached == spots.size(), "%s: walked to %d of %d pages" % [tag, reached, spots.size()])


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

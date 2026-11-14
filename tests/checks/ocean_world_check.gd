extends Node

## The ocean world (chapter 20): a sea over the whole world with very few islands, driftwood to start on, wrecks with an air pocket and a page, driftwood to stand on, kelp that hides.
## A wizard out of its depth swims; its breath runs out under water and comes back in an air pocket.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/ocean_world_check.tscn

var failed := false
var _seen: Node


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failed = true


func _ready() -> void:
	var seed_value := 3
	for s in 400:
		MatchState.begin(s)
		if MatchState.biome_of(1) == "ocean" or MatchState.biome_of(2) == "ocean":
			seed_value = s
			break
	var at := 1 if MatchState.biome_of(1) == "ocean" else 2
	_check(MatchState.biome_of(at) == "ocean", "a match reaches the ocean world (seed %d, world %d)" % [seed_value, at])
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = seed_value
	MatchState.begin(seed_value)
	MatchState.stage = at  # (the world is entered as a later one of the match, as it always is)
	MatchState.pending = true
	MatchState.ledgers = Pages.start_empty(World.WIZARDS)
	MatchState.vitals = []
	for k in World.WIZARDS:
		MatchState.vitals.append({"alive": true, "max": 200.0, "stamina": 200.0})
	call_deferred("_start")


func _start() -> void:
	reparent(get_tree().root)
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if not (scene is World) or scene == _seen or scene.player == null or scene.ledgers.size() == 0 or scene.nav == null:
		return
	_seen = scene
	set_process(false)
	_run(scene)


func _count(world: World, kind: Variant) -> int:
	return world.get_children().filter(func(n: Node) -> bool: return is_instance_of(n, kind)).size()


func _run(world: World) -> void:
	for k in 10:
		await get_tree().process_frame
	var seas := world.get_children().filter(func(n: Node) -> bool: return n is Pond and n.deep)
	_check(seas.size() >= 2 and absf(seas.map(func(n: Pond) -> float: return n.width).reduce(func(a: float, b: float) -> float: return a + b) - ArenaGen.world_size.x * float(World.TILE)) < 1.0, "the deep sea lies over the whole world, in lengths (%d)" % seas.size())
	_check(_count(world, Wreck) >= 3, "wrecks lie on the floor (%d)" % _count(world, Wreck))
	_check(_count(world, Driftwood) + _count(world, KelpPatch) > 4, "driftwood floats and kelp grows (%d, %d)" % [_count(world, Driftwood), _count(world, KelpPatch)])
	_check(not world.flies(), "nobody flies in the ocean")
	var sea: Pond = seas[0]
	# A wizard put into the deep swims and runs out of breath.
	var wizard: Wizard = world.player
	var floors: PackedInt32Array = world.graph.surface["floor"]
	var deepest := SurfaceGen.MARGIN
	for c in range(SurfaceGen.MARGIN, floors.size() - SurfaceGen.MARGIN):
		if floors[c] > floors[deepest]:
			deepest = c
	wizard.global_position = Vector2((deepest + 0.5) * World.TILE, floors[deepest] * float(World.TILE) - 200.0)
	wizard.velocity = Vector2.ZERO
	var before := wizard.lungs.air
	for k in 90:
		await get_tree().physics_frame
	print("   wizard at ", wizard.global_position, " sea ", sea.position, " floor ", floors[deepest], " swim ", wizard.swim_time, " breath ", wizard.lungs.air, " under ", wizard.lungs.submerged())
	_check(wizard.swim_time > 0.0, "a wizard out of its depth swims")
	_check(wizard.lungs.air < before, "and its breath runs down under the water")
	# The same wizard in a wreck's air pocket keeps its breath.
	var wreck: Wreck = world.get_children().filter(func(n: Node) -> bool: return n is Wreck).front()
	_check(AirPocket.holds(get_tree(), wreck.pocket.global_position + Vector2(0.0, -40.0)), "a wreck has an air pocket")
	# Refusals: a spell that needs ground fizzles under water for want of it.
	_check(SpellLimits.refusal(wizard, "Fire Breath") != "", "fire fizzles under water")
	_check(SpellLimits.refusal(wizard, "Stone Wall") == "" or SpellLimits.refusal(wizard, "Stone Wall") != "No ground", "a Stone Wall can still be raised on the sea floor")
	# A wreck is a thing in the water: a wizard sinking onto its bow comes to rest on the hull, and one sinking onto the stern's deck stands on the deck.
	var both_ways := []  # a wreck lying each way round, if there are both: the solid parts are turned point by point
	for node in world.get_children():
		if node is Wreck and both_ways.filter(func(w: Wreck) -> bool: return signf(w.pocket.position.x) == signf(node.pocket.position.x)).is_empty():
			both_ways.append(node)
	for pair in both_ways.size() * 2:
		var on_wreck: Wreck = both_ways[pair / 2]
		var spot: Vector2 = [Vector2(120.0, 82.0), Vector2(400.0, 112.0)][pair % 2]
		var side := 1.0 if on_wreck.pocket.position.x > 0.0 else -1.0
		var on := on_wreck.global_position + Vector2((spot.x - Wreck.ORIGIN.x) * side, spot.y - Wreck.ORIGIN.y)
		wizard.global_position = on + Vector2(0.0, -70.0)
		wizard.velocity = Vector2.ZERO
		wizard.lungs.air = Lungs.BREATH
		for k in 100:
			await get_tree().physics_frame
		var rests := absf(wizard.global_position.y - on.y) < 24.0 and wizard.global_position.y < on_wreck.global_position.y - 30.0
		_check(rests, "a wizard comes to rest on the %s of a wreck turned %s (%.0f, the hull at %.0f, the floor at %.0f)" % ["bow" if spot.x < 288.0 else "deck", "right" if side > 0.0 else "left", wizard.global_position.y, on.y, on_wreck.global_position.y])
	# A bonfire lit on the sea floor goes out at once; one on the island in the middle burns.
	var fires_before := _count(world, Bonfire)
	world.kindle(Vector2((deepest + 0.5) * World.TILE, floors[deepest] * float(World.TILE)), 1.0)
	_check(_count(world, Bonfire) == fires_before, "a bonfire under water goes out")
	var middle := floors.size() / 2
	world.kindle(Vector2((middle + 0.5) * World.TILE, floors[middle] * float(World.TILE)), 1.0)
	_check(_count(world, Bonfire) == fires_before + 1, "a bonfire on the island burns")
	print("RESULT  ", "FAILED" if failed else "ok")
	get_tree().quit(1 if failed else 0)

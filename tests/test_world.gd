extends SceneTree

## Checks the world generator: one seed always builds the same world, every room of every world can be walked to from
## the start, and incantations and seeds convert both ways. Pass `-- out=DIR` to save a picture of one world's map.
##
## Run from the project folder:
##     godot --headless -s tests/test_world.gd
## It prints each failure and exits with code 1 if anything failed.

var seeds := 300
var picture_seed := 7

var _failures := 0


func _initialize() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
		elif arg.begins_with("pic="):
			picture_seed = int(arg.substr(4))
		elif arg.begins_with("seeds="):
			seeds = int(arg.substr(6))
	for s in 2000:
		var value := s * 7919
		if Incantation.seed_of(Incantation.words_for(value)) != value:
			_fail("incantation round trip failed for seed %d" % value)
			break
	var rooms_seen := 0
	var ponds_seen := 0
	var lava_seen := 0
	for s in seeds:
		var world := _make(s)
		var again := _make(s)
		if hash(world["cells"]) != hash(again["cells"]) or world["graph"].boss != again["graph"].boss:
			_fail("seed %d did not build the same world twice" % s)
		var graph: WorldGraph = world["graph"]
		rooms_seen += graph.rooms.size()
		var seen := WorldBuilder.reachable(world["cells"], world["start"], world["size"].y, world["hazards"])
		for room in graph.rooms:
			if not seen.has(world["markers"][room["id"]]):
				_fail("seed %d: room %d (%s) cannot be reached from the start" % [s, room["id"], room["kind"]])
		var boss: Dictionary = graph.rooms[graph.boss]
		for pond in world["ponds"]:
			ponds_seen += 1
			lava_seen += 1 if pond["lava"] else 0
		if boss["depth"] < 3:
			_fail("seed %d: the boss is only %d doors from the start" % [s, boss["depth"]])
	# The check must be able to fail: with walls across the surface on both sides of the start, some room has to become unreachable.
	var broken := _make(1)
	broken["hazards"] = {}
	for r in range(0, WorldGraph.SURFACE_ROW):
		for dx in [-12, 12]:
			broken["cells"][Vector2i(broken["start"].x + dx, r)] = ArenaGen.GROUND
	var cut := WorldBuilder.reachable(broken["cells"], broken["start"], broken["size"].y, broken["hazards"])
	var lost := 0
	for room in broken["graph"].rooms:
		if not cut.has(broken["markers"][room["id"]]):
			lost += 1
	if lost == 0:
		_fail("the reachability check passed a world with no way up")
	print("%d worlds, %d rooms, %d ponds (%d of lava) checked" % [seeds, rooms_seen, ponds_seen, lava_seen])
	if out != "":
		_picture(_make(picture_seed), out)
	print("%d failures" % _failures if _failures > 0 else "all world checks passed")
	quit(1 if _failures > 0 else 0)


func _make(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var graph := WorldGraph.build(rng)
	var world := WorldBuilder.build(graph, rng)
	world["graph"] = graph
	return world


func _fail(text: String) -> void:
	_failures += 1
	print("FAIL  " + text)


## One pixel block per tile: rock dark, castle stone tan, and each room's marker coloured by its kind.
func _picture(world: Dictionary, dir: String) -> void:
	var scale := 3
	var size: Vector2i = world["size"]
	var image := Image.create(size.x * scale, size.y * scale, false, Image.FORMAT_RGB8)
	image.fill(Color("#15101c"))
	for cell in world["cells"]:
		var colour := Color("#6a5a7a") if world["cells"][cell] == ArenaGen.GROUND else Color("#d0a050")
		image.fill_rect(Rect2i(cell * scale, Vector2i(scale, scale)), colour)
	for pond in world["ponds"]:
		image.fill_rect(Rect2i(Vector2i(pond["a"], pond["surface"]) * scale, Vector2i(pond["b"] - pond["a"] + 1, pond["depth"]) * scale), Color.ORANGE_RED if pond["lava"] else Color.DODGER_BLUE)
	var graph: WorldGraph = world["graph"]
	var kinds := {"start": Color.LIME, "boss": Color.RED, "branch": Color.YELLOW, "area": Color.CYAN}
	for room in graph.rooms:
		var at: Vector2i = world["markers"][room["id"]]
		image.fill_rect(Rect2i((at - Vector2i(1, 6)) * scale, Vector2i(scale * 3, scale * 7)), kinds[room["kind"]])
	DirAccess.make_dir_recursive_absolute(dir)
	image.save_png(dir.path_join("world_%d.png" % picture_seed))
	print("saved the map of seed %d to %s" % [picture_seed, dir])

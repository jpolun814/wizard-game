extends SceneTree

## Checks the world generator: one seed always builds the same world, every room of every world can be walked to from
## the start, and incantations and seeds convert both ways. Pass `-- out=DIR` to save a picture of one world's map.
##
## Run from the project folder:
##     godot --headless -s tests/test_world.gd
## It prints each failure and exits with code 1 if anything failed.

var seeds := 300
var first := 0
var picture_seed := 7

var _failures := 0


func _initialize() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
		elif arg.begins_with("pic="):
			picture_seed = int(arg.substr(4))
		elif arg.begins_with("first="):
			first = int(arg.substr(6))
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
	var kinds := {}
	for s in range(first, first + seeds):
		var world := _make(s)
		var again := _make(s)
		if hash(world["cells"].data) != hash(again["cells"].data) or world["graph"].boss != again["graph"].boss:
			_fail("seed %d did not build the same world twice" % s)
		var graph: WorldGraph = world["graph"]
		rooms_seen += graph.rooms.size()
		var boss: Dictionary = graph.rooms[graph.boss]
		for pond in world["ponds"]:
			ponds_seen += 1
			lava_seen += 1 if pond["lava"] else 0
		# Gates: every gated passage has one, and with them all in place the locked areas cannot be reached but all the rest can.
		# A spell takes a gate away: it fills what the passage lacks (a bridge, the floor of the notch) or burns the thorns.
		if world["gates"].size() != graph.locks.size():
			_fail("seed %d: %d gates for %d locks" % [s, world["gates"].size(), graph.locks.size()])
		var barred: Dictionary = world["hazards"].duplicate()
		var opened: TileGrid = world["cells"].duplicate()
		var shut: TileGrid = world["cells"].duplicate()
		var here := {}
		for gate in world["gates"]:
			kinds[gate["kind"]] = kinds.get(gate["kind"], 0) + 1
			here[gate["kind"]] = here.get(gate["kind"], 0) + 1
		print("seed %d gates: %s" % [s, here])
		for gate in world["gates"]:
			if gate["kind"] in ["sentinel", "piranhas"]:
				print("   ", gate["kind"], gate["at"], gate.get("stands", ""), gate.get("pit", ""), gate["inward"])
		var far := 0.0
		for spawn in graph.spawns:
			var hops: Dictionary = graph._hops_from(spawn)
			var nearest := 99.0
			for lock in graph.locks:
				var link: Dictionary = graph.links[lock["link"]]
				nearest = minf(nearest, minf(hops.get(link["a"], 99.0), hops.get(link["b"], 99.0)))
			far = maxf(far, nearest)
		print("seed %d: from every starting place a gate is at most %.1f passages away" % [s, far])
		for gate in world["gates"]:
			for cell: Vector2i in gate["thorns"]:
				barred[cell] = true
			for cell: Vector2i in gate["blocks"]:
				if gate["kind"] == "ice" or gate["kind"] == "wall":
					shut.put(cell, ArenaGen.GROUND)  # ice and a wall are as solid as rock, so no one jumps over it
				else:
					barred[cell] = true
			for step: Dictionary in gate["solve"]:
				opened.fill_rect(step["rect"], step["with"])
		var locked_seen := WorldBuilder.reachable(shut, world["start"], world["size"].y, barred)
		var open_seen := WorldBuilder.reachable(opened, world["start"], world["size"].y, world["hazards"])
		world["opened"] = opened
		for lock in graph.locks:
			var leak := false
			for id in lock["rooms"]:
				leak = leak or locked_seen.has(world["markers"][id])
			if leak:
				_fail("seed %d: the %s of lock %d lets whoever walks in the locked area (passage %s)" % [s, lock["gate"], lock["id"], graph.links[lock["link"]]["pa"]])
		for room in graph.rooms:
			var reached := locked_seen.has(world["markers"][room["id"]])
			if room["lock"] >= 0 and reached:
				_fail("seed %d: room %d is in locked area %d but can be reached with the gates in place" % [s, room["id"], room["lock"]])
			if room["lock"] < 0 and not reached:
				_fail("seed %d: room %d is outside every lock but cannot be reached with the gates in place" % [s, room["id"]])
			if not open_seen.has(world["markers"][room["id"]]):
				_fail("seed %d: room %d cannot be reached even with every gate taken away" % [s, room["id"]])
		for lock in graph.locks:
			if lock["key"] < 0:
				_fail("seed %d: lock %d has no key" % [s, lock["id"]])
		_sprawl(s, world, graph, open_seen)
		if world["castle"] >= 0:  # the castle can be walked through, in both directions
			var row: int = WorldGraph.SURFACE_ROW - 1
			var west := Vector2i(world["castle"] - 2, row)
			var east := Vector2i(world["castle"] + WorldBuilder.CASTLE_WIDTH + 2, row)
			if not WorldBuilder.reachable(world["cells"], west, world["size"].y, world["hazards"]).has(east):
				_fail("seed %d: the castle cannot be walked through from the west" % s)
			if not WorldBuilder.reachable(world["cells"], east, world["size"].y, world["hazards"]).has(west):
				_fail("seed %d: the castle cannot be walked through from the east" % s)
		Pages.begin(s)
		var layout := Pages.plan(graph, RandomNumberGenerator.new())
		var page_rooms := {}
		for entry: Dictionary in layout["placed"]:
			page_rooms[entry["room"]] = true
		var first_hops := 99.0
		var mean := 0.0
		for spawn in graph.spawns:
			var from_here: Dictionary = graph._hops_from(spawn)
			var nearest_page := 99.0
			for room in page_rooms:
				nearest_page = minf(nearest_page, from_here.get(room, 99.0))
			first_hops = minf(first_hops, nearest_page)
			mean += nearest_page
		print("seed %d: %d rooms, %d with a page; nearest page from a spawn: %.0f passages (average %.1f); world %s tiles" % [s, graph.rooms.size(), page_rooms.size(), first_hops, mean / maxf(graph.spawns.size(), 1), str(world["size"])])
		var seen := {}
		for entry: Dictionary in layout["placed"]:
			var page: String = entry["page"]
			var room: Dictionary = graph.rooms[entry["room"]]
			if seen.has(page):
				_fail("seed %d: the page %s is laid twice" % [s, page])
			seen[page] = true
			if room["lock"] != -1 and not Pages.LOCKABLE.has(page):
				_fail("seed %d: the page %s, which may open a gate, lies in a locked area" % [s, page])
			if room["lock"] != -1 and graph.locks[room["lock"]]["boss"]:
				_fail("seed %d: the page %s lies in the dark wizard's area" % [s, page])
		for page in layout["stash"]:
			seen[page] = true
		for page in Pages.every():
			if not seen.has(page) and not Pages.known.has(page):
				_fail("seed %d: the page %s is nowhere" % [s, page])
		if boss["lock"] < 0:
			_fail("seed %d: the boss is not in a locked area" % s)
	# The check must be able to fail: with walls across the surface on both sides of the start, some room has to become unreachable.
	var broken := _make(1)
	broken["hazards"] = {}
	for r in range(0, WorldGraph.SURFACE_ROW):
		for dx in [-3, 3]:
			broken["cells"].put(Vector2i(broken["start"].x + dx, r), ArenaGen.GROUND)
	var cut := WorldBuilder.reachable(broken["cells"], broken["start"], broken["size"].y, broken["hazards"])
	var lost := 0
	for room in broken["graph"].rooms:
		if not cut.has(broken["markers"][room["id"]]):
			lost += 1
	if lost == 0:
		_fail("the reachability check passed a world with no way up")
	print("gates: ", kinds)
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


## The world is a sprawl, not a single path: many ways down, systems of halls joined by more than one route, and four starting
## places far apart, each with halls of its own around it and a way to every hall.
func _sprawl(s: int, world: Dictionary, graph: WorldGraph, seen: Dictionary) -> void:
	var mouths: Array = graph.rooms[0]["mouths"]
	if mouths.size() < 10:
		_fail("seed %d: only %d ways down from the surface" % [s, mouths.size()])
	for biome in world["surface"]["biomes"]:
		var inside := 0
		for x: int in mouths:
			inside += 1 if x >= biome["a"] and x <= biome["b"] else 0
		if inside < (0 if biome["name"] == "graveyard" else 1):
			_fail("seed %d: only %d ways down in the %s" % [s, inside, biome["name"]])
	var loops := graph.links.size() - (graph.rooms.size() - 1)
	if loops < 1:
		_fail("seed %d: only %d loops between halls" % [s, loops])
	if world["spawns"].size() != WorldGraph.PLAYERS:
		_fail("seed %d: %d starting places" % [s, world["spawns"].size()])
		return
	for k in world["spawns"].size():
		var spawn: Vector2i = world["spawns"][k]
		if not WorldBuilder.standing(world["cells"], spawn.x, spawn.y):
			_fail("seed %d: starting place %d is not on firm ground" % [s, k])
		for j in range(k + 1, world["spawns"].size()):
			if absi(world["spawns"][j].x - spawn.x) < 200:
				_fail("seed %d: starting places %d and %d are only %d columns apart" % [s, k, j, absi(world["spawns"][j].x - spawn.x)])
		var halls := 0
		for room in graph.rooms:
			halls += 1 if not room.has("surface") and absi(room["cx"] - spawn.x) < 260 else 0
		if halls < 5:
			_fail("seed %d: only %d halls within reach of starting place %d" % [s, halls, k])
		var from_here := WorldBuilder.reachable(world["opened"], spawn, world["size"].y, world["hazards"])
		for room in graph.rooms:
			if not from_here.has(world["markers"][room["id"]]):
				_fail("seed %d: room %d cannot be reached from starting place %d" % [s, room["id"], k])
				break


func _fail(text: String) -> void:
	_failures += 1
	print("FAIL  " + text)


## One pixel block per tile: rock dark, castle stone tan, and each room's marker coloured by its kind.
func _picture(world: Dictionary, dir: String) -> void:
	var scale := 1
	var size: Vector2i = world["size"]
	var image := Image.create(size.x * scale, size.y * scale, false, Image.FORMAT_RGB8)
	image.fill(Color("#15101c"))
	var grid: TileGrid = world["cells"]
	for r in size.y:
		for c in size.x:
			var value := grid.data[r * size.x + c]
			if value != 0:
				image.set_pixel(c, r, Color("#6a5a7a") if value == ArenaGen.GROUND + 1 else Color("#d0a050"))
	for pond in world["ponds"]:
		image.fill_rect(Rect2i(Vector2i(pond["a"], pond["surface"]) * scale, Vector2i(pond["b"] - pond["a"] + 1, pond["depth"]) * scale), Color.ORANGE_RED if pond["lava"] else Color.DODGER_BLUE)
	var graph: WorldGraph = world["graph"]
	var kinds := {"start": Color.LIME, "boss": Color.RED, "branch": Color.YELLOW, "area": Color.CYAN}
	for room in graph.rooms:
		var at: Vector2i = world["markers"][room["id"]]
		image.fill_rect(Rect2i((at - Vector2i(1, 6)) * scale, Vector2i(scale * 3, scale * 7)), kinds[room["kind"]])
		if room["lock"] >= 0:
			image.fill_rect(Rect2i((at - Vector2i(1, 10)) * scale, Vector2i(scale * 3, scale * 3)), Color.MAGENTA)  # in a locked area
		if room["key"] >= 0:
			image.fill_rect(Rect2i((at - Vector2i(1, 10)) * scale, Vector2i(scale * 3, scale * 3)), Color.WHITE)  # holds a key
	for spawn: Vector2i in world["spawns"]:
		image.fill_rect(Rect2i((spawn - Vector2i(2, 14)) * scale, Vector2i(scale * 5, scale * 15)), Color.WHITE)
	for gate in world["gates"]:
		for step: Dictionary in gate["solve"]:
			image.fill_rect(Rect2i(step["rect"].position * scale, step["rect"].size * scale), Color.MAGENTA)
		for cell: Vector2i in gate["thorns"]:
			image.fill_rect(Rect2i(cell * scale, Vector2i(scale, scale)), Color.GREEN)
		for cell: Vector2i in gate["blocks"]:
			image.fill_rect(Rect2i(cell * scale, Vector2i(scale, scale)), Color.GREEN)
	for biome in world["surface"]["biomes"]:
		image.fill_rect(Rect2i(biome["a"] * scale, 0, (biome["b"] - biome["a"]) * scale, 4), [Color.GRAY, Color.GREEN, Color.LIGHT_BLUE, Color.ORANGE, Color.DARK_RED][world["surface"]["biomes"].find(biome)])
	DirAccess.make_dir_recursive_absolute(dir)
	image.save_png(dir.path_join("world_%d.png" % picture_seed))
	print("saved the map of seed %d to %s" % [picture_seed, dir])

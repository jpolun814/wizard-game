class_name WorldGraph
extends RefCounted

## The shape of a world before any ground is made: the surface (see SurfaceGen), halls placed under it, and the passages
## between them. A hall is a cave chamber with a floor level, a width and a height: a cavern, now and then a great hall
## (wide and tall, an arena) or a small vault. Halls are joined two ways. A tunnel leaves the end of a hall and climbs or
## sinks a little to the hall beside it. A descent leaves the middle of a floor, or a ledge on the surface, on a steep
## ramp to a hall below it, or above it. So a hall can have many ways in and out, and the surface has a way down in
## every biome. Halls lie anywhere under the ground, mountains included.
## Some passages are gated: the halls beyond a gate are a locked area, with an elite or the boss in its widest hall and
## the key in a vault outside it. Everything here comes from the rng it is given, so one seed always gives one graph.

const FULL := Vector2i(1200, 380)  # the first world, in tiles
const MIN_ROOMS := 36
const MAX_ROOMS := 42
const ENTRANCE_SPACING := 40   # one way down for about this many columns of surface, at the least, in every biome
const SURFACE_APART := 34       # columns between two ways down from the surface
const CLUSTER_ROOMS := 8       # a way down is the start of a system of about this many halls
const PLAYERS := 4
const MIN_RUN := 22         # the least a tunnel runs between two halls, in columns
const MAX_RUN := 54
const SLOPE := 2.0          # columns a gentle tunnel needs for each row it climbs
const STEEP := 1.0          # and a steep one: 45 degrees, the most a walker can climb
const STEEP_CHANCE := 0.4
const EXTRA_DESCENTS := 30  # loops added as steep ramps from the middle of a floor down to a hall below it
const EXTRA_LINKS := 26     # loops added between halls that already sit near each other
const SURFACE_ROW := SurfaceGen.BASE_ROW  # the row where the plains start
const MOUTH_APART := 30     # columns between two descents from one floor
const COVER := 6            # rows of rock a hall keeps over its roof
const MAX_LOCKS := 14
const NEAR_LOCK := 5        # passages: a locked area is at least this near to where every player is set down
const CHASM_FLAT := 26      # level columns a lava chasm needs: its width and a landing on each side
const PIRANHA_FLAT := 38      # level columns the piranha pit needs
const SENTINEL_RUN := 24     # columns a passage needs for a statue to stand in it with a field of fire
const TRAP_MARGIN := 4      # columns kept clear at each end of a passage that holds a trap
const THORN_BUDGET := 28    # what each trap is made of, in columns of level walking (see _trap_room)
const GAS_BUDGET := 32
const DARK_BUDGET := 32
const ICE_FLAT := 6         # a plug of ice only needs a place to stand each side
const WALL_DEPTH := 22      # rows of rock a wall needs over the floor of a passage: the room it takes from the ceiling, and a roof
const GATES := ["chasm", "flood", "brambles", "wall", "ice", "dark", "gas", "piranhas", "sentinel"]  # what can bar a passage; each is beaten by any of several spells

## Each room: {"id", "cx": middle column, "cy": the row where its floor starts (first solid row at the middle), "hw": half its
## width, "air": its height at the middle, "role": cavern / great / vault, "kind": start / area / branch / boss,
## "depth": passages from the start, "zone": 0 to 2, how far along the run it is, "lock": the locked area it is in, or -1,
## "guard": "elite" or "boss" in the arena of a locked area, "key": the lock it holds the key to, or -1}. Each link:
## {"a", "b": room ids, "kind": "tunnel", "lock": the lock it is gated by, or -1, "slope": columns per row, "pa", "pb": the
## two mouths, as tiles, pa in room a and pb in room b, "inside_a" or "inside_b": true when that mouth is in the middle of
## a floor rather than at a hall's end}.
static var size := FULL  # the world to build, in tiles: the portal collapses into smaller ones
var rooms: Array[Dictionary] = []
var links: Array[Dictionary] = []
var locks: Array[Dictionary] = []  # {"id", "link", "rooms": [ids], "guard": room id, "key": room id, "boss": bool, "gate": what bars the passage}
var surface := {}
var start := 0
var boss := 0
var spawns: Array[Dictionary] = []  # where up to PLAYERS players are set down: {"x": the column on the surface, "room": the hall below it}
var _adjacent: Array = []  # per room: the rooms beside it, as Vector2i(room, passage)
var _reserved: Array[Dictionary] = []  # {"rect": Rect2i, "owners": [room ids]}: space that halls and tunnels have taken


## Tries again from scratch until a world has enough halls, a gate and a far boss; the best of a few tries if none does.
static func build(rng: RandomNumberGenerator) -> WorldGraph:
	var wanted_mouths := _scaled(8, 3)
	var wanted_locks := 2 if size.x >= 800 else 1
	var wanted_depth := 3 if size.x >= 800 else 2
	var best: WorldGraph = null
	var best_score := -1
	for attempt in 60:
		var graph := _grow(rng)
		var mouths: int = graph.rooms[0]["mouths"].size()
		var score := graph.rooms.size() + mouths * 3 + mini(graph.links.size() - graph.rooms.size(), 4) * 4 + (6 if graph.locks.size() >= wanted_locks else 0) + (4 if graph.rooms[graph.boss]["depth"] >= wanted_depth else 0) + (0 if graph._spawns_apart() else -40)
		if score > best_score:
			best = graph
			best_score = score
		if graph.rooms.size() >= _scaled(MIN_ROOMS, 8) and mouths >= wanted_mouths and graph._every_biome_has_a_way_down() and graph.locks.size() >= wanted_locks and graph.rooms[graph.boss]["depth"] >= wanted_depth and graph.spawns.size() == PLAYERS and graph._spawns_apart() and graph.links.size() - graph.rooms.size() >= 2:
			return graph
	return best


## A count for the full-size world, scaled down for a smaller one (never below a least).
static func _scaled(count: int, least: int) -> int:
	return maxi(least, count * size.x / FULL.x)


## A world with no caves: only the surface, with the players' places spread along it. The last world of a match, with nowhere to hide.
static func build_open(rng: RandomNumberGenerator) -> WorldGraph:
	var graph := WorldGraph.new()
	graph.surface = SurfaceGen.open(size.x, rng)
	graph._add_room({"cx": size.x / 2, "cy": SURFACE_ROW, "hw": size.x / 2 - 4, "air": SURFACE_ROW - 3, "surface": true,
			"tunnel_1": true, "tunnel_-1": true, "mouths": [], "role": "surface", "cluster": -1})
	graph._classify(rng)
	for k in PLAYERS:  # the middle is level, for the first to start on; the others are spread along the rest, away from it
		var column := roundi(size.x * (k + 0.5) / PLAYERS)
		graph.spawns.append({"x": column, "room": 0, "side": 0})
	graph.locks = []
	return graph


## True when each biome of the surface has at least one way down.
func _every_biome_has_a_way_down() -> bool:
	for biome in surface["biomes"]:
		if biome["name"] == "graveyard":
			continue  # the castle stands there
		var inside := 0
		for column in rooms[0]["mouths"]:
			if column >= biome["a"] and column <= biome["b"]:
				inside += 1
		if inside == 0:
			return false
	return true


## True when every two starting places are at least 140 columns apart.
func _spawns_apart() -> bool:
	for i in spawns.size():
		for j in range(i + 1, spawns.size()):
			if absi(spawns[i]["x"] - spawns[j]["x"]) < 140 * size.x / FULL.x:
				return false
	return true


static func _grow(rng: RandomNumberGenerator) -> WorldGraph:
	var graph := WorldGraph.new()
	graph.surface = SurfaceGen.build(size.x, rng)
	var count := rng.randi_range(_scaled(MIN_ROOMS, 8), _scaled(MAX_ROOMS, 10))
	graph._add_room({"cx": size.x / 2, "cy": SURFACE_ROW, "hw": size.x / 2 - 4, "air": SURFACE_ROW - 3, "surface": true,
			"tunnel_1": true, "tunnel_-1": true, "mouths": [], "role": "surface", "cluster": -1})
	# Ways down all along the surface, in every biome, each the start of a system of halls of its own.
	for biome in graph.surface["biomes"]:
		var wanted := maxi(2, (biome["b"] - biome["a"] + 1) / ENTRANCE_SPACING)
		for k in wanted:
			for attempt in 300:
				if graph._try_descent(graph.rooms[0], rng, rng.randi_range(biome["a"] + 16, biome["b"] - 16)):
					break
	var clusters: Array[int] = []
	for room in graph.rooms:
		if room["cluster"] >= 0:
			clusters.append(room["cluster"])
	var tries := 0
	while graph.rooms.size() < count and tries < 8000 and not clusters.is_empty():
		tries += 1
		var cluster: int = clusters[rng.randi() % clusters.size()]
		var members: Array[Dictionary] = []
		for room in graph.rooms:
			if room["cluster"] == cluster:
				members.append(room)
		if members.size() >= CLUSTER_ROOMS + 4:
			continue
		var from: Dictionary = members[rng.randi() % members.size()]
		if rng.randf() < 0.55:
			graph._try_descent(from, rng, -1)
		else:
			graph._try_tunnel(from, rng)
	graph._add_descent_loops(rng)
	graph._add_loops(rng)
	graph._classify(rng)
	graph._pick_spawns()
	graph._lock(rng)
	return graph


func neighbours(id: int) -> Array[int]:
	var out: Array[int] = []
	for link in links:
		if link["a"] == id:
			out.append(link["b"])
		elif link["b"] == id:
			out.append(link["a"])
	return out


func linked(a: int, b: int) -> bool:
	return neighbours(a).has(b)


## Where a tunnel leaves a hall: the middle of its side, at floor level.
static func exit_of(room: Dictionary, side: int) -> Vector2i:
	return Vector2i(room["cx"] + side * room["hw"], room["cy"])


## The size of a new hall: mostly caverns, now and then a great hall or a small vault.
static func _roll_hall(rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randf()
	if roll < 0.14:
		return {"hw": rng.randi_range(30, 42), "air": rng.randi_range(24, 34), "role": "great"}
	if roll < 0.32:
		return {"hw": rng.randi_range(8, 11), "air": rng.randi_range(12, 14), "role": "vault"}
	return {"hw": rng.randi_range(12, 26), "air": rng.randi_range(12, 22) if rng.randf() < 0.8 else rng.randi_range(26, 38), "role": "cavern"}


## A new hall to one side of another, with a tunnel between them. The new hall's floor can differ from the old one by as
## much as the tunnel can climb: a gentle tunnel climbs a row in two columns, a steep one a row in one.
func _try_tunnel(from: Dictionary, rng: RandomNumberGenerator) -> void:
	var side := 1 if rng.randf() < 0.5 else -1
	if from.has("tunnel_%d" % side):
		return  # a hall has one tunnel at each end: two would cut each other's floors near the mouth
	var run := rng.randi_range(MIN_RUN, MAX_RUN)
	var slope := STEEP if rng.randf() < STEEP_CHANCE else SLOPE
	var reach := int(run / slope) - 2
	var dy := rng.randi_range(-reach / 2, reach)  # a little more down than up, so the halls reach the depths
	var spec := _roll_hall(rng)
	spec.merge({"cx": from["cx"] + side * (from["hw"] + run + spec["hw"]), "cy": from["cy"] + dy, "mouths": []})
	if not _fits(spec):
		return
	var a := exit_of(from, side)
	var b := Vector2i(a.x + side * run, a.y + dy)
	if _join(from, spec, a, b, slope, {}):
		from["tunnel_%d" % side] = true
		rooms[rooms.size() - 1]["tunnel_%d" % -side] = true


## A new hall at the end of a steep ramp down from the middle of a floor, or from the surface at a column. The column is -1 to
## pick one inside the hall. The ramp starts in a short pit under a lid of rock, so the floor above carries on across it.
func _try_descent(from: Dictionary, rng: RandomNumberGenerator, column: int) -> bool:
	var on_surface := from.has("surface")
	var mouth_x := column
	if not on_surface:
		mouth_x = from["cx"] + rng.randi_range(-from["hw"] / 2, from["hw"] / 2)
	if on_surface and (mouth_x < 22 or mouth_x > size.x - 22 or not _clear_ground(mouth_x)):
		return false
	if not on_surface and from["hw"] < 12:
		return false  # a vault has no room for a ramp
	for other in from["mouths"]:
		if absi(other - mouth_x) < (SURFACE_APART if on_surface else MOUTH_APART):
			return false
	var row: int = surface["floor"][mouth_x] if on_surface else from["cy"]
	var side := 1 if rng.randf() < 0.5 else -1
	var run := rng.randi_range(MIN_RUN + 8, MAX_RUN)
	var dy := rng.randi_range(10, run - 2)
	var spec := _roll_hall(rng)
	if on_surface:
		spec = {"hw": rng.randi_range(10, 16), "air": rng.randi_range(12, 16), "role": "cavern"}  # a small hall first: the system grows from it
	var b := Vector2i(mouth_x + side * run, row + dy)
	spec.merge({"cx": b.x + side * spec["hw"], "cy": b.y, "mouths": [], "tunnel_%d" % -side: true})
	if not _fits(spec):
		return false
	var a := Vector2i(mouth_x, row)
	if not _under_surface(a, b, STEEP, on_surface):
		return false
	if _join(from, spec, a, b, STEEP, {"inside_a": true}):
		from["mouths"].append(mouth_x)
		return true
	return false


## Adds a hall and the tunnel from a mouth of an old hall to a mouth of the new one, unless the tunnel runs into something.
func _join(from: Dictionary, spec: Dictionary, a: Vector2i, b: Vector2i, slope: float, extra: Dictionary) -> bool:
	var tunnel := Rect2i(mini(a.x, b.x) + 4, mini(a.y, b.y) - 12, absi(b.x - a.x) - 8, absi(b.y - a.y) + 16)
	if _blocked(tunnel, [from["id"]]) or not _under_surface(a, b, slope, from.has("surface") or extra.has("inside_a")):
		return false
	var made := _add_room(spec)
	rooms[made]["cluster"] = from["cluster"] if from["cluster"] >= 0 else made
	_reserved.append({"rect": tunnel, "owners": [from["id"], made]})
	var link := {"a": from["id"], "b": made, "kind": "tunnel", "lock": -1, "slope": slope, "pa": a, "pb": b}
	link.merge(extra)
	links.append(link)
	return true


## True when a tunnel keeps rock over its head along its way, not counting the first columns at a mouth on the surface,
## which is a trench open to the sky.
func _under_surface(a: Vector2i, b: Vector2i, slope: float, open_start: bool) -> bool:
	var left := a if a.x < b.x else b
	var right := b if a.x < b.x else a
	var need := int(ceil(absf(float(right.y - left.y)) * slope))
	for k in range(right.x - left.x + 1):
		if open_start and (k < 12 if left == a else right.x - left.x - k < 12):
			continue
		var level := left.y + roundi((right.y - left.y) * clampf(float(k - 6) / maxf(need, 1.0), 0.0, 1.0))
		if level - 11 < surface["floor"][left.x + k] + 1:
			return false
	return true


## True when a mouth on the surface at a column has room to slope away from every other level stretch of ground: the start,
## the castle, the pools and the other mouths.
func _clear_ground(x: int) -> bool:
	var floor_row: PackedInt32Array = surface["floor"]
	var level := floor_row[x]
	var spots: Array = [[size.x / 2 - SurfaceGen.START_FLAT, size.x / 2 + SurfaceGen.START_FLAT, SurfaceGen.BASE_ROW],
			[surface["castle"] - 3, surface["castle"] + SurfaceGen.CASTLE_WIDTH + 3, SurfaceGen.BASE_ROW]]
	for pond in surface["ponds"]:
		spots.append([pond["a"] - SurfaceGen.POOL_PAD, pond["b"] + SurfaceGen.POOL_PAD, pond["surface"]])
	for other in rooms[0]["mouths"]:
		spots.append([other - 16, other + 16, floor_row[other]])
	for spot in spots:
		var distance := maxi(spot[0] - (x + 16), (x - 16) - spot[1])
		if distance < 0 or absi(spot[2] - level) + 1 > distance:
			return false
	return true


## True when a hall in this spot would stay under the ground and inside the world and not run into anything.
func _fits(spec: Dictionary) -> bool:
	var box := _hall_box(spec)
	if box.position.x < 3 or box.end.x > size.x - 3 or box.end.y > size.y - 3:
		return false
	var lowest := 0
	for c in range(box.position.x, box.end.x):
		lowest = maxi(lowest, surface["floor"][c])
	if box.position.y < lowest + COVER:
		return false
	return not _blocked(box, [])


static func _hall_box(spec: Dictionary) -> Rect2i:
	return Rect2i(spec["cx"] - spec["hw"] - 3, spec["cy"] - spec["air"] - 5, spec["hw"] * 2 + 7, spec["air"] + 5 + 10)


## True when a rectangle runs into taken space, ignoring the halls (and their links) it is meant to join.
func _blocked(rect: Rect2i, joining: Array) -> bool:
	for room in rooms:
		if room.has("surface"):
			continue
		if not joining.has(room["id"]) and _hall_box(room).intersects(rect):
			return true
	for taken in _reserved:
		var owners: Array = taken["owners"]
		var shared := false
		for id in joining:
			shared = shared or owners.has(id)
		if not shared and taken["rect"].intersects(rect):
			return true
	return false


func _add_room(spec: Dictionary) -> int:
	var id := rooms.size()
	var room := spec.duplicate()
	room.merge({"id": id, "kind": "area", "depth": 0, "zone": 0, "lock": -1, "guard": "", "key": -1, "role": "cavern", "mouths": [], "cluster": -1}, false)
	rooms.append(room)
	if not room.has("surface"):
		_reserved.append({"rect": _hall_box(room), "owners": [id]})
	return id


## Steep ramps from the middle of a floor down to a hall that already exists, to the free end of it that faces the ramp: more
## ways between the halls, and between the systems of them.
func _add_descent_loops(rng: RandomNumberGenerator) -> void:
	var options: Array = []
	for a in rooms:
		if a.has("surface") or a["hw"] < 12:
			continue
		for b in rooms:
			if b.has("surface") or b["id"] == a["id"] or b["cy"] - a["cy"] < 10 or linked(a["id"], b["id"]):
				continue
			var side := 1 if b["cx"] > a["cx"] else -1
			if b.has("tunnel_%d" % -side) or absi(b["cx"] - a["cx"]) > MAX_RUN + a["hw"] + b["hw"]:
				continue
			options.append([a["id"], b["id"], side, 0 if a["cluster"] != b["cluster"] else 1])
	for i in range(options.size() - 1, 0, -1):
		options.push_front(options.pop_at(rng.randi() % (i + 1)))
	options.sort_custom(func(x: Array, y: Array) -> bool: return x[3] < y[3])  # between systems first
	var made := 0
	for option in options:
		if made >= EXTRA_DESCENTS:
			break
		var a: Dictionary = rooms[option[0]]
		var b: Dictionary = rooms[option[1]]
		var side: int = option[2]
		if b.has("tunnel_%d" % -side) or linked(a["id"], b["id"]):
			continue
		var end := exit_of(b, -side)
		var dy: int = end.y - a["cy"]
		if dy + 2 > MAX_RUN:
			continue
		for attempt in 24:
			var mouth_x: int = a["cx"] + rng.randi_range(-a["hw"] / 2, a["hw"] / 2)
			var run: int = (end.x - mouth_x) * side
			if run < dy + 2 or run > MAX_RUN:
				continue
			var near := false
			for other in a["mouths"]:
				near = near or absi(other - mouth_x) < MOUTH_APART
			var from_mouth := Vector2i(mouth_x, a["cy"])
			var tunnel := Rect2i(mini(from_mouth.x, end.x) + 4, mini(from_mouth.y, end.y) - 12, absi(end.x - from_mouth.x) - 8, absi(end.y - from_mouth.y) + 16)
			if near or _blocked(tunnel, [a["id"], b["id"]]) or not _under_surface(from_mouth, end, STEEP, true):
				continue
			_reserved.append({"rect": tunnel, "owners": [a["id"], b["id"]]})
			links.append({"a": a["id"], "b": b["id"], "kind": "tunnel", "lock": -1, "slope": STEEP, "pa": from_mouth, "pb": end, "inside_a": true})
			a["mouths"].append(mouth_x)
			b["tunnel_%d" % -side] = true
			made += 1
			break


## Extra tunnels between halls that already sit side by side with a clear way between them, between systems of halls first, so
## the ways down are joined up underground and there is more than one way to get anywhere.
func _add_loops(rng: RandomNumberGenerator) -> void:
	var across: Array = []
	var within: Array = []
	for a in rooms:
		if a.has("surface") or a.has("tunnel_1"):
			continue
		for b in rooms:
			if b.has("surface") or b.has("tunnel_-1") or a["cx"] >= b["cx"]:
				continue
			var run: int = (b["cx"] - b["hw"]) - (a["cx"] + a["hw"])
			var dy: int = absi(b["cy"] - a["cy"])
			if run < 16 or run > MAX_RUN or dy * SLOPE > run - 4 or linked(a["id"], b["id"]):
				continue
			var tunnel := Rect2i(a["cx"] + a["hw"] + 4, mini(a["cy"], b["cy"]) - 12, run - 8, dy + 16)
			var pa := exit_of(a, 1)
			var pb := exit_of(b, -1)
			if not _blocked(tunnel, [a["id"], b["id"]]) and _under_surface(pa, pb, SLOPE, false):
				(across if a["cluster"] != b["cluster"] else within).append([a["id"], b["id"], tunnel])
	for list in [across, within]:
		for i in range(list.size() - 1, 0, -1):
			list.push_front(list.pop_at(rng.randi() % (i + 1)))
	var made := 0
	for option in across + within:
		if made >= EXTRA_LINKS:
			break
		if linked(option[0], option[1]) or _blocked(option[2], [option[0], option[1]]):
			continue
		if rooms[option[0]].has("tunnel_1") or rooms[option[1]].has("tunnel_-1"):
			continue
		_reserved.append({"rect": option[2], "owners": [option[0], option[1]]})
		links.append({"a": option[0], "b": option[1], "kind": "tunnel", "lock": -1, "slope": SLOPE,
				"pa": exit_of(rooms[option[0]], 1), "pb": exit_of(rooms[option[1]], -1)})
		rooms[option[0]]["tunnel_1"] = true
		rooms[option[1]]["tunnel_-1"] = true
		made += 1


## Where the players are set down: the ways down nearest to evenly spaced columns along the surface, one to a player.
func _pick_spawns() -> void:
	var mouths: Array = rooms[0]["mouths"].duplicate()
	for k in PLAYERS:
		if mouths.is_empty():
			break
		var wanted := size.x * (k + 0.5) / PLAYERS
		var best: int = mouths[0]
		for x: int in mouths:
			if absf(x - wanted) < absf(best - wanted):
				best = x
		mouths.erase(best)
		for link in links:
			if link["a"] == 0 and link["pa"].x == best:
				spawns.append({"x": best, "room": link["b"], "side": signi(link["pb"].x - link["pa"].x)})
	while spawns.size() < PLAYERS and size.x < FULL.x:  # a small world has too few ways down: the rest start on open ground, as far from the others as it goes
		var column := _open_ground_far_from_spawns()
		if column < 0:
			break
		spawns.append({"x": column, "room": 0, "side": 0})


## The column of open surface (clear of the pools, the castle and the ways down) farthest from every starting place so far, or -1.
func _open_ground_far_from_spawns() -> int:
	var best := -1
	var best_gap := -1
	for column in range(SurfaceGen.MARGIN + 20, size.x - SurfaceGen.MARGIN - 20, 4):
		var clear: bool = column < surface["castle"] - 8 or column > surface["castle"] + SurfaceGen.CASTLE_WIDTH + 8
		for pond: Dictionary in surface["ponds"]:
			clear = clear and (column < pond["a"] - 6 or column > pond["b"] + 6)
		for mouth: int in rooms[0]["mouths"]:
			clear = clear and absi(column - mouth) > 12
		if not clear:
			continue
		var gap := 1 << 20
		for spawn in spawns:
			gap = mini(gap, absi(column - spawn["x"]))
		if gap > best_gap:
			best_gap = gap
			best = column
	return best


## Works out how many passages each room is from the start, and marks the start, the dead ends (branches) and the farthest
## room, which is the boss's until a locked area claims it.
func _classify(rng: RandomNumberGenerator) -> void:
	start = 0
	var depth := {0: 0}
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		for next in neighbours(at):
			if not depth.has(next):
				depth[next] = depth[at] + 1
				queue.append(next)
	var farthest := 0
	for id in depth:
		farthest = maxi(farthest, depth[id])
	var far: Array[int] = []
	for id in depth:
		if depth[id] == farthest:
			far.append(id)
	boss = far[rng.randi() % far.size()]
	for room in rooms:
		room["depth"] = depth.get(room["id"], 0)
		room["zone"] = mini(2, room["depth"] * 3 / (farthest + 1))
		if neighbours(room["id"]).size() == 1:
			room["kind"] = "branch"
	rooms[start]["kind"] = "start"
	rooms[boss]["kind"] = "boss"


## The rooms a passage cuts off from the start: those that cannot be reached without it.
func _cut_off(link_index: int) -> Array[int]:
	var seen := {start: true}
	var queue: Array[int] = [start]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		for step: Vector2i in _adjacent[at]:  # x: the room beside, y: the passage to it
			if step.y != link_index and not seen.has(step.x):
				seen[step.x] = true
				queue.append(step.x)
	var out: Array[int] = []
	for room in rooms:
		if not seen.has(room["id"]):
			out.append(room["id"])
	return out


## How much trap a passage has room for, in columns of level walking, for someone going in to the locked area. A trap costs a
## walker by the time they spend in it. Downhill they are not slowed, so a column of it counts one; uphill they are, by the
## slope's own length, so it counts more and less of it fits. Any ground will do, not only a level stretch.
func _trap_room(link_index: int, behind: Array) -> float:
	var link: Dictionary = links[link_index]
	var inside_b: bool = behind.has(link["b"])
	var going_down: bool = (link["pb"].y > link["pa"].y) == inside_b
	var run := absi(link["pb"].x - link["pa"].x)
	var need := ceili(absi(link["pb"].y - link["pa"].y) * link["slope"])
	var per_column: float = 1.0 / link["slope"]
	var weight: float = 1.0 if going_down else sqrt(1.0 + per_column * per_column)
	return float(run - need) + need * weight - TRAP_MARGIN * 2.0


## What a passage has room for: a lava chasm and a thorn field need a long level stretch, and a wall needs the rock over the
## middle of the passage deep enough to cut the room for it, so that it does not break out to the surface.
func _gate_fits(link_index: int, behind: Array) -> Array[String]:
	var link: Dictionary = links[link_index]
	var run := absi(link["pb"].x - link["pa"].x)
	var flat := run - ceili(absi(link["pb"].y - link["pa"].y) * link["slope"])
	var fits: Array[String] = []
	var deep := true
	for t in [0.3, 0.5, 0.7]:
		var x := roundi(lerpf(link["pa"].x, link["pb"].x, t))
		var y := roundi(lerpf(link["pa"].y, link["pb"].y, t))
		deep = deep and y - surface["floor"][x] >= WALL_DEPTH
	if deep:
		fits.append("wall")
	if run >= SENTINEL_RUN:
		fits.append("sentinel")
	if flat >= ICE_FLAT:
		fits.append("ice")
	if flat >= CHASM_FLAT:
		fits.append("chasm")
		fits.append("flood")
	if flat >= PIRANHA_FLAT:
		fits.append("piranhas")
	var room := _trap_room(link_index, behind)
	if room >= THORN_BUDGET:
		fits.append("brambles")
	if room >= DARK_BUDGET:
		fits.append("dark")
	if room >= GAS_BUDGET:
		fits.append("gas")
	return fits


## True when a locked area is either apart from every one chosen already, or inside one of them, or has one inside it.
func _nests(bridge: Dictionary, chosen: Array) -> bool:
	for taken in chosen:
		var shared := 0
		for id in bridge["rooms"]:
			shared += 1 if taken["rooms"].has(id) else 0
		if shared != 0 and shared != bridge["rooms"].size() and shared != taken["rooms"].size():
			return false
	return true


## How far each hall is, in passages, from where a player is set down: through the halls below, or along the surface to
## another way down first (40 columns of walking count as a passage). The surface itself is not a hall to go through.
func _hops_from(spawn: Dictionary) -> Dictionary:
	var cost := {}
	for link in links:
		if link["a"] == 0:
			var walk := absf(link["pa"].x - spawn["x"]) / 40.0
			cost[link["b"]] = minf(cost.get(link["b"], 999.0), walk + 1.0)
	cost[spawn["room"]] = 0.0
	var changed := true
	while changed:
		changed = false
		for link in links:
			if link["a"] == 0:
				continue
			for pair in [[link["a"], link["b"]], [link["b"], link["a"]]]:
				if cost.has(pair[0]) and cost[pair[0]] + 1.0 < cost.get(pair[1], 999.0):
					cost[pair[1]] = cost[pair[0]] + 1.0
					changed = true
	return cost


## Gates a few passages that have halls only behind them. The widest hall of each locked area holds its guard (an elite, or
## the boss for the biggest one), and a key lies in a vault or a dead end outside every locked area.
func _lock(rng: RandomNumberGenerator) -> void:
	_adjacent = []
	for room in rooms:
		_adjacent.append([])
	for k in links.size():
		_adjacent[links[k]["a"]].append(Vector2i(links[k]["b"], k))
		_adjacent[links[k]["b"]].append(Vector2i(links[k]["a"], k))
	var bridges: Array = []
	var small: Array = []  # one or two halls behind a gate: only used to put a gate near a starting place
	for k in links.size():
		if links[k]["a"] == 0:
			continue  # a way down from the surface is not gated: whoever is dropped there must be able to go in
		var behind := _cut_off(k)
		if behind.size() >= 1 and behind.size() <= rooms.size() * 40 / 100 and not _gate_fits(k, behind).is_empty():
			if behind.size() >= 3:
				bridges.append({"link": k, "rooms": behind})
			else:
				small.append({"link": k, "rooms": behind})
	bridges.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["rooms"].size() > y["rooms"].size())
	var chosen: Array = []
	for bridge in bridges:
		if chosen.size() >= MAX_LOCKS:
			break
		if _nests(bridge, chosen):
			chosen.append(bridge)
	# Wherever the players are set down there is a locked area not far off, so the first one is found in a few minutes.
	for spawn in spawns:
		var hops := _hops_from(spawn)
		var best := {}
		var best_hops := 99.0
		var covered := false
		for bridge in bridges + small:
			var link: Dictionary = links[bridge["link"]]
			var near := mini(hops.get(link["a"], 99.0), hops.get(link["b"], 99.0))
			if chosen.has(bridge):
				covered = covered or near <= NEAR_LOCK
			elif near < best_hops and _nests(bridge, chosen):
				best = bridge
				best_hops = near
		if not covered and not best.is_empty():
			chosen.append(best)
	chosen.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["rooms"].size() > y["rooms"].size())
	for bridge in chosen:
		locks.append({"id": locks.size(), "link": bridge["link"], "rooms": bridge["rooms"], "guard": -1, "key": -1, "boss": locks.is_empty()})
	var used := {}
	for lock in locks:
		links[lock["link"]]["lock"] = lock["id"]
		var inner: Dictionary = links[lock["link"]]
		var inside_b: bool = lock["rooms"].has(inner["b"])
		inner["inward"] = signi((inner["pb"].x - inner["pa"].x) * (1 if inside_b else -1))  # which way along the passage leads into the locked area
		# What bars the way: the kind used least so far among those the passage has room for, so a world has a mix of them.
		var link: Dictionary = links[lock["link"]]
		var fits := _gate_fits(lock["link"], lock["rooms"])
		var least := 99
		for kind in fits:
			least = mini(least, used.get(kind, 0))
		var choice: Array[String] = []
		for kind in fits:
			if used.get(kind, 0) == least:
				choice.append(kind)
		lock["gate"] = choice[rng.randi() % choice.size()]
		used[lock["gate"]] = used.get(lock["gate"], 0) + 1
	# Smaller (inner) areas are marked last, so a room belongs to the innermost lock around it.
	for lock in locks:
		for id in lock["rooms"]:
			rooms[id]["lock"] = lock["id"]
	for lock in locks:
		var widest := -1
		for own_only in [true, false]:  # the widest hall of the area itself, or of the whole of it when an inner area takes every hall
			for id in lock["rooms"]:
				if own_only and rooms[id]["lock"] != lock["id"]:
					continue
				if widest < 0 or rooms[id]["hw"] > rooms[widest]["hw"] or (rooms[id]["hw"] == rooms[widest]["hw"] and rooms[id]["depth"] > rooms[widest]["depth"]):
					widest = id
			if widest >= 0:
				break
		lock["guard"] = widest
		rooms[widest]["guard"] = "boss" if lock["boss"] else "elite"
		if lock["boss"]:
			rooms[boss]["kind"] = "branch" if neighbours(boss).size() == 1 else "area"
			boss = widest
			rooms[boss]["kind"] = "boss"
	# Keys: dead ends and vaults outside every locked area, each a long way from its gate.
	var taken_keys := {}
	for lock in locks:
		var best := -1
		for strict in [true, false]:  # when few rooms lie outside the locked areas, a room may hold two keys
			for room in rooms:
				if room["lock"] != -1 or room.has("surface") or (strict and (room["id"] == start or taken_keys.has(room["id"]))):
					continue
				if best < 0 or _key_score(room, lock) > _key_score(rooms[best], lock):
					best = room["id"]
			if best >= 0:
				break
		if best >= 0:
			lock["key"] = best
			rooms[best]["key"] = lock["id"]
			taken_keys[best] = true


func _key_score(room: Dictionary, lock: Dictionary) -> float:
	var gate_room: Dictionary = rooms[links[lock["link"]]["a"]]
	return (2.0 if room["kind"] == "branch" else 0.0) + (1.0 if room["role"] == "vault" else 0.0) + minf(absf(room["cx"] - gate_room["cx"]), 200.0) / 100.0

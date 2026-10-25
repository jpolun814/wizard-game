class_name WorldGraph
extends RefCounted

## The shape of a world before any ground is made: halls placed anywhere in a big space, and the passages between them.
## A hall is a cave chamber with a floor level, a width and a height. Two halls are joined by a tunnel (they sit side by
## side, and the tunnel climbs or sinks between their floors on a slope a walker can manage) or by a shaft (one hall sits
## under the other and they share a few columns). The world grows outward from the start hall in every direction. The boss
## hall is the one farthest from the start by passages. Every link has a gate slot, left empty until gates exist.
## Everything here comes from the rng it is given, so one seed always gives one graph.

const SIZE := Vector2i(360, 170)  # the world, in tiles
const MIN_ROOMS := 9
const MAX_ROOMS := 12
const MIN_RUN := 30         # the least a tunnel runs between two halls, in columns
const MAX_RUN := 70
const SLOPE := 2.0          # columns a gentle tunnel needs for each row it climbs
const STEEP := 1.0          # and a steep one: 45 degrees, the most a walker can climb
const STEEP_CHANCE := 0.4
const EXTRA_LINKS := 3      # loops added between halls that already sit near each other
const SURFACE_ROW := 40     # the row where the ground above the caves starts, on average

## Each room: {"id", "cx": middle column, "cy": the row where its floor starts (first solid row at the middle), "hw": half its
## width, "air": its height at the middle, "kind": start / area / branch / boss, "depth": passages from the start, "zone": 0 to 2,
## how far along the run it is}. Each link: {"a", "b": room ids, "kind": "tunnel", "gate": "", "slope": columns per row,
## "pa", "pb": the two mouths, as tiles, pa in room a and pb in room b}.
var rooms: Array[Dictionary] = []
var links: Array[Dictionary] = []
var start := 0
var boss := 0
var _reserved: Array[Dictionary] = []  # {"rect": Rect2i, "owners": [room ids]}: space that halls and tunnels have taken


## Tries again from scratch when the boss would sit too close to the start.
static func build(rng: RandomNumberGenerator) -> WorldGraph:
	var graph := _grow(rng)
	for attempt in 20:
		if graph.rooms[graph.boss]["depth"] >= 3:
			break
		graph = _grow(rng)
	return graph


static func _grow(rng: RandomNumberGenerator) -> WorldGraph:
	var graph := WorldGraph.new()
	var count := rng.randi_range(MIN_ROOMS, MAX_ROOMS)
	# The first room is the surface: open to the sky, the width of the world. Caves lie under it, reached by steep ramps.
	graph._add_room({"cx": SIZE.x / 2, "cy": SURFACE_ROW, "hw": SIZE.x / 2 - 4, "air": SURFACE_ROW - 3, "surface": true, "tunnel_1": true, "tunnel_-1": true})
	for side in [1, -1]:
		for attempt in 40:
			if graph._try_ramp(graph.rooms[0], rng, side):
				break
	var tries := 0
	while graph.rooms.size() < count and tries < 6000:
		tries += 1
		var from: Dictionary = graph.rooms[rng.randi() % graph.rooms.size()]
		graph._try_tunnel(from, rng)
	graph._add_loops(rng)
	graph._classify(rng)
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


## A new hall to one side of another, with a tunnel between them. The new hall's floor can differ from the old one by as
## much as the tunnel can climb: a gentle tunnel climbs a row in two columns, a steep one a row in one.
func _try_tunnel(from: Dictionary, rng: RandomNumberGenerator) -> void:
	var side := 1 if rng.randf() < 0.5 else -1
	if from.has("tunnel_%d" % side):
		return  # a hall has one tunnel on each side: two would cut each other's floors near the mouth
	var run := rng.randi_range(MIN_RUN, MAX_RUN)
	var slope := STEEP if rng.randf() < STEEP_CHANCE else SLOPE
	var reach := int(run / slope) - 2
	var dy := rng.randi_range(-reach, reach)
	var hw := rng.randi_range(12, 26)
	var air := rng.randi_range(12, 22) if rng.randf() < 0.8 else rng.randi_range(26, 40)  # now and then a tall cavern
	var spec := {"cx": from["cx"] + side * (from["hw"] + run + hw), "cy": from["cy"] + dy, "hw": hw, "air": air}
	if not _fits(spec):
		return
	var a := exit_of(from, side)
	var b := Vector2i(a.x + side * run, a.y + dy)
	if _join(from, spec, a, b, slope):
		from["tunnel_%d" % side] = true
		rooms[rooms.size() - 1]["tunnel_%d" % -side] = true


## A new hall far under the surface, with a steep tunnel from one end of the surface down to the hall's near side.
func _try_ramp(surface: Dictionary, rng: RandomNumberGenerator, side: int) -> bool:
	var run := rng.randi_range(40, MAX_RUN)
	var hw := rng.randi_range(14, 24)
	var air := rng.randi_range(12, 22)
	var dy := rng.randi_range(air + 16, maxi(air + 16, run - 2))
	if dy > run - 2:
		return false
	var mouth: int = surface["cx"] - side * surface["hw"]  # at an end of the surface: a trench in the middle would cut it in two
	var spec := {"cx": mouth + side * (run + hw), "cy": surface["cy"] + dy, "hw": hw, "air": air}
	if not _fits(spec):
		return false
	var a := Vector2i(mouth, surface["cy"])
	var b := Vector2i(mouth + side * run, a.y + dy)
	if _join(surface, spec, a, b, STEEP):
		rooms[rooms.size() - 1]["tunnel_%d" % -side] = true
		return true
	return false


## Adds a hall and the tunnel from a mouth of an old hall to a mouth of the new one, unless the tunnel runs into something.
func _join(from: Dictionary, spec: Dictionary, a: Vector2i, b: Vector2i, slope: float) -> bool:
	var tunnel := Rect2i(mini(a.x, b.x) + 4, mini(a.y, b.y) - 12, absi(b.x - a.x) - 8, absi(b.y - a.y) + 16)
	if _blocked(tunnel, [from["id"]]):
		return false
	var made := _add_room(spec)
	_reserved.append({"rect": tunnel, "owners": [from["id"], made]})
	links.append({"a": from["id"], "b": made, "kind": "tunnel", "gate": "", "slope": slope, "pa": a, "pb": b})
	return true


## True when a hall in this spot would stay inside the world and not run into anything.
func _fits(spec: Dictionary) -> bool:
	var box := _hall_box(spec)
	if box.position.x < 3 or box.position.y < 3 or box.end.x > SIZE.x - 3 or box.end.y > SIZE.y - 3:
		return false
	return not _blocked(box, [])


static func _hall_box(spec: Dictionary) -> Rect2i:
	return Rect2i(spec["cx"] - spec["hw"] - 3, spec["cy"] - spec["air"] - 5, spec["hw"] * 2 + 7, spec["air"] + 5 + 10)


## True when a rectangle runs into taken space, ignoring the halls (and their links) it is meant to join.
func _blocked(rect: Rect2i, joining: Array) -> bool:
	for room in rooms:
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
	room.merge({"id": id, "kind": "area", "depth": 0, "zone": 0}, true)
	rooms.append(room)
	_reserved.append({"rect": _hall_box(room), "owners": [id]})
	return id


## A few extra tunnels between halls that already sit side by side with a clear way between them.
func _add_loops(rng: RandomNumberGenerator) -> void:
	var options: Array = []
	for a in rooms:
		for b in rooms:
			if a["cx"] >= b["cx"] or linked(a["id"], b["id"]) or a.has("tunnel_1") or b.has("tunnel_-1"):
				continue
			var run: int = (b["cx"] - b["hw"]) - (a["cx"] + a["hw"])
			var dy: int = absi(b["cy"] - a["cy"])
			if run < 16 or run > MAX_RUN or dy * SLOPE > run - 4:
				continue
			var tunnel := Rect2i(a["cx"] + a["hw"] + 4, mini(a["cy"], b["cy"]) - 12, run - 8, dy + 16)
			if not _blocked(tunnel, [a["id"], b["id"]]):
				options.append([a["id"], b["id"], tunnel])
	for i in mini(EXTRA_LINKS, options.size()):
		var pick := rng.randi() % options.size()
		var option: Array = options[pick]
		options.remove_at(pick)
		if linked(option[0], option[1]) or _blocked(option[2], [option[0], option[1]]):
			continue
		if rooms[option[0]].has("tunnel_1") or rooms[option[1]].has("tunnel_-1"):
			continue
		_reserved.append({"rect": option[2], "owners": [option[0], option[1]]})
		links.append({"a": option[0], "b": option[1], "kind": "tunnel", "gate": "", "slope": SLOPE,
				"pa": exit_of(rooms[option[0]], 1), "pb": exit_of(rooms[option[1]], -1)})
		rooms[option[0]]["tunnel_1"] = true
		rooms[option[1]]["tunnel_-1"] = true


## Works out how many passages each room is from the start, and marks the start, the boss (the farthest room) and the dead
## ends (branches, where pages will go).
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
		room["depth"] = depth[room["id"]]
		room["zone"] = mini(2, room["depth"] * 3 / (farthest + 1))
		if neighbours(room["id"]).size() == 1:
			room["kind"] = "branch"
	rooms[start]["kind"] = "start"
	rooms[boss]["kind"] = "boss"

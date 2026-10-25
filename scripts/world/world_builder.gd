class_name WorldBuilder
extends RefCounted

## Turns a WorldGraph into tiles. The whole world starts as solid rock and the passages are cut out of it.
##
## A hall is a cave chamber: a domed ceiling over a floor that rolls in hills and valleys, with now and then a plateau, a
## basin holding a lake, a pool of lava or nothing, and rock formations to climb. The first hall is the surface: open sky over
## rolling ground, with a ruined castle on it. A tunnel joins two halls on a slope a walker can climb (at most 45 degrees),
## with wiggles and wider chambers along the way; steep ones lead down from the surface. There is nothing floating: everything
## stands on the ground or hangs from rock.
## The tiles are blocky, but the terrain turns their edges into smooth slopes (see Terrain), and a flood fill (see
## `reachable`) confirms every hall can be reached on foot. Nothing here uses randomness except the rng it is given.

const FORMATION_STEP := 2   # rows between the steps of a rock formation, so a jump from a slope still reaches
const CASTLE_HEIGHT := 26  # rows the towers stand above the ground
const CASTLE_WALL := 14  # rows the wall over the hall stands above the ground
const CASTLE_GATE := 16  # columns the gatehouse takes, with the gate through its foot
const CASTLE_GATE_HEIGHT := 7  # rows of air in the gate
const CASTLE_STAIR := 47  # the column where the stair inside the east tower starts, and the east tower with it
const CASTLE_HALL_HEIGHT := 9  # rows of air in the hall
const CASTLE_WIDTH := 100  # columns the ruined castle takes on the surface
const EXIT_FLAT := 10       # columns of flat floor inside a hall at a tunnel mouth
const PASSAGE_HEIGHT := 6   # rows of air in a tunnel, at the least
const BASIN_CHANCE := 0.5
const MIN_AIR := 9          # rows of air kept above the floor in the body of a hall

## Standing needs this many clear rows (the wizard is about 2.4 tiles tall).
const HEADROOM := 3
const JUMP_ROWS := 3
const JUMP_COLS := 4


## Returns {"cells": {Vector2i: material}, "size": Vector2i in tiles, "markers": {room id: Vector2i tile to stand on},
## "start": Vector2i, "ponds": [{"a", "b": first and last column, "surface": row, "depth": rows, "lava": bool}],
## "hazards": {Vector2i: true} for tiles inside lava, "shafts": [{"upper", "lower", "x", "width", "style", "platforms"}]}.
static func build(graph: WorldGraph, rng: RandomNumberGenerator) -> Dictionary:
	var size := WorldGraph.SIZE
	var cells := {}
	for c in size.x:
		for r in size.y:
			cells[Vector2i(c, r)] = ArenaGen.GROUND
	var plans := {}
	for room in graph.rooms:
		plans[room["id"]] = {"room": room, "pins": [], "shafts": [], "left": false, "right": false}
	var tunnels := []
	for link in graph.links:
		tunnels.append({"from": link["pa"], "to": link["pb"], "slope": link["slope"], "surface_x": link["pa"].x if graph.rooms[link["a"]].has("surface") else (link["pb"].x if graph.rooms[link["b"]].has("surface") else -1)})
		for end in [[link["a"], link["pa"]], [link["b"], link["pb"]]]:
			var room: Dictionary = graph.rooms[end[0]]
			var mouth: Vector2i = end[1]
			if room.has("surface"):
				plans[room["id"]]["pins"].append(Vector2i(mouth.x - EXIT_FLAT, mouth.x + EXIT_FLAT))  # a trench into the ground
			elif mouth.x > room["cx"]:
				plans[room["id"]]["right"] = true
				plans[room["id"]]["pins"].append(Vector2i(mouth.x - EXIT_FLAT, mouth.x))
			else:
				plans[room["id"]]["left"] = true
				plans[room["id"]]["pins"].append(Vector2i(mouth.x, mouth.x + EXIT_FLAT))
	var ponds := []
	var hazards := {}
	var profiles := {}
	var castle_x := _castle_site(graph.rooms[0], plans[0]["pins"], rng)
	if castle_x >= 0:
		plans[0]["pins"].append(Vector2i(castle_x - 3, castle_x + CASTLE_WIDTH + 3))
	plans[0]["pins"].append(Vector2i(graph.rooms[0]["cx"] - 8, graph.rooms[0]["cx"] + 8))  # level ground to start on
	for room in graph.rooms:
		profiles[room["id"]] = _profile(plans[room["id"]], rng)
	for room in graph.rooms:
		_carve_hall(cells, profiles[room["id"]])
		for pond in profiles[room["id"]]["ponds"]:
			ponds.append(pond)
			if pond["lava"]:
				_stepping_stones(cells, pond)
				for c in range(pond["a"], pond["b"] + 1):
					for r in range(pond["surface"], pond["surface"] + pond["depth"] + 1):
						hazards[Vector2i(c, r)] = true
	for tunnel in tunnels:
		_carve_tunnel(cells, tunnel["from"], tunnel["to"], tunnel["slope"], tunnel["surface_x"], rng)
	var markers := {}
	for room in graph.rooms:
		markers[room["id"]] = _marker(profiles[room["id"]], plans[room["id"]])
		if not room.has("surface"):
			plans[room["id"]]["pins"].append(Vector2i(markers[room["id"]].x - 3, markers[room["id"]].x + 3))  # keep the marker clear
			_formations(cells, profiles[room["id"]], plans[room["id"]], rng)
	var hall: Array = []
	if castle_x >= 0:
		hall = _castle(cells, graph.rooms[0]["cy"], castle_x)
	return {"cells": cells, "size": size, "markers": markers, "start": markers[graph.start], "ponds": ponds,
			"hazards": hazards, "castle": castle_x, "hall": hall, "profiles": profiles, "sky": {"xl": profiles[0]["xl"], "floor": profiles[0]["floor"]}}


## A hall's floor and ceiling: a first solid row for each column from its left end to its right, and the basins in it.
static func _profile(plan: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var room: Dictionary = plan["room"]
	var cx: int = room["cx"]
	var hw: int = room["hw"]
	var cy: int = room["cy"]
	var xl := cx - hw
	var n := hw * 2 + 1
	var pinned := PackedByteArray()
	pinned.resize(n)
	for pin in plan["pins"]:
		for c in range(maxi(pin.x, xl), mini(pin.y, xl + n - 1) + 1):
			pinned[c - xl] = 1
	var floor_row := PackedInt32Array()
	floor_row.resize(n)
	floor_row.fill(cy)
	var ponds := []
	# The dome over the hall: how much air there is at the middle of each column before the floor rises into it.
	var dome := PackedFloat32Array()
	dome.resize(n)
	for i in n:
		var t := absf(float(i - hw)) / hw
		dome[i] = room["air"] * sqrt(maxf(0.0, 1.0 - t * t))
		if room.has("surface"):
			dome[i] = room["air"]  # open sky: no dome
		elif (plan["right"] and i > hw and t > 0.7) or (plan["left"] and i < hw and t > 0.7):
			dome[i] = maxf(dome[i], PASSAGE_HEIGHT + 0.5)  # the dome stays open where a tunnel leaves
	# One basin, now and then: a lake, lava, or a dry pit. It needs flat ground round it, so it is kept off the pins.
	if room["kind"] != "start" and rng.randf() < BASIN_CHANCE:
		var depth := rng.randi_range(3, 5)
		var bottom := rng.randi_range(2, 7)
		var width := bottom + depth * 2
		for attempt in 12:
			if xl + 8 > xl + n - width - 8:
				break
			var a := rng.randi_range(xl + 8, xl + n - width - 8)
			if _clear_of(pinned, xl, a - 4, a + width + 3):
				var zone: int = room["zone"]
				var roll := rng.randf()
				var water: float = [0.55, 0.35, 0.15][zone]
				var lava: float = [0.0, 0.35, 0.55][zone]
				var kind := "water" if roll < water else ("lava" if roll < water + lava else "pit")
				for c in range(a, a + width):
					floor_row[c - xl] = cy + mini(mini(c - a + 1, a + width - c), depth)
					pinned[c - xl] = 2
				if kind != "pit":
					ponds.append({"a": a, "b": a + width - 1, "surface": cy, "depth": depth, "lava": kind == "lava"})
				break
	# Rolling ground: hills and valleys that fade to flat near anything that needs level floor.
	var near := _distance_to_pinned(pinned)
	var amp1 := rng.randf_range(2.0, 6.0)
	var amp2 := rng.randf_range(0.5, 2.0)
	var period1 := rng.randf_range(26.0, 52.0)
	var period2 := rng.randf_range(11.0, 20.0)
	var phase1 := rng.randf() * TAU
	var phase2 := rng.randf() * TAU
	for i in n:
		if pinned[i] == 0:
			var fade := clampf(near[i] / 7.0, 0.0, 1.0)
			var wave := amp1 * sin(TAU * i / period1 + phase1) + amp2 * sin(TAU * i / period2 + phase2)
			floor_row[i] = cy + roundi(wave * fade)
	# A mesa now and then: a slope up to a flat top and down again, in the middle where the dome is high.
	if rng.randf() < 0.4 and not room.has("surface"):
		var top_width := rng.randi_range(4, 10)
		var rise := rng.randi_range(4, 8)
		var length := top_width + rise * 4
		var first := rng.randi_range(hw / 2, maxi(hw / 2, n - hw / 2 - length))
		var free := first >= 2 and first + length < n - 2
		for i in range(first - 2, first + length + 2):
			free = free and i >= 0 and i < n and pinned[i] == 0
		if free:
			var worst := 999.0
			for k in length:
				worst = minf(worst, dome[first + k])
			rise = mini(rise, int(worst) - MIN_AIR - 2)
			if rise >= 3:
				for k in length:
					var up := mini(rise, mini(k + 1, length - k) / 2)
					floor_row[first + k] = mini(floor_row[first + k], cy - up)
					pinned[first + k] = 3
	# Hills and mesas stay under the dome: where the dome is low the floor stays down.
	for i in n:
		floor_row[i] = maxi(floor_row[i], cy - maxi(0, int(dome[i]) - MIN_AIR - 1))
	_relax(floor_row, pinned)
	# The ceiling: a dome over the floor, with bulges, closed at a side that has no tunnel.
	var ceiling := PackedInt32Array()
	ceiling.resize(n)
	var bulges := []
	for i in rng.randi_range(2, 4):
		bulges.append([rng.randi_range(6, n - 7), rng.randi_range(2, 5), rng.randi_range(3, 7)])
	for i in n:
		var t := absf(float(i - hw)) / hw
		var height: float = dome[i]
		var lowest := 0.0  # the deepest bulge here; bulges do not add up, so none ever closes the hall
		for bulge in bulges:
			var off := absi(i - bulge[0])
			if off < bulge[2] and t < 0.6:  # never near the ends, where a tunnel may leave
				lowest = maxf(lowest, bulge[1] * (1.0 - float(off) / bulge[2]))
		height -= lowest
		var top := cy - roundi(height)
		var body := height >= MIN_AIR + 3
		ceiling[i] = mini(top, floor_row[i] - MIN_AIR) if body else mini(top, floor_row[i] - 1)
	for shaft in plan["shafts"]:
		for c in range(shaft["x"], shaft["x"] + shaft["width"]):
			ceiling[c - xl] = mini(ceiling[c - xl], cy - 8)
	if room.has("surface"):
		ceiling.fill(0)
	return {"xl": xl, "floor": floor_row, "ceiling": ceiling, "ponds": ponds, "cy": cy}


## How far each column is from one the profile keeps flat, in columns.
static func _distance_to_pinned(pinned: PackedByteArray) -> PackedFloat32Array:
	var n := pinned.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var d := 999.0
	for i in n:
		d = 0.0 if pinned[i] != 0 else d + 1.0
		out[i] = d
	d = 999.0
	for i in range(n - 1, -1, -1):
		d = 0.0 if pinned[i] != 0 else d + 1.0
		out[i] = minf(out[i], d)
	return out


## Smooths a floor until neighbouring columns differ by at most one row, leaving the pinned columns where they are.
static func _relax(floor_row: PackedInt32Array, pinned: PackedByteArray) -> void:
	for pass_number in 6:
		for i in range(1, floor_row.size()):
			if pinned[i] == 0 and absi(floor_row[i] - floor_row[i - 1]) > 1:
				floor_row[i] = floor_row[i - 1] + signi(floor_row[i] - floor_row[i - 1])
		for i in range(floor_row.size() - 2, -1, -1):
			if pinned[i] == 0 and absi(floor_row[i] - floor_row[i + 1]) > 1:
				floor_row[i] = floor_row[i + 1] + signi(floor_row[i] - floor_row[i + 1])


static func _clear_of(pinned: PackedByteArray, xl: int, from: int, to: int) -> bool:
	for c in range(from, to + 1):
		if c - xl < 0 or c - xl >= pinned.size() or pinned[c - xl] != 0:
			return false
	return true


static func _carve_hall(cells: Dictionary, profile: Dictionary) -> void:
	var xl: int = profile["xl"]
	for i in profile["floor"].size():
		for r in range(profile["ceiling"][i], profile["floor"][i]):
			cells.erase(Vector2i(xl + i, r))


## A tunnel between two mouths, a floor that climbs at no more than a row for every SLOPE columns, a ceiling a little over
## the wizard's head that rises and falls, and a few wider chambers on the way.
static func _carve_tunnel(cells: Dictionary, from: Vector2i, to: Vector2i, slope: float, surface_x: int, rng: RandomNumberGenerator) -> void:
	var a := from if from.x < to.x else to
	var b := to if from.x < to.x else from
	var run := b.x - a.x
	var dy := b.y - a.y
	var flat := 6
	var need := int(ceil(absf(dy) * slope))
	var ramp := maxi(need, mini(run - flat * 2, need + rng.randi_range(0, 10)))
	var ramp_start := flat + rng.randi_range(0, maxi(0, run - flat * 2 - ramp))
	if surface_x == a.x:
		ramp_start = flat  # a tunnel from the surface drops at once, so its trench stays near the end
	elif surface_x == b.x:
		ramp_start = run - flat - ramp
	var wiggle_amp := rng.randf_range(0.0, 1.4)
	var wiggle_period := rng.randf_range(9.0, 16.0)
	var wiggle_phase := rng.randf() * TAU
	var height := float(PASSAGE_HEIGHT) + 1.0
	var floors := PackedInt32Array()
	for k in range(run + 1):
		var progress := clampf(float(k - ramp_start) / maxf(ramp, 1), 0.0, 1.0)
		var level := a.y + roundi(dy * progress)
		var edge := clampf(minf(k, run - k) / 8.0, 0.0, 1.0)
		floors.append(level + roundi(wiggle_amp * edge * sin(TAU * k / wiggle_period + wiggle_phase)))
	var pinned := PackedByteArray()
	pinned.resize(floors.size())
	pinned[0] = 1
	pinned[floors.size() - 1] = 1
	floors[0] = a.y
	floors[floors.size() - 1] = b.y
	_relax(floors, pinned)
	for k in range(run + 1):
		height = clampf(height + rng.randf_range(-0.6, 0.6), PASSAGE_HEIGHT, PASSAGE_HEIGHT + 3.0)
		for r in range(floors[k] - roundi(height), floors[k]):
			cells.erase(Vector2i(a.x + k, r))
	# Wider chambers: a rounded space cut above the floor.
	for i in rng.randi_range(1, 3):
		var k := rng.randi_range(10, maxi(10, run - 10))
		var rx := rng.randi_range(4, 8)
		var ry := rng.randi_range(3, 5)
		for c in range(-rx, rx + 1):
			for r in range(-ry * 2, 0):
				if pow(float(c) / rx, 2.0) + pow(float(r + ry) / ry, 2.0) <= 1.0:
					cells.erase(Vector2i(a.x + k + c, floors[clampi(k + c, 0, run)] + r))


## Pillars of rock standing in a pool of lava, three wide with two-tile gaps, one tile above the floor at its edges.
static func _stepping_stones(cells: Dictionary, pond: Dictionary) -> void:
	var c: int = pond["a"]
	while c <= pond["b"]:
		for k in 3:
			if c + k <= pond["b"]:
				for r in range(pond["surface"] - 1, pond["surface"] + pond["depth"] + 1):
					cells[Vector2i(c + k, r)] = ArenaGen.GROUND
		c += 5


## Stepped rock formations, a ziggurat standing on a hall's floor: steps of four columns, each FORMATION_STEP rows above the
## last up to a flat top and down again the same way, so a walker can climb over from either side. Kept off the mouths.
static func _formations(cells: Dictionary, profile: Dictionary, plan: Dictionary, rng: RandomNumberGenerator) -> void:
	var room: Dictionary = plan["room"]
	var tall: bool = room["air"] > 24
	var xl: int = profile["xl"]
	for i in rng.randi_range(1, 2) + (1 if tall else 0):
		var steps := rng.randi_range(2, 4 if tall else 3)  # how many steps up to the top
		var col := rng.randi_range(xl + 8, xl + room["hw"] * 2 - 10 - steps * 8)
		var base: int = profile["floor"][col - xl]
		var placed: Array[Vector2i] = []
		var fits := true
		for k in steps * 2 - 1:
			var level := k + 1 if k < steps else steps * 2 - 1 - k
			var at := Vector2i(col + 4 * k, base - FORMATION_STEP * level)
			if not _open_above(cells, profile, plan, at, 4, base):
				fits = false
				break
			placed.append(at)
		if fits:
			for at in placed:
				for c in 4:
					for r in range(at.y, profile["floor"][at.x + c - xl]):
						cells[Vector2i(at.x + c, r)] = ArenaGen.GROUND


## True when a pillar top of a width fits at a tile: the air above it and down to the floor beside it is clear, clear of the
## shafts and mouths, and the pillar stands on the floor.
static func _open_above(cells: Dictionary, profile: Dictionary, plan: Dictionary, at: Vector2i, width: int, base: int) -> bool:
	var xl: int = profile["xl"]
	for pin in plan["pins"]:
		if at.x + width > pin.x - 2 and at.x < pin.y + 2:
			return false
	for c in range(at.x - 1, at.x + width + 1):
		if c - xl < 0 or c - xl >= profile["floor"].size():
			return false
		if absi(profile["floor"][c - xl] - base) > 1:
			return false  # the ground here is not level with where the formation starts
		for r in range(at.y - 4, profile["floor"][c - xl]):
			if cells.has(Vector2i(c, r)):
				return false
	return true


## Where the castle can stand on the surface: a stretch of ground clear of the tunnel mouths, or -1 when there is none.
static func _castle_site(surface: Dictionary, pins: Array, rng: RandomNumberGenerator) -> int:
	var options: Array[int] = []
	var left: int = surface["cx"] - surface["hw"] + 12
	var right: int = surface["cx"] + surface["hw"] - 12 - CASTLE_WIDTH
	for x in range(left, right, 6):
		if absi(x + CASTLE_WIDTH / 2 - surface["cx"]) < CASTLE_WIDTH / 2 + 20:
			continue  # the middle is where you start
		var free := true
		for pin: Vector2i in pins:
			if pin.y > x - 8 and pin.x < x + CASTLE_WIDTH + 8:
				free = false
		if free:
			options.append(x)
	return options[rng.randi() % options.size()] if not options.is_empty() else -1


## A castle on level ground, in stone, with battlements. A tall gatehouse stands at the west end with an arched gate at ground level,
## leading into a long hall under a lower wall. At the far end of the hall a stair climbs inside the east tower and comes out into the open at the
## top of it, and a stair down its far side leads to the ground. The gatehouse, the wall and the west half of the tower top cannot be reached;
## they are only there to be seen. Nothing floats: the east tower stands on the ground and holds up the rest.
## Returns the rooms inside it, as one rectangle of tiles per column, so they can be painted as the inside of a building.
static func _castle(cells: Dictionary, ground: int, x: int) -> Array:
	var inside: Array = []
	var tower := CASTLE_STAIR  # the first column of the east tower
	var reach := CASTLE_HEIGHT
	for i in CASTLE_WIDTH:
		var top := 0
		var battlements := true
		if i < CASTLE_GATE:
			top = reach  # the gatehouse
		elif i < tower:
			top = CASTLE_WALL  # the wall over the hall
		elif i <= tower + reach:
			top = reach  # the east tower
		else:
			top = maxi(0, reach - (i - tower - reach))  # the stair down the far side
			battlements = false
		if battlements and (i / 2) % 2 == 0 and i < tower + reach - 8:
			top += 2  # a merlon
		for r in range(ground - top, ground):
			cells[Vector2i(x + i, r)] = ArenaGen.STONE
	# The gate and the hall: a passage through the gatehouse at ground level, its mouth stepped like an arch, then the hall.
	for i in tower:
		var room := CASTLE_HALL_HEIGHT if i >= CASTLE_GATE else (CASTLE_GATE_HEIGHT - 2 if i < 1 else (CASTLE_GATE_HEIGHT - 1 if i < 2 else CASTLE_GATE_HEIGHT))
		for r in range(ground - room, ground):
			cells.erase(Vector2i(x + i, r))
		inside.append(Rect2i(x + i, ground - room, 1, room))
	# The stair up inside the east tower. Where the stone over it would be thinner than three rows, it is open to the sky.
	for k in reach + 1:
		var room := mini(CASTLE_HALL_HEIGHT, reach - k - 3)
		var ceiling := ground - reach - 2 if room < 5 else ground - k - room
		for r in range(ceiling, ground - k):
			cells.erase(Vector2i(x + tower + k, r))
		if room >= 5:
			inside.append(Rect2i(x + tower + k, ceiling, 1, ground - k - ceiling))
	return inside


## The tile a hall's marker stands on: the flat floor column nearest the middle that has headroom, clear of holes and basins.
static func _marker(profile: Dictionary, plan: Dictionary) -> Vector2i:
	var room: Dictionary = plan["room"]
	var xl: int = profile["xl"]
	var best := -1
	for i in profile["floor"].size():
		var c: int = xl + i
		if profile["floor"][i] != room["cy"] or profile["floor"][i] - profile["ceiling"][i] < MIN_AIR:
			continue
		var in_hole := false
		for shaft in plan["shafts"]:
			if c >= shaft["x"] - 2 and c < shaft["x"] + shaft["width"] + 2:
				in_hole = true
		if in_hole:
			continue
		if best < 0 or absi(c - room["cx"]) < absi(best - room["cx"]):
			best = c
	return Vector2i(best, room["cy"] - 1)


## True when a cell does not stop a body: it is air.
static func passable(cells: Dictionary, cell: Vector2i) -> bool:
	return not cells.has(cell)


static func clear(cells: Dictionary, c: int, r: int) -> bool:
	for k in HEADROOM:
		if not passable(cells, Vector2i(c, r - k)):
			return false
	return true


static func supported(cells: Dictionary, c: int, r: int) -> bool:
	return cells.has(Vector2i(c, r + 1))


static func standing(cells: Dictionary, c: int, r: int, hazards := {}) -> bool:
	return clear(cells, c, r) and supported(cells, c, r) and not hazards.has(Vector2i(c, r))


## Every tile the wizard can stand on that can be reached from a starting tile by walking, stepping up one tile, falling
## and jumping up to JUMP_ROWS rows. Standing in lava does not count. This is a little stricter than the real jump, so a
## world that passes is walkable.
static func reachable(cells: Dictionary, start: Vector2i, bottom: int, hazards := {}) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		var found: Array[Vector2i] = []
		for dc in [-1, 1]:
			var c: int = at.x + dc
			for dr in [0, -1]:
				if standing(cells, c, at.y + dr, hazards) and clear(cells, at.x, at.y + dr):
					found.append(Vector2i(c, at.y + dr))
			# Walking off an edge: fall to the first thing below.
			if clear(cells, c, at.y) and not supported(cells, c, at.y):
				var r := at.y
				while r < bottom and clear(cells, c, r) and not supported(cells, c, r):
					r += 1
				if r < bottom and standing(cells, c, r, hazards):
					found.append(Vector2i(c, r))
		# Jumps: up to JUMP_ROWS higher, across at the same height, or down to a lower landing.
		for h in range(-JUMP_ROWS, JUMP_ROWS + 1):
			for dc in range(-JUMP_COLS, JUMP_COLS + 1):
				if dc == 0 and h <= 0:
					continue
				var target := Vector2i(at.x + dc, at.y - h)
				if not standing(cells, target.x, target.y, hazards):
					continue
				var open := true
				for c in range(mini(at.x, target.x), maxi(at.x, target.x) + 1):
					var top := mini(at.y, target.y) - HEADROOM + 1
					var last := at.y - 1 if c != target.x else target.y
					for r in range(top, last + 1):
						if not passable(cells, Vector2i(c, r)):
							open = false
				if open:
					found.append(target)
		for next in found:
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen

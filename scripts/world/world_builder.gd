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
const CASTLE_AIR := 9  # rows of air in a hall or a room
const CASTLE_SLAB := 2  # rows of stone between the storeys
const CASTLE_DOOR := 4  # rows tall a doorway is
const CASTLE_TOWER := 30  # rows the gate tower and the back tower stand above the ground
const CASTLE_KEEP := 38  # rows the keep stands above the ground
const CASTLE_WIDTH := 136  # columns the castle takes on the surface (SurfaceGen keeps the same)
const EXIT_FLAT := 10       # columns of flat floor inside a hall at a tunnel mouth
const LID_SPAN := 16        # columns of flat floor past a ramp that starts in the middle of a floor
const LID_GAP := 7          # columns of that ramp that are open pit: the floor above carries on past it, a jump across
const LID_ROWS := 3         # how thick the lid of rock over the ramp is
const PASSAGE_HEIGHT := 6   # rows of air in a tunnel, at the least
const BASIN_CHANCE := 0.5
const CHASM_WIDTH := 20     # columns of a lava chasm: further than a hasted jump reaches
const CHASM_DEPTH := 8      # rows from the floor to the bottom of it, which is too deep to climb out of
const PIT_WIDTH := 36         # columns of the piranha pit: far further than any jump
const PIT_DEPTH := 2         # rows of the piranha pit: shallow, a wizard can wade it and climb out
const CHASM_LAVA_TOP := 2   # rows under the floor where the lava's surface lies, so the lava fills the deep part of the pit
const WALL_HEIGHT := 8      # rows of a sheer wall in a passage: more than two jumps
const WALL_WIDTH := 3       # columns thick
const GAS_BANK := 8          # columns in each bank of it
const SPIKE_WIDTH := 5       # columns in each strip of spikes
const SPIKE_APART := 9       # columns from the start of one strip to the next
const ICE_WIDTH := 3         # columns thick a plug of ice is
const MIN_AIR := 9          # rows of air kept above the floor in the body of a hall

## Standing needs this many clear rows (the wizard is about 2.4 tiles tall).
const HEADROOM := 3
const JUMP_ROWS := 3
const JUMP_COLS := 4
const JUMP_FAR := 9     # how far a jump at (nearly) the same height reaches: a ramp's pit is jumped across


## Returns {"cells": a TileGrid, "size": Vector2i in tiles, "markers": {room id: Vector2i tile to stand on},
## "start": Vector2i, "ponds": [{"a", "b": first and last column, "surface": row, "depth": rows, "lava": bool}],
## "hazards": {Vector2i: true} for tiles inside lava, "shafts": [{"upper", "lower", "x", "width", "style", "platforms"}]}.
static func build(graph: WorldGraph, rng: RandomNumberGenerator) -> Dictionary:
	var size := WorldGraph.size
	var cells := TileGrid.new(size, ArenaGen.GROUND)
	var plans := {}
	for room in graph.rooms:
		plans[room["id"]] = {"room": room, "pins": [], "pits": [], "shafts": [], "left": false, "right": false}
	var tunnels := []
	for link in graph.links:
		var inside_x := -1  # the column of a mouth in the middle of a floor, where the ramp drops at once
		if link.get("inside_a", false):
			inside_x = link["pa"].x
		elif link.get("inside_b", false):
			inside_x = link["pb"].x
		tunnels.append({"from": link["pa"], "to": link["pb"], "slope": link["slope"], "surface_x": inside_x, "lock": link["lock"], "inward": link.get("inward", 1),
				"lid": inside_x >= 0, "row": link["pa"].y if link.get("inside_a", false) else link["pb"].y,
				"gate": graph.locks[link["lock"]]["gate"] if link["lock"] >= 0 else ""})
		for end in [[link["a"], link["pa"], link.get("inside_a", false)], [link["b"], link["pb"], link.get("inside_b", false)]]:
			var room: Dictionary = graph.rooms[end[0]]
			var mouth: Vector2i = end[1]
			if end[2]:
				# A mouth in the middle of a floor: level ground behind it and under the lid that carries the floor over the ramp.
				var way: int = signi(link["pb"].x - link["pa"].x) * (1 if end[0] == link["a"] else -1)
				plans[room["id"]]["pins"].append(Vector3i(mouth.x - EXIT_FLAT, mouth.x + LID_SPAN, mouth.x) if way > 0 else Vector3i(mouth.x - LID_SPAN, mouth.x + EXIT_FLAT, mouth.x))
				plans[room["id"]]["pits"].append(Vector2i(mouth.x, mouth.x + LID_GAP * way) if way > 0 else Vector2i(mouth.x + LID_GAP * way, mouth.x))
			elif room.has("surface"):
				plans[room["id"]]["pins"].append(Vector3i(mouth.x - EXIT_FLAT, mouth.x + EXIT_FLAT, mouth.x))
			elif mouth.x > room["cx"]:
				plans[room["id"]]["right"] = true
				plans[room["id"]]["pins"].append(Vector2i(mouth.x - EXIT_FLAT, mouth.x))
			else:
				plans[room["id"]]["left"] = true
				plans[room["id"]]["pins"].append(Vector2i(mouth.x, mouth.x + EXIT_FLAT))
	var ponds := []
	var hazards := {}
	var profiles := {}
	var castle_x: int = graph.surface["castle"]
	plans[0]["pins"].append(Vector3i(graph.rooms[0]["cx"] - SurfaceGen.START_FLAT, graph.rooms[0]["cx"] + SurfaceGen.START_FLAT, graph.rooms[0]["cx"]))  # level ground to start on
	for room in graph.rooms:
		profiles[room["id"]] = _surface_profile(graph, plans[0]) if room.has("surface") else _profile(plans[room["id"]], rng)
	for room in graph.rooms:
		_carve_hall(cells, profiles[room["id"]])
		for pond in profiles[room["id"]]["ponds"]:
			ponds.append(pond)
			if pond["lava"]:
				_stepping_stones(cells, pond)
				for c in range(pond["a"], pond["b"] + 1):
					for r in range(pond["surface"], pond["surface"] + pond["depth"] + 1):
						hazards[Vector2i(c, r)] = true
	var carved := []
	for tunnel in tunnels:
		carved.append(_carve_tunnel(cells, tunnel["from"], tunnel["to"], tunnel["slope"], tunnel["surface_x"], rng, tunnel["gate"] in ["chasm", "flood", "brambles", "dark", "gas", "piranhas"]))
	var markers := {}
	for room in graph.rooms:
		markers[room["id"]] = _marker(profiles[room["id"]], plans[room["id"]])
		if not room.has("surface"):
			plans[room["id"]]["pins"].append(Vector2i(markers[room["id"]].x - 3, markers[room["id"]].x + 3))  # keep the marker clear
			_formations(cells, profiles[room["id"]], plans[room["id"]], rng)
	for k in tunnels.size():
		if tunnels[k]["lid"]:
			_lid(cells, tunnels[k], carved[k])
	var spawns: Array[Vector2i] = []
	var sky_floor: PackedInt32Array = profiles[0]["floor"]
	for spawn in graph.spawns:
		var x: int = spawn["x"] - spawn["side"] * 5  # on the flat ground behind the way down, not in its trench
		spawns.append(Vector2i(x, sky_floor[x - profiles[0]["xl"]] - 1))
	var hall: Array = []
	var doors: Array = []
	var ladders: Array = []
	if castle_x >= 0:
		var castle := _castle(cells, graph.rooms[0]["cy"], castle_x)
		hall = castle["hall"]
		doors = castle["doors"]
		ladders = castle["ladders"]
	# What bars each gated tunnel is made in it: a lava chasm, a stretch of thorns or a sheer wall.
	var gates := []
	for k in tunnels.size():
		if tunnels[k]["lock"] >= 0:
			var gate := _make_gate(cells, tunnels[k], carved[k], ponds, hazards, profiles[0])
			gate["lock"] = tunnels[k]["lock"]
			gates.append(gate)
	return {"cells": cells, "size": size, "markers": markers, "start": markers[graph.start], "ponds": ponds,
			"hazards": hazards, "castle": castle_x, "hall": hall, "doors": doors, "ladders": ladders, "profiles": profiles, "sky": {"xl": profiles[0]["xl"], "floor": profiles[0]["floor"]},
			"surface": graph.surface, "gates": gates, "spawns": spawns}


## The ground of the surface: the biomes' heights, made level round every mouth, with the pools dug into it.
static func _surface_profile(graph: WorldGraph, plan: Dictionary) -> Dictionary:
	var room: Dictionary = plan["room"]
	var xl: int = room["cx"] - room["hw"]
	var n: int = room["hw"] * 2 + 1
	var floor_row := PackedInt32Array()
	floor_row.resize(n)
	var pinned := PackedByteArray()
	pinned.resize(n)
	for i in n:
		floor_row[i] = graph.surface["floor"][xl + i]
	for pond in graph.surface["ponds"]:
		for c in range(pond["a"] - SurfaceGen.POOL_PAD, pond["b"] + SurfaceGen.POOL_PAD + 1):
			pinned[c - xl] = 1
	if graph.surface["castle"] >= 0:
		for c in range(graph.surface["castle"] - 3, graph.surface["castle"] + CASTLE_WIDTH + 4):
			pinned[c - xl] = 1
	for pin: Vector3i in plan["pins"]:
		var level := floor_row[pin.z - xl]  # a mouth is level for a stretch, at the height of the mouth itself
		for c in range(pin.x, pin.y + 1):
			floor_row[c - xl] = level
			pinned[c - xl] = 1
	SurfaceGen._relax(floor_row, pinned, graph.surface["limits"], xl)
	var ceiling := PackedInt32Array()
	ceiling.resize(n)
	ceiling.fill(0)
	return {"xl": xl, "floor": floor_row, "ceiling": ceiling, "ponds": graph.surface["ponds"], "cy": room["cy"]}


## The floor over the start of a ramp that begins in the middle of a floor: after the open pit at its mouth, a lid of rock
## holds the floor up across, so the floor carries on over the ramp and a walker just jumps the pit.
static func _lid(cells: TileGrid, tunnel: Dictionary, carved: Dictionary) -> void:
	var mouth_x: int = tunnel["surface_x"]
	var way: int = 1 if tunnel["to"].x > tunnel["from"].x else -1
	if mouth_x != tunnel["from"].x:
		way = -way  # the interior mouth is the `to` end, so the ramp runs the other way
	var row: int = tunnel["row"]
	for k in range(LID_GAP, LID_SPAN):
		for r in range(row, row + LID_ROWS):
			cells.put(Vector2i(mouth_x + way * k, r), ArenaGen.GROUND)


## Makes what bars a gated tunnel, in the tunnel. Returns {"kind", "solve": the tiles to fill to take the gate away as a spell would
## (a tile's worth of floor the passage lacks), "thorns": the standing tiles a thorn stretch covers, "floors", "first": the floor row
## and first column of a thorn stretch}. Only the thorns are more than rock: a chasm is lava (a pond) and a wall is a drop and a cliff.
static func _make_gate(cells: TileGrid, tunnel: Dictionary, carved: Dictionary, ponds: Array, hazards: Dictionary, sky: Dictionary) -> Dictionary:
	var floors: PackedInt32Array = carved["floors"]
	var first: int = carved["a"].x
	var out := {"kind": tunnel["gate"], "solve": [], "thorns": [], "blocks": [], "at": Vector2i.ZERO}
	out["inward"] = tunnel.get("inward", 1)  # which way along the passage goes into the locked area: 1 to the right
	var span := Vector2i.ZERO  # the columns of the passage the gate takes up, counted from its left end
	match tunnel["gate"]:
		"chasm":
			# In the middle of the longest level stretch, a pit as wide as it needs and lava at the bottom of it.
			var k0 := _level_stretch(floors, CHASM_WIDTH)
			var level := floors[k0]
			span = Vector2i(k0, k0 + CHASM_WIDTH)
			_dig_pit(cells, first + k0, CHASM_WIDTH, level, out["inward"])
			var pond := {"a": first + k0, "b": first + k0 + CHASM_WIDTH - 1, "surface": level + CHASM_LAVA_TOP, "depth": CHASM_DEPTH - CHASM_LAVA_TOP, "lava": true}
			ponds.append(pond)
			for c in range(pond["a"], pond["b"] + 1):
				for r in range(pond["surface"], pond["surface"] + pond["depth"] + 1):
					hazards[Vector2i(c, r)] = true
			out["solve"].append({"rect": Rect2i(first + k0, level, CHASM_WIDTH, 1), "with": ArenaGen.GROUND})  # a bridge across
			out["at"] = Vector2i(first + k0, level)
		"flood":
			# The same pit, full of water to the brim: whoever falls in cannot climb out, and spells that cross water cross it.
			var k0 := _level_stretch(floors, CHASM_WIDTH)
			var level := floors[k0]
			span = Vector2i(k0, k0 + CHASM_WIDTH)
			_dig_pit(cells, first + k0, CHASM_WIDTH, level, out["inward"])
			ponds.append({"a": first + k0, "b": first + k0 + CHASM_WIDTH - 1, "surface": level, "depth": CHASM_DEPTH, "lava": false})
			out["solve"].append({"rect": Rect2i(first + k0, level, CHASM_WIDTH, 1), "with": ArenaGen.GROUND})  # a bridge across
			out["at"] = Vector2i(first + k0, level)
		"piranhas":
			# A long pit, no deeper than a wade, full of water and of piranhas: they have to be killed or crossed above.
			var k0 := _level_stretch(floors, PIT_WIDTH)
			var level := floors[k0]
			span = Vector2i(k0, k0 + PIT_WIDTH)
			for k in range(k0, k0 + PIT_WIDTH):
				for r in range(level, level + PIT_DEPTH):
					cells.erase(Vector2i(first + k, r))
					out["blocks"].append(Vector2i(first + k, r))  # for the test, to wade it is to be eaten
			ponds.append({"a": first + k0, "b": first + k0 + PIT_WIDTH - 1, "surface": level, "depth": PIT_DEPTH, "lava": false})
			out["solve"].append({"rect": Rect2i(first + k0, level, PIT_WIDTH, 1), "with": ArenaGen.GROUND})  # a bridge across
			out["at"] = Vector2i(first + k0, level)
			out["pit"] = Rect2i(first + k0, level, PIT_WIDTH, PIT_DEPTH)
		"sentinel":
			# A statue in the middle of the passage, on its floor. For the test the passage is barred: it shoots whoever walks it.
			var k0 := floors.size() / 2
			span = Vector2i(k0 - 1, k0 + 2)
			out["at"] = Vector2i(first + k0, floors[k0])
			out["stands"] = Vector2i(first + k0, floors[k0])
			for c in range(WorldGraph.TRAP_MARGIN, floors.size() - WorldGraph.TRAP_MARGIN):
				out["blocks"].append(Vector2i(first + c, floors[c] - 1))
		"ice":
			# The whole of the passage, floor to roof, for a few columns: ice that melts, or breaks.
			var k0 := _level_stretch(floors, ICE_WIDTH)
			span = Vector2i(k0, k0 + ICE_WIDTH)
			out["columns"] = []
			for k in range(k0, k0 + ICE_WIDTH):
				var top := floors[k]
				while top > 1 and not cells.has(Vector2i(first + k, top - 1)):
					top -= 1
				out["columns"].append({"x": first + k, "top": top, "bottom": floors[k]})
				for r in range(top, floors[k]):
					out["blocks"].append(Vector2i(first + k, r))
			out["at"] = Vector2i(first + k0, floors[k0])
		"dark":
			# Strips of spikes along a level floor, which no one sees until a light falls on them.
			var stretch := _trap_stretch(floors, WorldGraph.DARK_BUDGET, tunnel["inward"])
			var from := stretch.x
			var length := stretch.y - stretch.x
			span = stretch
			out["first"] = first + from
			out["at"] = Vector2i(first + from, floors[from])
			out["strips"] = []
			var k := 3
			while k + SPIKE_WIDTH <= length:
				out["strips"].append({"x": first + from + k, "width": SPIKE_WIDTH, "floors": floors.slice(from + k, from + k + SPIKE_WIDTH)})
				k += SPIKE_APART
			for c in range(from, stretch.y):  # for the test, the whole of the stretch bars the way: walking it unseen costs more than it can
				out["blocks"].append(Vector2i(first + c, floors[c] - 1))
		"gas":
			# Banks of poison gas lying along a level floor, from the floor to the roof.
			var stretch := _trap_stretch(floors, WorldGraph.GAS_BUDGET, tunnel["inward"])
			var from := stretch.x
			span = stretch
			out["first"] = first + from
			out["at"] = Vector2i(first + from, floors[from])
			out["banks"] = []
			for k in range(from, stretch.y, GAS_BANK):
				var last := mini(k + GAS_BANK, stretch.y)
				var tops := PackedInt32Array()
				for c in range(k, last):
					var top := floors[c]
					while top > 1 and not cells.has(Vector2i(first + c, top - 1)):
						top -= 1
					tops.append(top)
				out["banks"].append({"x": first + k, "floors": floors.slice(k, last), "tops": tops})
			for k in range(from, stretch.y):
				out["blocks"].append(Vector2i(first + k, floors[k] - 1))
		"wall":
			# A block of rock standing up from the floor, with room cut over the top of it: a sheer face on each side to get over.
			var run := floors.size() - 1
			var k0 := run / 2
			for step in range(0, run):  # the place nearest the middle where the rock over the top of it is deep enough
				var k := run / 2 + (step + 1) / 2 * (1 if step % 2 == 0 else -1)
				if k < 6 or k > run - 6 - WALL_WIDTH:
					continue
				var shallow := false
				for c in range(k, k + WALL_WIDTH):
					var i: int = first + c - sky["xl"]
					shallow = shallow or floors[c] - WALL_HEIGHT - 5 < sky["floor"][clampi(i, 0, sky["floor"].size() - 1)] + 4
				if not shallow:
					k0 = k
					break
			var top := mini(floors[k0 - 1], floors[k0 + WALL_WIDTH]) - WALL_HEIGHT
			span = Vector2i(k0, k0 + WALL_WIDTH)
			out["at"] = Vector2i(first + k0, top)
			out["columns"] = []
			for c in range(k0, k0 + WALL_WIDTH):
				for r in range(top - 5, top):
					cells.erase(Vector2i(first + c, r))
				for r in range(top, floors[c]):
					cells.erase(Vector2i(first + c, r))  # the wall is not part of the ground: it stands in the passage as a RockWall and can be broken down
					out["blocks"].append(Vector2i(first + c, r))
				out["columns"].append({"x": first + c, "top": top, "bottom": floors[c]})
				out["solve"].append({"rect": Rect2i(first + c, top, 1, floors[c] - top), "with": -1})  # the passage without the wall
		"brambles":
			var stretch := _trap_stretch(floors, WorldGraph.THORN_BUDGET, tunnel["inward"])  # longer downhill, shorter uphill
			var from := stretch.x
			span = stretch
			out["first"] = first + from
			out["at"] = Vector2i(first + from, floors[from])
			out["floors"] = floors.slice(from, stretch.y)
			for k in range(from, stretch.y):
				out["thorns"].append(Vector2i(first + k, floors[k] - 1))
	var edge := clampi(span.x - 4 if out["inward"] > 0 else span.y + 3, 0, floors.size() - 1)
	out["outside"] = Vector2i(first + edge, floors[edge])  # a place on the floor just short of the gate, on the way in from outside
	return out


## Digs a pit CHASM_DEPTH deep and `width` columns wide into a level floor. The side a walker comes from, on the way in, slopes gently down
## (a row for every two columns), so anyone who falls in can walk back out; the far side is sheer, too high to climb.
static func _dig_pit(cells: TileGrid, first: int, width: int, level: int, inward: int) -> void:
	for k in width:
		var from_near := k if inward > 0 else width - 1 - k
		for r in range(level, level + mini(CHASM_DEPTH, 1 + from_near / 2)):
			cells.erase(Vector2i(first + k, r))


## The columns [from, to) a trap covers in a passage, in the middle of it: as many as it takes to cost a walker going inward the
## budget's worth of level walking. A column going downhill (or level) counts one; uphill, where they are slower, it counts
## the slope's own length, so a trap is longer downhill and shorter uphill.
static func _trap_stretch(floors: PackedInt32Array, budget: float, inward: int) -> Vector2i:
	var count := floors.size()
	var lo := WorldGraph.TRAP_MARGIN
	var hi := count - WorldGraph.TRAP_MARGIN
	var from := count / 2
	var to := from
	var spent := 0.0
	var grow_left := true
	while spent < budget and (from > lo or to < hi):
		if (grow_left and from > lo) or to >= hi:
			from -= 1
			var step := (floors[from + 1] - floors[from]) * inward  # rows down, going inward, from this column to the next
			spent += 1.0 if step >= 0 else sqrt(1.0 + float(step * step))
		else:
			var step := (floors[mini(to + 1, count - 1)] - floors[to]) * inward
			spent += 1.0 if step >= 0 else sqrt(1.0 + float(step * step))
			to += 1
		grow_left = not grow_left
	return Vector2i(from, to)


## The first column of a level stretch of the given length, in the middle of the longest level stretch of a tunnel's floor.
static func _level_stretch(floors: PackedInt32Array, length: int) -> int:
	var best_at := 0
	var best_len := 0
	var at := 0
	for k in range(1, floors.size() + 1):
		if k == floors.size() or floors[k] != floors[at]:
			if k - at > best_len:
				best_len = k - at
				best_at = at
			at = k
	return best_at + (best_len - length) / 2


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


static func _carve_hall(cells: TileGrid, profile: Dictionary) -> void:
	var xl: int = profile["xl"]
	for i in profile["floor"].size():
		for r in range(profile["ceiling"][i], profile["floor"][i]):
			cells.erase(Vector2i(xl + i, r))


## A tunnel between two mouths, a floor that climbs at no more than a row for every SLOPE columns, a ceiling a little over
## the wizard's head that rises and falls, and a few wider chambers on the way.
static func _carve_tunnel(cells: TileGrid, from: Vector2i, to: Vector2i, slope: float, surface_x: int, rng: RandomNumberGenerator, flat_gate := false) -> Dictionary:
	var a := from if from.x < to.x else to
	var b := to if from.x < to.x else from
	var run := b.x - a.x
	var dy := b.y - a.y
	var flat := 6
	var need := int(ceil(absf(dy) * slope))
	var ramp := maxi(need, mini(run - flat * 2, need + rng.randi_range(0, 10)))
	var ramp_start := flat + rng.randi_range(0, maxi(0, run - flat * 2 - ramp))
	if flat_gate:
		ramp = need  # a chasm needs a long level floor: the climb is done at one end and the rest lies flat
		ramp_start = 0 if rng.randf() < 0.5 else run - ramp
	if surface_x >= 0:
		ramp = need  # a ramp from the middle of a floor drops at once, as steep as a walker can climb, so its pit stays short
		ramp_start = 0 if surface_x == a.x else run - ramp
	var wiggle_amp := rng.randf_range(0.0, 1.4) if surface_x < 0 and not flat_gate else 0.0  # a ramp under a lid is straight, so the lid and the floor keep their distance
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
	return {"a": a, "floors": floors}


## Pillars of rock standing in a pool of lava, three wide with two-tile gaps, one tile above the floor at its edges.
static func _stepping_stones(cells: TileGrid, pond: Dictionary) -> void:
	var c: int = pond["a"]
	while c <= pond["b"]:
		for k in 3:
			if c + k <= pond["b"]:
				for r in range(pond["surface"] - 1, pond["surface"] + pond["depth"] + 1):
					cells.put(Vector2i(c + k, r), ArenaGen.GROUND)
		c += 5


## Stepped rock formations, a ziggurat standing on a hall's floor: steps of four columns, each FORMATION_STEP rows above the
## last up to a flat top and down again the same way, so a walker can climb over from either side. Kept off the mouths.
static func _formations(cells: TileGrid, profile: Dictionary, plan: Dictionary, rng: RandomNumberGenerator) -> void:
	var room: Dictionary = plan["room"]
	var tall: bool = room["air"] > 24
	var xl: int = profile["xl"]
	for i in rng.randi_range(1, 2) + (1 if tall else 0):
		var steps := rng.randi_range(2, 4 if tall else 3)  # how many steps up to the top
		var last_col: int = xl + room["hw"] * 2 - 10 - steps * 8
		if last_col < xl + 8:
			continue  # too small a hall for steps this long
		var col := rng.randi_range(xl + 8, last_col)
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
						cells.put(Vector2i(at.x + c, r), ArenaGen.GROUND)


## True when a pillar top of a width fits at a tile: the air above it and down to the floor beside it is clear, clear of the
## shafts and mouths, and the pillar stands on the floor.
static func _open_above(cells: TileGrid, profile: Dictionary, plan: Dictionary, at: Vector2i, width: int, base: int) -> bool:
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


## A castle on level ground, in stone, with battlements, and rooms on three floors inside it. Everything is carved out of solid stone, so
## nothing floats: floors and ceilings are stone, and walls stand between the rooms of a floor with a wooden door in each (see CastleDoor).
## The floors lie one over another, a whole way through the castle: the ground floor is seven rooms in a row from the gate to the back
## door, the first floor is the same seven over them, and under the keep the second floor has three more. A rope ladder (see RopeLadder)
## rises through a hatch in the ceiling of each room to the room above it, so there are many ways through: along any floor, or up and down
## between them. The towers and the keep are stone with small windows, and only there to be seen.
## Returns {"hall": the rooms inside, as one rectangle of tiles per column, so they can be painted as the inside of a building,
## "doors": [{"x": the column the door stands on the edge of, "floor": the row its floor starts on}],
## "ladders": [{"x": the first of the two columns of the hatch, "bottom": the row of the floor it climbs from, "top": the row of the floor it reaches}]}.
static func _castle(cells: TileGrid, ground: int, x: int) -> Dictionary:
	var hall: Array = []
	var doors: Array = []
	var ladders: Array = []
	var floor_1 := CASTLE_AIR + CASTLE_SLAB  # height of the first floor's floor
	var top_1 := floor_1 + CASTLE_AIR - 1  # the highest row of air on the first floor
	var floor_2 := top_1 + 1 + CASTLE_SLAB  # and of the second floor's
	var top_2 := floor_2 + CASTLE_AIR  # the highest row of air on the second floor (a row higher: the great hall)
	# The whole of it, solid: the towers at each end, the wings, the keep, with merlons on top.
	for i in CASTLE_WIDTH:
		var top := top_1 + 1 + CASTLE_SLAB
		if i < 16 or i >= CASTLE_WIDTH - 10:
			top = CASTLE_TOWER
		elif i >= 37 and i <= 104:
			top = CASTLE_KEEP
		if (i / 2) % 2 == 0:
			top += 2  # a merlon
		for h in top:
			cells.put(Vector2i(x + i, ground - 1 - h), ArenaGen.STONE)
	# Air, from height low to height high inclusive in one column, painted as a room.
	var carve := func(i: int, low: int, high: int) -> void:
		for h in range(low, high + 1):
			cells.erase(Vector2i(x + i, ground - 1 - h))
		hall.append(Rect2i(x + i, ground - 1 - high, 1, high - low + 1))
	# A room: columns from first to last inclusive, from the floor to the top of its air.
	var room := func(first: int, last: int, floor_h: int, high: int) -> void:
		for i in range(first, last + 1):
			carve.call(i, floor_h, high)
	# A wall between two rooms, two columns thick, with a doorway in it and a wooden door in the doorway.
	var door := func(i: int, floor_h: int) -> void:
		for k in 2:
			carve.call(i + k, floor_h, floor_h + CASTLE_DOOR - 1)
		doors.append({"x": x + i + 1, "floor": ground - floor_h})
	# A hatch two columns wide through the ceiling of the room whose floor is low_floor, to the room whose floor is up_floor, and a ladder in it.
	var hatch := func(i: int, low_floor: int, up_floor: int) -> void:
		for k in 2:
			carve.call(i + k, low_floor + CASTLE_AIR, up_floor - 1)
		ladders.append({"x": x + i, "bottom": ground - low_floor, "top": ground - up_floor})
	# The gate: a door in the outer wall, where the outside gives way to the inside, and a porch behind it.
	door.call(0, 0)
	carve.call(2, 0, CASTLE_AIR - 1)
	carve.call(3, 0, CASTLE_AIR - 1)
	# The rooms of a floor, as the first and last column of each; the walls between them take the two columns after each room.
	var rows: Array[Vector2i] = [Vector2i(4, 13), Vector2i(16, 33), Vector2i(36, 53), Vector2i(56, 73), Vector2i(76, 93), Vector2i(96, 113), Vector2i(116, 125)]
	for k in rows.size():
		room.call(rows[k].x, rows[k].y, 0, CASTLE_AIR - 1)  # the ground floor
		room.call(rows[k].x, rows[k].y, floor_1, top_1)  # the first floor, over it
		if k + 1 < rows.size():
			door.call(rows[k].y + 1, 0)
			door.call(rows[k].y + 1, floor_1)
		hatch.call(rows[k].x + 3, 0, floor_1)
	door.call(126, 0)  # the back door
	room.call(128, 131, 0, CASTLE_AIR - 1)
	carve.call(132, 0, CASTLE_AIR - 1)
	carve.call(133, 0, CASTLE_AIR - 1)
	door.call(134, 0)  # and the door in the outer wall at the back
	# The second floor, under the keep.
	var great: Array[Vector2i] = [Vector2i(40, 57), Vector2i(60, 77), Vector2i(80, 101)]
	for k in great.size():
		room.call(great[k].x, great[k].y, floor_2, top_2)
		if k + 1 < great.size():
			door.call(great[k].y + 1, floor_2)
	for i in [44, 66, 86]:
		hatch.call(i, floor_1, floor_2)
	# Windows: pockets of air in the solid stone of the towers and the keep, seen from outside as dark slits.
	var windows: Array[Vector3i] = []
	for i in [5, 9, 12, CASTLE_WIDTH - 9, CASTLE_WIDTH - 6, CASTLE_WIDTH - 3]:
		windows.append(Vector3i(i, 24, 3))
	for i in [46, 56, 68, 78, 90, 98]:
		windows.append(Vector3i(i, 33, 3))
	for spot in windows:
		for h in range(spot.y, spot.y + spot.z):
			cells.erase(Vector2i(x + spot.x, ground - 1 - h))
	return {"hall": hall, "doors": doors, "ladders": ladders}


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
		for pit: Vector2i in plan["pits"]:
			in_hole = in_hole or (c >= pit.x - 2 and c <= pit.y + 2)  # not in the pit at a ramp's mouth
		if in_hole:
			continue
		if best < 0 or absi(c - room["cx"]) < absi(best - room["cx"]):
			best = c
	return Vector2i(best, room["cy"] - 1)


## True when a cell does not stop a body: it is air.
static func passable(cells: TileGrid, cell: Vector2i) -> bool:
	return not cells.has(cell)


static func clear(cells: TileGrid, c: int, r: int) -> bool:
	for k in HEADROOM:
		if not passable(cells, Vector2i(c, r - k)):
			return false
	return true


static func supported(cells: TileGrid, c: int, r: int) -> bool:
	return cells.has(Vector2i(c, r + 1))


static func standing(cells: TileGrid, c: int, r: int, hazards := {}) -> bool:
	return clear(cells, c, r) and supported(cells, c, r) and not hazards.has(Vector2i(c, r))


## The world as it is before any gate is opened, for a wizard to find its way about: {"cells": a TileGrid in which ice and walls are as solid as rock,
## "barred": the tiles no one stands in or walks through (lava, thorns, the stretch a trap covers)}. Takes what build() returns.
static func shut(world: Dictionary) -> Dictionary:
	var cells: TileGrid = world["cells"].duplicate()
	var barred: Dictionary = world["hazards"].duplicate()
	for gate in world["gates"]:
		if gate.get("open", false):
			continue  # a gate that has been cleared bars nothing
		var per: int = gate.get("per", 0)  # a gate of thorns or gas is cleared a piece at a time: this many columns each
		var gone: Array = gate.get("gone", [])
		if gate["kind"] == "dark":  # only the strips bar the way: they are narrow, and a wizard jumps them
			for strip: Dictionary in gate["strips"]:
				for k in strip["floors"].size():
					barred[Vector2i(strip["x"] + k, strip["floors"][k] - 1)] = true
			continue
		for part in 2:  # the thorns, then the rest of what bars the way
			var list: Array = gate["thorns"] if part == 0 else gate["blocks"]
			for k in list.size():
				if per > 0 and gone.size() > k / per and gone[k / per]:
					continue
				var cell: Vector2i = list[k]
				if part == 1 and (gate["kind"] == "ice" or gate["kind"] == "wall"):
					cells.put(cell, ArenaGen.GROUND)
				else:
					barred[cell] = true
	return {"cells": cells, "barred": barred}


## Every tile the wizard can stand on that can be reached from a starting tile by walking, stepping up one tile, falling
## and jumping up to JUMP_ROWS rows (see Walkways). Standing in lava does not count.
static func reachable(cells: TileGrid, start: Vector2i, bottom: int, hazards := {}) -> Dictionary:
	var ways := Walkways.new(cells, bottom, hazards)
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		for next in ways.moves(queue.pop_back()):
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen

class_name SurfaceGen
extends RefCounted

## The ground above the caves. Each world is one biome: the whole surface is that biome, from end to end (the seed picks
## which, see MatchState). Heights are rows of tiles (a lower number is higher ground). Neighbouring columns never differ by
## more than a row, so all of it can be walked. Nothing here uses randomness except the rng it is given.

const BASE_ROW := 110       # the ground line of the plains
const MARGIN := 4           # columns at each end of the world that are left alone
const GRAVEYARD_WIDTH := 270
const CASTLE_WIDTH := 136   # the same as WorldBuilder's
const CASTLE_START_WEST := 25    # columns from a castle's west end to a place to start on its ground floor, in the second room
const CASTLE_START_EAST := 105   # and in the sixth
const POOL_PAD := 3         # columns of level shore each side of a pool
const START_FLAT := 8       # columns each side of the middle that are level, to start on
const LEDGE := 3            # the most a ledge on a mountain climbs in one column: a jump (the wizard clears three rows)
const RIM := 11             # columns each side of a volcano's middle that are level: the rim round its crater
const CRATER_WIDTH := 16    # the lava lake in a volcano's top
const BIOMES := ["graveyard", "mountains", "jungle", "ashlands", "castle", "underground"]  # one of these is the whole of a world
const OPEN_BIOMES := ["graveyard", "mountains", "jungle", "ashlands"]  # those with open sky and room to spare: the last world of a match is one of them

## True for the biome with halls under the ground (the deep's caves). The rest have no tunnels: each has its own landmarks on the
## surface in place of them (the castle's are its floors and its cellar, in the castles themselves).
static func has_halls(biome: String) -> bool:
	return biome == "underground"


## What each biome looks like: the tiles of its grassy top, the backdrop, the colour its daylight is tinted, and the
## things standing about on it.
const CRYPT_SPACING := 80  # columns between one crypt and the next
const LOOKS := {
	"graveyard": {"title": "The Graveyard", "tiles": "cemetery", "weather": ["rain", "fog"], "backdrop": "cemetery", "tint": Color(0.6, 0.62, 0.68)},  # dark, with rain and a fog
	"mountains": {"title": "The Snowy Peaks", "tiles": "stone", "snow": 26, "weather": ["snow", "blizzard"], "backdrop": "mountains", "tint": Color(0.82, 0.86, 0.98)},
	"jungle": {"title": "The Jungle", "tiles": "swamp", "weather": ["fireflies", "rain"], "backdrop": "jungle", "tint": Color(0.8, 1.0, 0.82)},
	"ashlands": {"title": "The Ashlands", "tiles": "ash", "weather": ["ash", "embers"], "backdrop": "ashlands", "tint": Color(1.12, 0.78, 0.7)},
	"castle": {"title": "The Castle", "tiles": "church", "backdrop": "cemetery", "tint": Color(0.9, 0.92, 1.08)},
	"underground": {"title": "The Deep", "tiles": "stone", "backdrop": "cemetery", "tint": Color(0.42, 0.4, 0.55)},  # under a roof of rock: no sky shows
}


## The ground of one world: one biome over the whole width, with open sky, level ground to start on in the middle and the
## biome's pools. Returns {"floor": the first solid row in each column, "limits": the most each column may step from the one
## before it, "biomes": [{"name", "a", "b"}], "ponds": [{"a", "b", "surface", "depth", "lava"}], "castles": the first column of each castle
## on the ground (only the castle world has any), "castle": the first of those or -1, "roofed": true when a roof of rock covers the surface
## (the underground), "start": the column to start on, "craters": the volcanoes of the ashlands [{"x": the column of the middle, "row": the
## rim's row}], "mud" and "thorns": the jungle's pits of mud and thickets of thorns [{"a", "b"}: first and last column], "trees": [{"column", "size", "mirror"}], "crypts": the columns of the graveyard's crypts, "landmarks": columns
## of level ground at a place worth going to (the rim of a volcano, a mountain's top), where pages are laid first}.
static func build(width: int, biome: String, rng: RandomNumberGenerator) -> Dictionary:
	var n := width - MARGIN * 2
	var offset := _offsets(biome, n, rng)
	var floor_row := PackedInt32Array()
	floor_row.resize(width)
	floor_row.fill(BASE_ROW)
	var limits := PackedByteArray()  # the most a column may differ from the one before it: one row, or a ledge on a mountain
	limits.resize(width)
	limits.fill(1)
	var volcanoes := _volcanoes(biome, n, rng)
	for volcano in volcanoes:  # the cone of a volcano climbs a row to each column, up to its flat rim
		for k in n:
			offset[k] -= clampf(volcano["height"] + RIM - absf(k - volcano["at"]), 0.0, volcano["height"])
	for i in n:
		floor_row[MARGIN + i] = BASE_ROW + roundi(offset[i])
	if biome == "mountains":
		for c in range(MARGIN + 1, MARGIN + n):
			var step := floor_row[c] - floor_row[c - 1]
			if absi(step) > 1:
				limits[c] = mini(absi(step), LEDGE)
				floor_row[c] = floor_row[c - 1] + signi(step) * mini(absi(step), LEDGE)
	# The start: level ground in the middle, pinned so the smoothing leaves it alone.
	var middle := width / 2
	var pinned := PackedByteArray()
	pinned.resize(width)
	for c in range(middle - START_FLAT, middle + START_FLAT + 1):
		floor_row[c] = BASE_ROW
		pinned[c] = 1
	var craters := []
	for volcano in volcanoes:
		var middle_column: int = MARGIN + volcano["at"]
		var rim_row: int = BASE_ROW - volcano["height"]
		for c in range(middle_column - RIM, middle_column + RIM + 1):
			floor_row[c] = rim_row
			pinned[c] = 1
		craters.append({"x": middle_column, "row": rim_row})
	var castles: Array[int] = []
	if biome == "castle":  # the whole world is castle: castles stand side by side from end to end, with a solid wall of the same height at each end where there is room left over
		var count := (width - MARGIN * 2) / CASTLE_WIDTH
		var first := MARGIN + ((width - MARGIN * 2) - count * CASTLE_WIDTH) / 2
		for k in count:
			castles.append(first + k * CASTLE_WIDTH)
		for c in range(0, width):
			floor_row[c] = BASE_ROW
			pinned[c] = 1
	var starts := _starts(width, castles)
	if castles.is_empty():  # a world that is all surface starts its wizards a quarter of the way apart, each on a level shelf cut into whatever ground is there
		for spot in starts:
			var shelf := floor_row[spot]
			for c in range(spot - START_FLAT, spot + START_FLAT + 1):
				floor_row[c] = shelf
				pinned[c] = 1
	_relax(floor_row, pinned, limits)
	# Pools, after the ground is smooth: each is dug into a level stretch of its own, far enough from any other level ground
	# that the ground between can slope from one to the other.
	var ponds := []
	for crater in craters:  # the lava lake in the top of each volcano
		var a: int = crater["x"] - CRATER_WIDTH / 2
		for c in range(a, a + CRATER_WIDTH):
			floor_row[c] = _lava_floor(c - a, crater["row"], 1)
		ponds.append({"a": a, "b": a + CRATER_WIDTH - 1, "surface": crater["row"], "depth": 1, "lava": true, "islands": true})
	var wants := _pools_for(biome, rng)
	var lava: bool = wants[1]
	for k in wants[0]:
		for attempt in 24:
			var pool_width := 5 * rng.randi_range(3, 6) + 3 if lava else rng.randi_range(14, 28)  # a lava lake ends in an island, as it begins
			var a := rng.randi_range(MARGIN + 14, width - MARGIN - 1 - pool_width - 14)
			var level := floor_row[a - 1]
			if _near_a_start(width, a - POOL_PAD, a + pool_width + POOL_PAD):
				continue
			if not _room_to_slope(floor_row, pinned, a - POOL_PAD, a + pool_width - 1 + POOL_PAD, level) or _on_a_volcano(craters, a - POOL_PAD, a + pool_width + POOL_PAD):
				continue
			var depth := 1 if lava else rng.randi_range(3, 4)
			for c in range(a - POOL_PAD, a + pool_width + POOL_PAD):
				floor_row[c] = level
				pinned[c] = 1
			for c in range(a, a + pool_width):
				floor_row[c] = _lava_floor(c - a, level, depth) if lava else level + mini(mini(c - a + 1, a + pool_width - c), depth)
			ponds.append({"a": a, "b": a + pool_width - 1, "surface": level, "depth": depth, "lava": lava, "islands": lava})
			break
	_relax(floor_row, pinned, limits)
	var mud := []
	var thorns := []
	var trees := []
	if biome == "jungle":
		_lay_jungle_hazards(width, ponds, mud, thorns, rng)
		trees = _plant_trees(floor_row, [ponds, mud, thorns], starts, rng)
	var crypts := _place_crypts(floor_row, [ponds], starts) if biome == "graveyard" else []
	return {"limits": limits, "floor": floor_row, "biomes": [{"name": biome, "a": MARGIN, "b": width - MARGIN - 1}], "ponds": ponds, "castles": castles, "castle": castles[0] if not castles.is_empty() else -1, "roofed": biome == "underground", "start": middle,
			"craters": craters, "mud": mud, "thorns": thorns, "trees": trees, "crypts": crypts, "landmarks": _landmarks(biome, floor_row, craters, trees, crypts), "starts": starts}


## The columns four wizards start from in a world that is all surface: a quarter of the way along it, each time over; or, in the castle
## world, inside the castles, on the ground floor, spread along the row.
static func _starts(width: int, castles: Array[int]) -> Array[int]:
	var out: Array[int] = []
	if castles.is_empty():
		for k in 4:
			out.append(roundi(width * (k + 0.5) / 4.0))
		return out
	var spots: Array[int] = []
	for castle in castles:
		spots.append(castle + CASTLE_START_WEST)
		spots.append(castle + CASTLE_START_EAST)
	for j in 4:
		out.append(spots[roundi(j * (spots.size() - 1) / 3.0)])
	return out


## The volcanoes of a biome: [{"at": the column (from the first the ground takes), "height": rows}]. Only the ashlands have them, a pair
## standing between the places the wizards start from (a quarter of the world apart, so the foot of one is never a start).
static func _volcanoes(biome: String, n: int, rng: RandomNumberGenerator) -> Array:
	if biome != "ashlands":
		return []
	var height := clampi(n / 22, 20, 46)
	var out := []
	for fraction in ([0.25, 0.75] if n >= 480 else [0.25]):
		out.append({"at": roundi(n * (fraction + rng.randf_range(-0.03, 0.03))), "height": height + rng.randi_range(-3, 3)})
	return out


## True when the columns from to are within a few columns of a place a wizard may start from in an open world (a quarter of the way
## along it, each time over), so no pool is ever the first thing someone lands in.
static func _near_a_start(width: int, from: int, to: int) -> bool:
	for spot in _starts(width, []):
		if to >= spot - 12 and from <= spot + 12:
			return true
	return false


## True when any part of the columns from to is on a volcano (the ground there climbs, so no pool is dug into it).
static func _on_a_volcano(craters: Array, from: int, to: int) -> bool:
	for crater in craters:
		var reach: int = BASE_ROW - crater["row"] + RIM + 4
		if to >= crater["x"] - reach and from <= crater["x"] + reach:
			return true
	return false


## Where the jungle's pits of mud and thickets of thorns lie: a handful of each, on separate stretches of ground, away from the pools,
## the start and the places the others start from.
static func _lay_jungle_hazards(width: int, ponds: Array, mud: Array, thorns: Array, rng: RandomNumberGenerator) -> void:
	var taken := []  # [first, last] columns
	for pond in ponds:
		taken.append([pond["a"] - 4, pond["b"] + 4])
	taken.append([width / 2 - START_FLAT - 4, width / 2 + START_FLAT + 4])
	for k in 4:  # the starting places of the other wizards
		var spot := roundi(width * (k + 0.5) / 4.0)
		taken.append([spot - 8, spot + 8])
	var each := maxi(3, width / 130)
	for kind in 2:
		for k in each:
			for attempt in 40:
				var length := rng.randi_range(6, 7) if kind == 0 else rng.randi_range(3, 5)
				var a := rng.randi_range(MARGIN + 14, width - MARGIN - 1 - length - 14)
				var overlaps := false
				for span in taken:
					overlaps = overlaps or (a <= span[1] + 3 and a + length - 1 >= span[0] - 3)
				if overlaps:
					continue
				taken.append([a, a + length - 1])
				(mud if kind == 0 else thorns).append({"a": a, "b": a + length - 1})
				break


## The jungle's great trees, one now and then along the ground where it is level and clear of the pits, the pools and the places the
## wizards start from: [{"column", "size": 1, 2 or 3 times the picture, "mirror"}]. The large ones have a branch with a vine to climb to it.
static func _plant_trees(floor_row: PackedInt32Array, hazards: Array, starts: Array, rng: RandomNumberGenerator) -> Array:
	var avoid := []  # [first, last] columns
	for list: Array in hazards:
		for entry: Dictionary in list:
			avoid.append([entry["a"] - 8, entry["b"] + 8])
	for column: int in starts:
		avoid.append([column - 12, column + 12])
	var out := []
	var column := MARGIN + 14
	while column < floor_row.size() - MARGIN - 14:
		var roll := rng.randf()
		var tree_size := 1 if roll < 0.2 else (2 if roll < 0.65 else 3)  # some small, some large, some larger still
		var mirror := rng.randf() < 0.5
		var spot := JungleTree.layout(tree_size, mirror)
		var clear: bool = absi(floor_row[column + spot["vine"]] - floor_row[column]) <= 2 and absi(floor_row[column + spot["vine"] / 2] - floor_row[column]) <= 1
		for span: Array in avoid:
			if column + 11 >= span[0] and column - 11 <= span[1]:
				clear = false
		if not clear:
			column += 3
			continue
		out.append({"column": column, "size": tree_size, "mirror": mirror})
		column += rng.randi_range(6, 11)
	return out


## The graveyard's crypts: columns of level ground, spread along the world and well clear of the pools and the places the wizards start from.
static func _place_crypts(floor_row: PackedInt32Array, hazards: Array, starts: Array) -> Array:
	var out := []
	var column := MARGIN + 30
	while column < floor_row.size() - MARGIN - 30:
		var level := true
		for d in range(-5, 6):
			level = level and floor_row[column + d] == floor_row[column]
		for start: int in starts:
			level = level and absi(start - column) > 18
		for list: Array in hazards:
			for entry: Dictionary in list:
				level = level and (column < entry["a"] - 10 or column > entry["b"] + 10)
		if level:
			out.append(column)
			column += CRYPT_SPACING
		else:
			column += 1
	return out


## Columns of level ground worth going to: the rim of each volcano, and the top of each mountain peak.
static func _landmarks(biome: String, floor_row: PackedInt32Array, craters: Array, trees: Array, crypts: Array) -> Array[int]:
	var out: Array[int] = []
	for column: int in crypts:
		out.append(column)  # a page lies in each crypt
	for tree: Dictionary in trees:
		if tree["size"] >= 2:
			out.append(tree["column"])  # a page lies on the branch of each large tree
	for crater in craters:
		out.append(crater["x"] - RIM + 1)
		out.append(crater["x"] + RIM - 1)
	if biome == "mountains":
		var c := MARGIN + 40
		while c < floor_row.size() - MARGIN - 40:
			var top := floor_row[c]
			for d in range(-40, 41):
				top = mini(top, floor_row[c + d])
			if floor_row[c] == top and top < BASE_ROW - 20 and (out.is_empty() or c - out[out.size() - 1] > 40):
				out.append(c)
				c += 40
			else:
				c += 1
	return out


## The ground at a column of a lava lake, k columns in from its first: an island of the ground itself three columns wide (a row above the shore, so that standing on it is out of the lava), then two
## columns of lava, and so on across, an island at each end. The islands are the ground, not pillars standing in it.
static func _lava_floor(k: int, level: int, depth: int) -> int:
	return level - 1 if k % 5 < 3 else level + depth  # shallow enough to climb out of: a wall of two rows, which a jump clears


## How many pools a biome has, and whether they are lava.
static func _pools_for(biome: String, rng: RandomNumberGenerator) -> Array:
	match biome:
		"jungle":
			return [rng.randi_range(3, 4), false]
		"ashlands":
			return [rng.randi_range(2, 3), true]
	return [0, false]


## True when level ground at a height can be made over the columns from to, without a cliff to any level ground (a pinned
## column) nearby: each is at least as many columns away as it is rows higher or lower.
static func _room_to_slope(floor_row: PackedInt32Array, pinned: PackedByteArray, from: int, to: int, level: int) -> bool:
	for c in range(maxi(0, from - 70), mini(floor_row.size(), to + 71)):
		if pinned[c] == 0 and c >= from and c <= to:
			continue
		if pinned[c] == 0:
			continue
		var distance := maxi(from - c, c - to)
		if c >= from and c <= to:
			return false
		if absi(floor_row[c] - level) > distance:
			return false
	return true


## How far above (negative) or below the plains each column of a biome sits.
static func _offsets(biome: String, n: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var phase1 := rng.randf() * TAU
	var phase2 := rng.randf() * TAU
	match biome:
		"mountains":
			# Two or three real peaks, each a ridge that climbs and falls at close to the steepest a walker can manage, with the
			# crags of rock along it.
			var count := 3 if n > 330 else 2
			var peaks := []
			for k in count:
				peaks.append([(k + 0.5 + rng.randf_range(-0.2, 0.2)) * n / count, rng.randf_range(60.0, 98.0), rng.randf_range(0.85, 1.0)])
			for k in n:
				var h := 0.0
				for peak in peaks:
					h = maxf(h, peak[1] - peak[2] * absf(k - peak[0]))
				if h > 3.0:
					h += 1.2 * sin(k / 4.0 + phase1) + 0.8 * sin(k / 1.9 + phase2)
					# Here and there the flank climbs in terraces: a flat tread, then a ledge of up to three rows that has to be jumped.
					var terraced := float(LEDGE) * floorf(h / LEDGE) + LEDGE * clampf((fposmod(h, LEDGE) / LEDGE - 0.4) / 0.2, 0.0, 1.0)
					h = lerpf(h, terraced, smoothstep(0.2, 0.8, 0.5 + 0.5 * sin(k / 29.0 + phase2)))
				out[k] = -maxf(h, 0.0)
		"jungle":
			for k in n:
				out[k] = 2.0 + 1.4 * sin(k / 9.0 + phase1) + 0.8 * sin(k / 4.0 + phase2)
		"castle":
			for k in n:
				out[k] = 1.5 * sin(k / 19.0 + phase1)
		"underground":
			for k in n:
				out[k] = 4.0 * sin(k / 13.0 + phase1) + 1.6 * sin(k / 5.0 + phase2)
		"ashlands":
			for k in n:
				out[k] = 4.0 * sin(k / 11.0 + phase1) + 1.6 * sin(k / 4.5 + phase2)
		_:
			for k in n:
				out[k] = 3.0 * sin(k / 17.0 + phase1) + 1.2 * sin(k / 6.5 + phase2)
	# Every biome meets the plains level at both ends.
	for k in n:
		var edge := clampf(float(mini(k, n - 1 - k)) / 12.0, 0.0, 1.0)
		out[k] *= edge if biome != "mountains" else 1.0
	return out


## Smooths a ground line until neighbouring columns differ by at most one row, leaving the pinned columns where they are.
## No pins at all (an empty array) is allowed.
static func _relax(floor_row: PackedInt32Array, pinned: PackedByteArray, limits := PackedByteArray(), offset := 0) -> void:
	for pass_number in 400:
		var changed := false
		for i in range(1, floor_row.size()):
			var most := 1 if limits.is_empty() else limits[offset + i]
			if (pinned.is_empty() or pinned[i] == 0) and absi(floor_row[i] - floor_row[i - 1]) > most:
				floor_row[i] = floor_row[i - 1] + signi(floor_row[i] - floor_row[i - 1]) * most
				changed = true
		for i in range(floor_row.size() - 2, -1, -1):
			var most := 1 if limits.is_empty() else limits[offset + i + 1]
			if (pinned.is_empty() or pinned[i] == 0) and absi(floor_row[i] - floor_row[i + 1]) > most:
				floor_row[i] = floor_row[i + 1] + signi(floor_row[i] - floor_row[i + 1]) * most
				changed = true
		if not changed:
			return


## The biome a column is in, as its name.
static func biome_at(surface: Dictionary, column: int) -> String:
	for biome in surface["biomes"]:
		if column >= biome["a"] and column <= biome["b"]:
			return biome["name"]
	return "graveyard"

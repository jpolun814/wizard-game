class_name SurfaceGen
extends RefCounted

## The ground above the caves: a long landscape cut into biomes, side by side. The graveyard (with the ruined castle)
## is in the middle, where you start; on either side, two of mountains, swamp, tundra and ashlands, in an order the
## seed picks. Heights are rows of tiles (a lower number is higher ground). Neighbouring columns never differ by more
## than a row, so all of it can be walked. Nothing here uses randomness except the rng it is given.

const BASE_ROW := 110       # the ground line of the plains
const MARGIN := 4           # columns at each end of the world that are left alone
const GRAVEYARD_WIDTH := 270
const CASTLE_WIDTH := 136   # the same as WorldBuilder's
const POOL_PAD := 3         # columns of level shore each side of a pool
const START_FLAT := 8       # columns each side of the middle that are level, to start on
const LEDGE := 3            # the most a ledge on a mountain climbs in one column: a jump (the wizard clears three rows)
const OTHERS := ["mountains", "swamp", "tundra", "ashlands"]

## What each biome looks like: the tiles of its grassy top, the backdrop, the colour its daylight is tinted, and the
## things standing about on it.
const LOOKS := {
	"graveyard": {"title": "The Graveyard", "tiles": "cemetery", "backdrop": "cemetery", "tint": Color(1.0, 1.0, 1.0)},
	"mountains": {"title": "The Mountains", "tiles": "stone", "snow": 26, "weather": ["snow"], "backdrop": "mountains", "tint": Color(0.82, 0.86, 0.98)},
	"swamp": {"title": "The Swamp", "tiles": "swamp", "weather": ["spores"], "backdrop": "swamp", "tint": Color(0.86, 1.0, 0.9)},
	"tundra": {"title": "The Tundra", "tiles": "snow", "weather": ["blizzard"], "backdrop": "tundra", "tint": Color(0.8, 0.95, 1.12)},
	"ashlands": {"title": "The Ashlands", "tiles": "cemetery", "weather": ["ash", "embers"], "backdrop": "ashlands", "tint": Color(1.12, 0.78, 0.7)},
}


## Returns {"floor": the first solid row in each column, "biomes": [{"name", "a", "b"}: the columns each takes],
## "ponds": [{"a", "b", "surface", "depth", "lava"}], "castle": the castle's first column, "start": the column to start on}.
static func build(width: int, rng: RandomNumberGenerator) -> Dictionary:
	var others: Array = OTHERS.duplicate()
	for i in others.size():
		others.append(others.pop_at(rng.randi() % others.size()))
	var middle := width / 2
	var graveyard := Vector2i(middle - GRAVEYARD_WIDTH / 2, middle + GRAVEYARD_WIDTH / 2 - 1)
	var left_room := graveyard.x - MARGIN
	var right_room := width - MARGIN - (graveyard.y + 1)
	var first := left_room / 2 + rng.randi_range(-14, 14)
	var third := right_room / 2 + rng.randi_range(-14, 14)
	var biomes := [
		{"name": others[0], "a": MARGIN, "b": MARGIN + first - 1},
		{"name": others[1], "a": MARGIN + first, "b": graveyard.x - 1},
		{"name": "graveyard", "a": graveyard.x, "b": graveyard.y},
		{"name": others[2], "a": graveyard.y + 1, "b": graveyard.y + third},
		{"name": others[3], "a": graveyard.y + third + 1, "b": width - MARGIN - 1},
	]
	var floor_row := PackedInt32Array()
	floor_row.resize(width)
	floor_row.fill(BASE_ROW)
	var ponds := []
	var limits := PackedByteArray()  # the most a column may differ from the one before it: one row, or a ledge on a mountain
	limits.resize(width)
	limits.fill(1)
	for biome in biomes:
		var n: int = biome["b"] - biome["a"] + 1
		var offset := _offsets(biome["name"], n, rng)
		for i in n:
			floor_row[biome["a"] + i] = BASE_ROW + roundi(offset[i])
		if biome["name"] == "mountains":
			for c in range(biome["a"] + 1, biome["b"] + 1):
				var step := floor_row[c] - floor_row[c - 1]
				if absi(step) > 1:
					limits[c] = mini(absi(step), LEDGE)
					floor_row[c] = floor_row[c - 1] + signi(step) * mini(absi(step), LEDGE)
	# The start: level ground in the middle. The castle stands on level ground to one side of it.
	for c in range(middle - START_FLAT, middle + START_FLAT + 1):
		floor_row[c] = BASE_ROW
	var castle := middle + 25 + rng.randi_range(0, 12) if rng.randf() < 0.5 else middle - 25 - CASTLE_WIDTH - rng.randi_range(0, 12)
	for c in range(castle - 3, castle + CASTLE_WIDTH + 4):
		floor_row[c] = BASE_ROW
	var pinned := PackedByteArray()
	pinned.resize(width)
	for c in range(middle - START_FLAT, middle + START_FLAT + 1):
		pinned[c] = 1
	for c in range(castle - 3, castle + CASTLE_WIDTH + 4):
		pinned[c] = 1
	_relax(floor_row, pinned, limits)
	# Pools, after the ground is smooth: each is dug into a level stretch of its own, far enough from any other level ground
	# that the ground between can slope from one to the other.
	for biome in biomes:
		var wants := _pools_for(biome["name"], rng)
		var pools: int = wants[0]
		var lava: bool = wants[1]
		for k in pools:
			for attempt in 24:
				var pool_width := rng.randi_range(18, 34) if lava or biome["name"] == "tundra" else rng.randi_range(14, 28)
				var a := rng.randi_range(biome["a"] + 14, biome["b"] - pool_width - 14)
				var level := floor_row[a - 1]
				if not _room_to_slope(floor_row, pinned, a - POOL_PAD, a + pool_width - 1 + POOL_PAD, level):
					continue
				var depth := 4 if lava else rng.randi_range(3, 4)
				for c in range(a - POOL_PAD, a + pool_width + POOL_PAD):
					floor_row[c] = level
					pinned[c] = 1
				for c in range(a, a + pool_width):
					floor_row[c] = level + mini(mini(c - a + 1, a + pool_width - c), depth)
				ponds.append({"a": a, "b": a + pool_width - 1, "surface": level, "depth": depth, "lava": lava})
				break
	_relax(floor_row, pinned, limits)
	return {"limits": limits, "floor": floor_row, "biomes": biomes, "ponds": ponds, "castle": castle, "start": middle}


## The ground of a world with no caves and no castle, for the last of the worlds: one biome, all of it open sky, with level ground to start on
## in the middle. Returns the same as build().
static func open(width: int, rng: RandomNumberGenerator) -> Dictionary:
	var biome: String = OTHERS[rng.randi() % OTHERS.size()]
	var n := width - MARGIN * 2
	var offset := _offsets(biome, n, rng)
	var floor_row := PackedInt32Array()
	floor_row.resize(width)
	floor_row.fill(BASE_ROW)
	var limits := PackedByteArray()
	limits.resize(width)
	limits.fill(1)
	for i in n:
		floor_row[MARGIN + i] = BASE_ROW + roundi(offset[i])
	if biome == "mountains":
		for c in range(MARGIN + 1, MARGIN + n):
			var step := floor_row[c] - floor_row[c - 1]
			if absi(step) > 1:
				limits[c] = mini(absi(step), LEDGE)
				floor_row[c] = floor_row[c - 1] + signi(step) * mini(absi(step), LEDGE)
	var middle := width / 2
	var pinned := PackedByteArray()
	pinned.resize(width)
	for c in range(middle - START_FLAT, middle + START_FLAT + 1):
		floor_row[c] = BASE_ROW
		pinned[c] = 1
	_relax(floor_row, pinned, limits)
	return {"limits": limits, "floor": floor_row, "biomes": [{"name": biome, "a": MARGIN, "b": width - MARGIN - 1}], "ponds": [], "castle": -1, "start": middle}


## How many pools a biome has, and whether they are lava.
static func _pools_for(biome: String, rng: RandomNumberGenerator) -> Array:
	match biome:
		"swamp":
			return [rng.randi_range(3, 4), false]
		"tundra":
			return [rng.randi_range(1, 2), false]
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
		"swamp":
			for k in n:
				out[k] = 2.0 + 1.4 * sin(k / 9.0 + phase1) + 0.8 * sin(k / 4.0 + phase2)
		"tundra":
			for k in n:
				out[k] = -4.0 + 6.0 * sin(k / 14.0 + phase1) + 2.5 * sin(k / 5.5 + phase2)
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

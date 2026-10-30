class_name SurfaceGen
extends RefCounted

## The ground above the caves. Each world is one biome: the whole surface is that biome, from end to end (the seed picks
## which, see MatchState). Heights are rows of tiles (a lower number is higher ground). Neighbouring columns never differ by
## more than a row, so all of it can be walked. Nothing here uses randomness except the rng it is given.

const BASE_ROW := 110       # the ground line of the plains
const MARGIN := 4           # columns at each end of the world that are left alone
const GRAVEYARD_WIDTH := 270
const CASTLE_WIDTH := 136   # the same as WorldBuilder's
const POOL_PAD := 3         # columns of level shore each side of a pool
const START_FLAT := 8       # columns each side of the middle that are level, to start on
const LEDGE := 3            # the most a ledge on a mountain climbs in one column: a jump (the wizard clears three rows)
const BIOMES := ["graveyard", "mountains", "swamp", "ashlands", "castle", "underground"]  # one of these is the whole of a world
const OPEN_BIOMES := ["graveyard", "mountains", "swamp", "ashlands"]  # those with open sky and room to spare: the last world of a match is one of them

## What each biome looks like: the tiles of its grassy top, the backdrop, the colour its daylight is tinted, and the
## things standing about on it.
const LOOKS := {
	"graveyard": {"title": "The Graveyard", "tiles": "cemetery", "backdrop": "cemetery", "tint": Color(1.0, 1.0, 1.0)},
	"mountains": {"title": "The Snowy Peaks", "tiles": "stone", "snow": 26, "weather": ["snow", "blizzard"], "backdrop": "mountains", "tint": Color(0.82, 0.86, 0.98)},
	"swamp": {"title": "The Swamp", "tiles": "swamp", "weather": ["spores"], "backdrop": "swamp", "tint": Color(0.86, 1.0, 0.9)},
	"ashlands": {"title": "The Ashlands", "tiles": "ash", "weather": ["ash", "embers"], "backdrop": "ashlands", "tint": Color(1.12, 0.78, 0.7)},
	"castle": {"title": "The Castle", "tiles": "church", "backdrop": "cemetery", "tint": Color(0.9, 0.92, 1.08)},
	"underground": {"title": "The Deep", "tiles": "stone", "backdrop": "cemetery", "tint": Color(0.42, 0.4, 0.55)},  # under a roof of rock: no sky shows
}


## The ground of one world: one biome over the whole width, with open sky, level ground to start on in the middle and the
## biome's pools. Returns {"floor": the first solid row in each column, "limits": the most each column may step from the one
## before it, "biomes": [{"name", "a", "b"}], "ponds": [{"a", "b", "surface", "depth", "lava"}], "castles": the first column of each castle
## on the ground (only the castle world has any), "castle": the first of those or -1, "roofed": true when a roof of rock covers the surface
## (the underground), "start": the column to start on}.
static func build(width: int, biome: String, rng: RandomNumberGenerator) -> Dictionary:
	var n := width - MARGIN * 2
	var offset := _offsets(biome, n, rng)
	var floor_row := PackedInt32Array()
	floor_row.resize(width)
	floor_row.fill(BASE_ROW)
	var limits := PackedByteArray()  # the most a column may differ from the one before it: one row, or a ledge on a mountain
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
	# The start: level ground in the middle, pinned so the smoothing leaves it alone.
	var middle := width / 2
	var pinned := PackedByteArray()
	pinned.resize(width)
	for c in range(middle - START_FLAT, middle + START_FLAT + 1):
		floor_row[c] = BASE_ROW
		pinned[c] = 1
	var castles: Array[int] = []
	if biome == "castle":  # castles stand in a row on level ground, an even number of them so the start falls between two
		var count := maxi(2, width / 250 / 2 * 2)
		var segment := (width - MARGIN * 2) / count
		for k in count:
			var x := MARGIN + k * segment + (segment - CASTLE_WIDTH) / 2
			castles.append(x)
			for c in range(x - 3, x + CASTLE_WIDTH + 4):
				floor_row[c] = BASE_ROW
				pinned[c] = 1
	_relax(floor_row, pinned, limits)
	# Pools, after the ground is smooth: each is dug into a level stretch of its own, far enough from any other level ground
	# that the ground between can slope from one to the other.
	var ponds := []
	var wants := _pools_for(biome, rng)
	var lava: bool = wants[1]
	for k in wants[0]:
		for attempt in 24:
			var pool_width := rng.randi_range(18, 34) if lava else rng.randi_range(14, 28)
			var a := rng.randi_range(MARGIN + 14, width - MARGIN - 1 - pool_width - 14)
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
	return {"limits": limits, "floor": floor_row, "biomes": [{"name": biome, "a": MARGIN, "b": width - MARGIN - 1}], "ponds": ponds, "castles": castles, "castle": castles[0] if not castles.is_empty() else -1, "roofed": biome == "underground", "start": middle}


## How many pools a biome has, and whether they are lava.
static func _pools_for(biome: String, rng: RandomNumberGenerator) -> Array:
	match biome:
		"swamp":
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
		"swamp":
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

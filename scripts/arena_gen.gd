class_name ArenaGen
extends RefCounted

## Builds a random arena out of chunks. The ground is not flat: each chunk has a shape of its own (a hill, a dip,
## a slope up or down, a step or a plateau), and the chunk's platforms, pillars and mounds stand on that ground,
## so they keep their place above it. Neighbouring columns never differ by more than one tile, so every slope is a
## walkable stair: the wizard and the enemies hop up one tile at a time.

const TILE := 32
const CHUNK_WIDTH := 6
const CHUNK_COUNT := 12  # the map is this many chunks wide
const FIRST_COL := -36   # first floor column, so the map is centred on column 0
const LEFT_WALL := FIRST_COL - 1
const RIGHT_WALL := FIRST_COL + CHUNK_WIDTH * CHUNK_COUNT
const GROUND_ROW := 6    # the flat ground line; the terrain moves up and down from here
const GROUND_Y := GROUND_ROW * TILE  # where the ground sits on a flat stretch
const DEPTH := 6         # rows of ground below the surface
const WALL_TOP := -14    # the side walls rise this high, well above anything you can reach
const MAX_DIP := 1.2     # how far, in rows, the ground may drop below the flat line in a valley
const SPAWN_CLEAR_ROWS := 3  # a character needs this many rows of air above the ground to stand

## What a cell is made of. GROUND is the biome's earth, STONE is rock.
const GROUND := 0
const STONE := 1

## The six rows above the ground, top row first, in each chunk. S is stone, . air. Everything here sits
## on the chunk's own ground, so a hill lifts its pillars and platforms with it.
const CHUNKS := [
	# Open ground. There are no platforms: a player who wants a ledge draws a Stone Wall.
	["......", "......", "......", "......", "......", "......", "......", "......"],
]
## The ground is a few long, smooth waves: big hills several tiles high, and slopes gentle enough to walk. Heights are
## in rows relative to the flat line (negative is higher). Their steepest slope is well under 45 degrees.
static var column_heights := PackedFloat32Array()  # the ground's height in each map column, set by build()
## The size in tiles of a generated world, or zero for the arena and the waiting room. A world has no flat ground line:
## its tiles start at (0, 0) and its edges are its own.
static var world_size := Vector2i.ZERO
## A world's sky: the first column of the surface and the row where its ground starts in each column, so the sky is drawn
## over the air above the ground only.
static var sky_xl := 0
static var sky_floor := PackedInt32Array()

## Each level has its own look: the biome's ground tiles, the backdrop behind it and the things standing about on
## the ground (art/props, drawn at their own pixel size).
const BIOMES := {
	"cemetery": {"tiles": "cemetery", "backdrop": "cemetery", "props": ["grave_1", "grave_2", "grave_3", "grave_4", "bush_small", "bush_large", "dead_tree_1", "statue"]},
	"swamp": {"tiles": "swamp", "backdrop": "swamp", "props": ["swamp_grass", "swamp_fern", "swamp_vine", "swamp_grass", "dead_tree_2"]},
	"church": {"tiles": "church", "backdrop": "church", "props": ["balustrade", "church_column", "statue", "barrel"]},
}


## Returns the arena's tiles as {Vector2i cell: material}. Pass a seeded rng for a repeatable arena. Pass heights (one per
## map column, in rows from the flat line) to shape the ground yourself, as the waiting room does.
static func build(rng: RandomNumberGenerator, heights := PackedFloat32Array()) -> Dictionary:
	var cells := {}
	world_size = Vector2i.ZERO
	sky_floor = PackedInt32Array()
	_fill(cells, LEFT_WALL, WALL_TOP, LEFT_WALL, GROUND_ROW + DEPTH, STONE)
	_fill(cells, RIGHT_WALL, WALL_TOP, RIGHT_WALL, GROUND_ROW + DEPTH, STONE)
	column_heights = heights if not heights.is_empty() else _ground_heights(rng)
	for c in range(FIRST_COL, RIGHT_WALL):
		var top := _top_of(c)
		_fill(cells, c, top, c, GROUND_ROW + DEPTH, GROUND)
	for i in CHUNK_COUNT:
		var chunk: Array = CHUNKS[0] if i == 0 or i == CHUNK_COUNT - 1 else CHUNKS[rng.randi() % CHUNKS.size()]
		var mirror := rng.randf() < 0.5
		var x0 := FIRST_COL + i * CHUNK_WIDTH
		for row in chunk.size():
			var line: String = chunk[row]
			if mirror:
				line = line.reverse()
			for col in CHUNK_WIDTH:
				var material := _material_for(line[col])
				if material >= 0:
					var c := x0 + col
					# Each cell sits on the ground of its own column: row chunk.size() - 1 is the cell just above it.
					cells[Vector2i(c, _top_of(c) - 1 - (chunk.size() - 1 - row))] = material
	return cells


## The ground's height in each map column, in rows from the flat line. Long waves make the hills; the ground is flat at
## both ends, so the spawn and the portal stand on level ground.
static func _ground_heights(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var phase_a := rng.randf() * TAU
	var phase_b := rng.randf() * TAU
	var phase_c := rng.randf() * TAU
	var out := PackedFloat32Array()
	var count := RIGHT_WALL - FIRST_COL
	for k in count:
		var x := float(k)
		var raw := -2.4 * sin(x * TAU / 34.0 + phase_a) - 0.8 * sin(x * TAU / 12.0 + phase_b) - 0.3 * sin(x * TAU / 6.0 + phase_c)
		var from_end := float(mini(k, count - 1 - k))
		var ramp := clampf(from_end / 10.0, 0.0, 1.0)
		# Hills can rise well above the line, but a valley dips only a little: the ground never drops to the bottom of the window.
		out.append(minf(raw, MAX_DIP) * ramp * ramp * (3.0 - 2.0 * ramp))  # eased, so the flat ends blend into the hills
	return out


## The row of the ground's top in a map column, rounded to whole tiles.
static func _top_of(col: int) -> int:
	return roundi(GROUND_ROW + column_heights[col - FIRST_COL])


## The row of the solid ground's top edge in a column (the highest ground cell in it).
static func surface_row(cells: Dictionary, col: int) -> int:
	for r in range(GROUND_ROW - 4, GROUND_ROW + DEPTH):
		if cells.get(Vector2i(col, r), -1) == GROUND:
			return r
	return GROUND_ROW


## The world y of the ground's top edge in a column.
static func surface_y(cells: Dictionary, col: int) -> float:
	return surface_row(cells, col) * TILE


## Floor columns where a character can stand: ground with nothing solid in the rows above it.
static func open_columns(cells: Dictionary) -> Array[int]:
	var cols: Array[int] = []
	for c in range(FIRST_COL, RIGHT_WALL):
		var top := surface_row(cells, c)
		var clear := true
		for r in range(top - SPAWN_CLEAR_ROWS, top):
			if cells.has(Vector2i(c, r)):
				clear = false
		if clear:
			cols.append(c)
	return cols


## The world x of the middle of a column.
static func column_x(col: int) -> float:
	return col * TILE + TILE * 0.5


static func column_of(x: float) -> int:
	return floori(x / TILE)


## The left and right edges of the walkable map, in world pixels.
static func left_edge() -> float:
	if world_size.x > 0:
		return 2 * TILE
	return (LEFT_WALL + 1) * TILE


static func right_edge() -> float:
	if world_size.x > 0:
		return (world_size.x - 2) * TILE
	return RIGHT_WALL * TILE


static func _material_for(ch: String) -> int:
	match ch:
		"S":
			return STONE
	return -1


static func _fill(cells: Dictionary, c0: int, r0: int, c1: int, r1: int, material: int) -> void:
	for c in range(c0, c1 + 1):
		for r in range(r0, r1 + 1):
			cells[Vector2i(c, r)] = material

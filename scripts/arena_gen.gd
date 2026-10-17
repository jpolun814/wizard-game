class_name ArenaGen
extends RefCounted

## Builds a random arena out of chunks. Every chunk sits on the same ground line, so any order of chunks joins up
## into something walkable. Chunks vary the platforms, pillars and mounds above it.

const TILE := 32
const CHUNK_WIDTH := 6
const CHUNK_COUNT := 12  # the map is this many chunks wide
const FIRST_COL := -36   # first floor column, so the map is centred on column 0
const LEFT_WALL := FIRST_COL - 1
const RIGHT_WALL := FIRST_COL + CHUNK_WIDTH * CHUNK_COUNT
const GROUND_ROW := 6    # the row of the ground surface; its top edge is GROUND_Y
const GROUND_Y := GROUND_ROW * TILE
const DEPTH := 6         # rows of ground below the surface
const WALL_TOP := -14    # the side walls rise this high, well above anything you can reach
const SPAWN_CLEAR_ROWS := 3  # a character needs this many rows of air above the ground to stand

## What a cell is made of. GROUND is the biome's earth, STONE is rock, PLATFORM is a ledge you can jump up through.
const GROUND := 0
const STONE := 1
const PLATFORM := 2

## The eight rows above the ground, top row first. S is stone, P a platform, . air.
## Platforms sit four rows up: high enough to walk and cast underneath, low enough for a jump to reach.
const CHUNKS := [
	# Open ground.
	["......", "......", "......", "......", "......", "......", "......", "......"],
	# One platform to jump onto.
	["......", "......", "......", "......", ".PPPP.", "......", "......", "......"],
	# A stone pillar two rows tall. Enemies can hop it, and it blocks their shots.
	["......", "......", "......", "......", "......", "......", "..SS..", "..SS.."],
	# A low mound of stone.
	["......", "......", "......", "......", "......", "......", "......", ".SSSS."],
	# Platforms at both edges, which join up with the next chunk's.
	["......", "......", "......", "......", "PP..PP", "......", "......", "......"],
	# A high perch, reached from a lower ledge beside it.
	["......", "..PPP.", "......", "......", "PP....", "......", "......", "......"],
	# A stone step with a ledge above it.
	["......", "......", "......", "......", "...PPP", "......", "......", "SS...."],
]

## Each level has its own look: the biome's ground tiles, the backdrop behind it and the things standing about on
## the ground (art/props, drawn at their own pixel size).
const BIOMES := {
	"cemetery": {"tiles": "cemetery", "backdrop": "cemetery", "props": ["grave_1", "grave_2", "grave_3", "grave_4", "bush_small", "bush_large", "dead_tree_1", "statue"]},
	"swamp": {"tiles": "swamp", "backdrop": "swamp", "props": ["swamp_grass", "swamp_fern", "swamp_vine", "swamp_grass", "dead_tree_2"]},
	"church": {"tiles": "church", "backdrop": "church", "props": ["balustrade", "church_column", "statue", "barrel"]},
}


## Returns the arena's tiles as {Vector2i cell: material}. Pass a seeded rng for a repeatable arena.
static func build(rng: RandomNumberGenerator) -> Dictionary:
	var cells := {}
	_fill(cells, LEFT_WALL, WALL_TOP, LEFT_WALL, GROUND_ROW + DEPTH, STONE)
	_fill(cells, RIGHT_WALL, WALL_TOP, RIGHT_WALL, GROUND_ROW + DEPTH, STONE)
	_fill(cells, FIRST_COL, GROUND_ROW, RIGHT_WALL - 1, GROUND_ROW + DEPTH, GROUND)
	# The chunks at each end stay open, so nobody spawns walled in against the side of the map.
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
					cells[Vector2i(x0 + col, GROUND_ROW - chunk.size() + row)] = material
	return cells


## Floor columns where a character can stand: ground with nothing solid in the rows above it.
static func open_columns(cells: Dictionary) -> Array[int]:
	var cols: Array[int] = []
	for c in range(FIRST_COL, RIGHT_WALL):
		var clear := true
		for r in range(GROUND_ROW - SPAWN_CLEAR_ROWS, GROUND_ROW):
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
	return (LEFT_WALL + 1) * TILE


static func right_edge() -> float:
	return RIGHT_WALL * TILE


static func _material_for(ch: String) -> int:
	match ch:
		"S":
			return STONE
		"P":
			return PLATFORM
	return -1


static func _fill(cells: Dictionary, c0: int, r0: int, c1: int, r1: int, material: int) -> void:
	for c in range(c0, c1 + 1):
		for r in range(r0, r1 + 1):
			cells[Vector2i(c, r)] = material

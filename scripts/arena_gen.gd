class_name ArenaGen
extends RefCounted

## Builds a random arena out of chunks. Every chunk has the same ground line, so any order of
## chunks joins up into something walkable. Chunks vary the platforms, pillars and steps above it.

const CHUNK_WIDTH := 12
const CHUNK_COUNT := 12  # the map is this many chunks wide
const FIRST_COL := -72   # first floor column, so the map is centred on column 0
const LEFT_WALL := FIRST_COL - 1
const RIGHT_WALL := FIRST_COL + CHUNK_WIDTH * CHUNK_COUNT
const GROUND_ROW := 12
const TOP_ROW := 6       # the first row a chunk describes; each chunk is 10 rows tall

const GRASS := 0
const DIRT := 1
const STONE := 2
const WOOD := 3

## Each chunk is 10 rows (rows 6 to 15). Rows 0 to 5 are air except for the layout;
## row 6 is the ground surface. G grass, D dirt, S stone, W wood, . air.
const CHUNKS := [
	# Open ground.
	["............", "............", "............", "............", "............",
		"............", "GGGGGGGGGGGG", "DDDDDDDDDDDD", "DDDDDDDDDDDD", "DDDDDDDDDDDD"],
	# One wooden platform to jump onto. High enough to walk and cast underneath.
	["............", "...WWWWWW...", "............", "............", "............",
		"............", "GGGGGGGGGGGG", "DDDDDDDDDDDD", "DDDDDDDDDDDD", "DDDDDDDDDDDD"],
	# A stone pillar that blocks the way.
	["............", "............", "............", ".....SS.....", ".....SS.....",
		".....SS.....", "GGGGGGGGGGGG", "DDDDDDDDDDDD", "DDDDDDDDDDDD", "DDDDDDDDDDDD"],
	# Stone steps climbing up.
	["............", "............", "............", "............", "....SSS.....",
		"...SSSSS....", "GGGGGGGGGGGG", "DDDDDDDDDDDD", "DDDDDDDDDDDD", "DDDDDDDDDDDD"],
	# Two platforms, one on each side, with room to walk and cast underneath.
	["............", "..WWWW..WWWW", "............", "............", "............",
		"............", "GGGGGGGGGGGG", "DDDDDDDDDDDD", "DDDDDDDDDDDD", "DDDDDDDDDDDD"],
]


## Returns the arena's tiles as {Vector2i cell: tile index}. Pass a seeded rng for a repeatable arena.
static func build(rng: RandomNumberGenerator) -> Dictionary:
	var cells := {}
	var right_wall := RIGHT_WALL
	_fill(cells, LEFT_WALL, -8, LEFT_WALL, 15, STONE)
	_fill(cells, right_wall, -8, right_wall, 15, STONE)
	for i in CHUNK_COUNT:
		var chunk: Array = CHUNKS[rng.randi() % CHUNKS.size()]
		var mirror := rng.randf() < 0.5
		var x0 := FIRST_COL + i * CHUNK_WIDTH
		for row in chunk.size():
			var line: String = chunk[row]
			if mirror:
				line = _reverse(line)
			for col in CHUNK_WIDTH:
				var tile := _tile_for(line.substr(col, 1))
				if tile >= 0:
					cells[Vector2i(x0 + col, TOP_ROW + row)] = tile
	return cells


## Columns where a character can stand on open floor (grass with air above it).
static func open_columns(cells: Dictionary) -> Array[int]:
	var cols: Array[int] = []
	for c in range(FIRST_COL, FIRST_COL + CHUNK_WIDTH * CHUNK_COUNT):
		if cells.get(Vector2i(c, GROUND_ROW)) == GRASS and not cells.has(Vector2i(c, GROUND_ROW - 1)):
			cols.append(c)
	return cols


static func _tile_for(ch: String) -> int:
	match ch:
		"G":
			return GRASS
		"D":
			return DIRT
		"S":
			return STONE
		"W":
			return WOOD
	return -1


static func _reverse(s: String) -> String:
	var out := ""
	for i in s.length():
		out = s.substr(i, 1) + out
	return out


static func _fill(cells: Dictionary, c0: int, r0: int, c1: int, r1: int, tile: int) -> void:
	for c in range(c0, c1 + 1):
		for r in range(r0, r1 + 1):
			cells[Vector2i(c, r)] = tile

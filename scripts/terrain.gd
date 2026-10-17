class_name Terrain
extends Node2D

## The arena's ground, drawn from ansimuz's GothicVania tiles and made solid. Each cell picks the tile piece that fits
## its neighbours (a top edge, a corner, a ledge end, the deep earth further down), so the ground reads as shapes
## rather than a grid. Every piece is pixel art at the same size as the characters.
## Collision is built from long strips, one per run of solid cells in a row, so characters slide along the ground
## without catching on the seams between tiles. Platforms are one-way: you jump up through them and land on top, and
## S drops you back through. They are drawn as wooden walkways so they never look like solid ground.

const ATLAS_TILE := 64   # a tile's size in the atlas image
const ATLAS_PAD := 4     # the repeated border around each tile in the atlas
const ATLAS_CELL := ATLAS_TILE + ATLAS_PAD * 2
const PLATFORM_LAYER := 16  # physics layer 5
const PROP_CHANCE := 0.22   # how many open ground columns get a decoration

## Atlas positions of each tile piece, as laid out by tools/prepare_gothic_art.py.
const TOP_LEFT := Vector2i(0, 0)
const TOP := Vector2i(1, 0)
const TOP_RIGHT := Vector2i(2, 0)
const SINGLE := Vector2i(3, 0)
const LEFT := Vector2i(0, 1)
const CENTER := Vector2i(1, 1)
const RIGHT := Vector2i(2, 1)
const LEDGE_LEFT := Vector2i(3, 1)
const BOTTOM_LEFT := Vector2i(0, 2)
const BOTTOM := Vector2i(1, 2)
const BOTTOM_RIGHT := Vector2i(2, 2)
const LEDGE_MIDDLE := Vector2i(3, 2)
const COLUMN_TOP := Vector2i(0, 3)
const COLUMN_MIDDLE := Vector2i(1, 3)
const COLUMN_BOTTOM := Vector2i(2, 3)
const LEDGE_RIGHT := Vector2i(3, 3)
const DEEP_LEFT := Vector2i(0, 4)
const DEEP := Vector2i(1, 4)
const DEEP_RIGHT := Vector2i(2, 4)
const DEEP_SINGLE := Vector2i(3, 4)
const PLANK_WIDTH := 16  # one wooden plank of a walkway; two span a cell

var cells := {}
var biome := "cemetery"
var _textures := {}  # material -> atlas texture


## Builds everything from the generated cells. Call once, after adding the terrain to the tree.
func build(map_cells: Dictionary, biome_name: String, rng: RandomNumberGenerator) -> void:
	cells = map_cells
	biome = biome_name
	var tiles: String = ArenaGen.BIOMES[biome]["tiles"]
	_textures[ArenaGen.GROUND] = load("res://art/tiles/%s.png" % tiles)
	_textures[ArenaGen.PLATFORM] = load("res://art/props/plank.png")
	_textures[ArenaGen.STONE] = load("res://art/tiles/stone.png")
	_build_collision()
	_scatter_props(rng)
	queue_redraw()


func _draw() -> void:
	for cell in cells:
		var material: int = cells[cell]
		if material == ArenaGen.PLATFORM:
			# Wooden planks, flush with the cell's top where you stand.
			var plank: Texture2D = _textures[material]
			for i in ArenaGen.TILE / PLANK_WIDTH:
				draw_texture(plank, Vector2(cell) * ArenaGen.TILE + Vector2(i * PLANK_WIDTH, 0))
			continue
		var piece := _piece_for(cell, material)
		var source := Rect2(Vector2(piece * ATLAS_CELL + Vector2i(ATLAS_PAD, ATLAS_PAD)), Vector2(ATLAS_TILE, ATLAS_TILE))
		draw_texture_rect_region(_textures[material], Rect2(Vector2(cell) * ArenaGen.TILE, Vector2.ONE * ArenaGen.TILE), source)


## Which tile piece a cell shows. Cells only join up with cells of the same material, so a stone pillar
## standing on the ground still gets its own rounded top and bottom.
func _piece_for(cell: Vector2i, material: int) -> Vector2i:
	var up := _same(cell + Vector2i.UP, material)
	var down := _same(cell + Vector2i.DOWN, material)
	var left := _same(cell + Vector2i.LEFT, material)
	var right := _same(cell + Vector2i.RIGHT, material)
	# The ground runs off the bottom of the map, and the side walls run off the top, so those edges never round off.
	if material == ArenaGen.GROUND and cell.y >= ArenaGen.GROUND_ROW + ArenaGen.DEPTH:
		down = true
	if cell.x == ArenaGen.LEFT_WALL or cell.x == ArenaGen.RIGHT_WALL:
		up = up or cell.y == ArenaGen.WALL_TOP
		down = true
		left = true
		right = true
	if material == ArenaGen.GROUND:
		# The ground meets the walls at both ends of the map, so it carries on under them.
		left = left or cells.has(cell + Vector2i.LEFT)
		right = right or cells.has(cell + Vector2i.RIGHT)
	if not up and not down:
		if not left and not right:
			return SINGLE
		if not left:
			return LEDGE_LEFT
		if not right:
			return LEDGE_RIGHT
		return LEDGE_MIDDLE
	if not left and not right:
		if not up:
			return COLUMN_TOP
		if not down:
			return COLUMN_BOTTOM
		return DEEP_SINGLE if _same(cell + Vector2i.UP * 2, material) else COLUMN_MIDDLE
	var row := 0 if not up else (2 if not down else 1)
	var col := 0 if not left else (2 if not right else 1)
	# Two or more cells under the surface is the plain deep earth.
	if row == 1 and _same(cell + Vector2i.UP * 2, material):
		row = 4
	return Vector2i(col, row)


func _same(cell: Vector2i, material: int) -> bool:
	return cells.get(cell, -1) == material


## One static body for solid ground and one for platforms. Each row's runs of cells become single strips.
func _build_collision() -> void:
	var solid := StaticBody2D.new()
	solid.collision_layer = 1
	add_child(solid)
	var ledges := StaticBody2D.new()
	ledges.collision_layer = PLATFORM_LAYER
	add_child(ledges)
	var rows := {}
	for cell in cells:
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell.x)
	for row in rows:
		var cols: Array = rows[row]
		cols.sort()
		var start: int = cols[0]
		for i in range(1, cols.size() + 1):
			# A strip ends at a gap, at the end of the row, or where platform meets solid ground.
			var ends: bool = i == cols.size() or cols[i] != cols[i - 1] + 1 \
					or _is_platform(Vector2i(cols[i], row)) != _is_platform(Vector2i(start, row))
			if ends:
				var ledge := _is_platform(Vector2i(start, row))
				_add_strip(ledges if ledge else solid, start, cols[i - 1], row, ledge)
				if i < cols.size():
					start = cols[i]


func _is_platform(cell: Vector2i) -> bool:
	return cells.get(cell, -1) == ArenaGen.PLATFORM


func _add_strip(body: StaticBody2D, c0: int, c1: int, row: int, one_way: bool) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var t := float(ArenaGen.TILE)
	if one_way:
		# A platform is only solid along its top, so a character standing under it is never pushed through.
		rect.size = Vector2((c1 - c0 + 1) * t, 10.0)
		shape.position = Vector2((c0 + c1 + 1) * t * 0.5, row * t + 5.0)
		shape.one_way_collision = true
		shape.one_way_collision_margin = 6.0
	else:
		rect.size = Vector2((c1 - c0 + 1) * t, t)
		shape.position = Vector2((c0 + c1 + 1) * t * 0.5, (row + 0.5) * t)
	shape.shape = rect
	body.add_child(shape)


## Gravestones, dead trees, statues and weeds along the open ground, behind the characters. They are only for
## looks, and drawn at their own pixel size like everything else.
func _scatter_props(rng: RandomNumberGenerator) -> void:
	var props: Array = ArenaGen.BIOMES[biome]["props"]
	for c in ArenaGen.open_columns(cells):
		if rng.randf() > PROP_CHANCE:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = load("res://art/props/%s.png" % props[rng.randi() % props.size()])
		sprite.centered = false
		var size := sprite.texture.get_size()
		sprite.flip_h = rng.randf() < 0.5
		# Stand the prop on the ground: its bottom edge sits a pixel or two into the surface.
		sprite.position = Vector2(roundf(ArenaGen.column_x(c) - size.x * 0.5 + rng.randf_range(-6.0, 6.0)), ArenaGen.GROUND_Y - size.y + 3.0)
		sprite.z_index = -1
		add_child(sprite)

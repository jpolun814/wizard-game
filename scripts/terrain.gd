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

## True for a generated world. Its rock is drawn and made solid by following the edges of the tiles smoothly (see
## _build_contour), so a staircase of tiles is a slope, rather than the arena's one smooth surface over a row of heights.
var tiled := false
## The ground is about to change in a rectangle (a pit is being dug), and then has changed. Pools listen, so they can flow into the new hollow.
signal about_to_change(area: Rect2)
signal changed(area: Rect2)
var air_loops: Array = []  # the traced outlines of the open air, in world pixels; pools are drawn only inside them
var cells: Variant = {}  # a Dictionary of cells (the waiting room) or a TileGrid (a world)
var biome := "cemetery"
var _textures := {}  # material -> atlas texture
const GRASS_BAND := 24.0  # how deep the grass along the top of the ground is, in world pixels
const EDGE_STEP := 8.0  # pixels between two of the waiting room's ground heights: fine enough for a pit to keep the shape that was drawn
var _edges := PackedFloat32Array()  # the ground's top edge height every EDGE_STEP pixels, left to right
var earth_tiles := "cemetery"  # the tile set of the world's first biome, which names its earth and its grassy lip
var snow_lip: Texture2D   # the snow along the ridges of the high ground
var snow_pack: Texture2D  # and the snow over its rock
var stone_earth: Texture2D  # the rock of the waiting room's slabs and walls, made like the ground's; kept here because a texture loaded in _draw is freed before it is drawn
var lip: Texture2D  # the grassy lip along every surface, kept here because a texture loaded in _draw is freed before it is drawn
var earth_texture: Texture2D  # the biome's plain earth, which repeats under the surface


## Builds everything from the generated cells. Call once, after adding the terrain to the tree. Props are the decorations scattered
## over open ground.
func build(map_cells: Variant, biome_name: String, rng: RandomNumberGenerator, props := true) -> void:
	cells = map_cells
	biome = biome_name
	var tiles: String = ArenaGen.BIOMES[biome]["tiles"]
	_textures[ArenaGen.GROUND] = load("res://art/tiles/%s.png" % tiles)
	_textures[ArenaGen.STONE] = load("res://art/tiles/stone.png")
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	earth_tiles = ArenaGen.biome_spans[0]["tiles"] if tiled and not ArenaGen.biome_spans.is_empty() else tiles
	lip = load("res://art/tiles/lip_%s.png" % earth_tiles)
	earth_texture = load("res://art/tiles/earth_%s.png" % earth_tiles)  # stones with dark seams, made for every biome by tools/prepare_earth.py
	stone_earth = earth_texture  # the waiting room's slabs are the same rock as its ground
	if tiled:
		_build_contour()
	else:
		_build_edges()
	_build_collision()
	if not tiled and props:
		_scatter_props(rng)
	queue_redraw()


## The ground's top edge: one height at each column boundary, the average of the columns either side. Drawing and
## collision both follow these edges, so a slope between two columns is a straight, smooth ramp.
func _build_edges() -> void:
	var heights := PackedFloat32Array()
	for h in ArenaGen.column_heights:
		heights.append((ArenaGen.GROUND_ROW + h) * float(ArenaGen.TILE))  # the smooth heights, not the rounded ones
	var corners := PackedFloat32Array()  # one height at each column boundary
	corners.append(heights[0])
	for k in range(1, heights.size()):
		corners.append((heights[k - 1] + heights[k]) * 0.5)
	corners.append(heights[heights.size() - 1])
	var per_tile := roundi(ArenaGen.TILE / EDGE_STEP)
	_edges.clear()
	for k in range(corners.size() - 1):
		for s in per_tile:
			_edges.append(lerpf(corners[k], corners[k + 1], float(s) / per_tile))
	_edges.append(corners[corners.size() - 1])


func _draw() -> void:
	if not tiled:
		_draw_ground()
	if tiled:
		return  # a world's rock is drawn along its outlines, see _build_contour
	for cell in cells:
		var material: int = cells[cell]
		if material == ArenaGen.GROUND:
			continue  # the ground is drawn as one smooth surface, see _draw_ground
		if material == ArenaGen.STONE:
			_draw_stone_cell(cell)
			continue
		var piece := _piece_for(cell, material)
		var source := Rect2(Vector2(piece * ATLAS_CELL + Vector2i(ATLAS_PAD, ATLAS_PAD)), Vector2(ATLAS_TILE, ATLAS_TILE))
		draw_texture_rect_region(_textures[material], Rect2(Vector2(cell) * ArenaGen.TILE, Vector2.ONE * ArenaGen.TILE), source)


## A cell of the waiting room's rock (a slab overhead, the walls): the same stones as the ground, with a dark rim on every side that faces the open and a lit
## edge on top, so it reads as rock and not as a floating tile.
func _draw_stone_cell(cell: Vector2i) -> void:
	var t := float(ArenaGen.TILE)
	var at := Vector2(cell) * t
	var uvs := PackedVector2Array()
	var quad := PackedVector2Array([at, at + Vector2(t, 0.0), at + Vector2(t, t), at + Vector2(0.0, t)])
	for p in quad:
		uvs.append(p / stone_earth.get_size())
	draw_polygon(quad, PackedColorArray([Color.WHITE]), uvs, stone_earth)
	var rim := Color("#0d0916")
	if not _same(cell + Vector2i.UP, ArenaGen.STONE):
		draw_rect(Rect2(at, Vector2(t, 3.0)), Color("#6a5f8c"))  # lit top
		draw_rect(Rect2(at + Vector2(0.0, 3.0), Vector2(t, 3.0)), rim)
	if not _same(cell + Vector2i.DOWN, ArenaGen.STONE):
		draw_rect(Rect2(at + Vector2(0.0, t - 4.0), Vector2(t, 4.0)), rim)
	if not _same(cell + Vector2i.LEFT, ArenaGen.STONE):
		draw_rect(Rect2(at, Vector2(4.0, t)), rim)
	if not _same(cell + Vector2i.RIGHT, ArenaGen.STONE):
		draw_rect(Rect2(at + Vector2(t - 4.0, 0.0), Vector2(4.0, t)), rim)


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
	if cell.x == ArenaGen.LEFT_WALL or cell.x == ArenaGen.right_wall:
		up = up or cell.y == ArenaGen.WALL_TOP
		down = true
		left = true
		right = true
	if material == ArenaGen.GROUND:
		# The ground meets the walls at both ends of the map, so it carries on under them.
		# A neighbour that has ground just under this row joins on too: on a slope the next column's top is one row lower,
		# and without this every step would get a rounded end and read as a separate block.
		left = left or cells.has(cell + Vector2i.LEFT) or cells.has(cell + Vector2i.LEFT + Vector2i.DOWN)
		right = right or cells.has(cell + Vector2i.RIGHT) or cells.has(cell + Vector2i.RIGHT + Vector2i.DOWN)
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


## The ground: earth filling everything under the surface, with a band of grass along the top, both following the edges.
func _draw_ground() -> void:
	var top := PackedVector2Array()
	for k in _edges.size():
		top.append(Vector2(ArenaGen.FIRST_COL * ArenaGen.TILE + k * EDGE_STEP, _edges[k]))
	var bottom := (ArenaGen.GROUND_ROW + ArenaGen.DEPTH + 1) * float(ArenaGen.TILE)
	var fill := PackedVector2Array(top)
	fill.append(Vector2(top[top.size() - 1].x, bottom))
	fill.append(Vector2(top[0].x, bottom))
	var fill_uvs := PackedVector2Array()
	for p in fill:
		fill_uvs.append(p / earth_texture.get_size())
	draw_polygon(fill, PackedColorArray([Color("#2a1f1a")]))  # an opaque base, so the earth is never see-through
	draw_polygon(fill, PackedColorArray([Color.WHITE]), fill_uvs, earth_texture)
	var band := PackedVector2Array(top)
	var uvs := PackedVector2Array()
	for p in top:
		uvs.append(Vector2(p.x / lip.get_width(), 0.0))
	for i in range(top.size() - 1, -1, -1):
		band.append(top[i] + Vector2(0, GRASS_BAND))
		uvs.append(Vector2(top[i].x / lip.get_width(), GRASS_BAND / lip.get_height()))
	draw_polygon(band, PackedColorArray([Color.WHITE]), uvs, lip)


## One static body for solid stone. Stone's runs of cells become single strips. The ground is a row of sloped blocks under
## its smooth top, one per column, so walking up a slope never catches on a step.
func _build_collision() -> void:
	if tiled:
		return  # a world's rock is solid along its outlines, see _build_contour
	var solid := StaticBody2D.new()
	solid.collision_layer = 1
	add_child(solid)
	_solid = solid
	var bottom := (ArenaGen.GROUND_ROW + ArenaGen.DEPTH + 1) * float(ArenaGen.TILE)
	for k in range(_edges.size() - 1):
		var x0 := ArenaGen.FIRST_COL * float(ArenaGen.TILE) + k * EDGE_STEP
		var x1 := x0 + EDGE_STEP
		var block := ConvexPolygonShape2D.new()
		block.points = PackedVector2Array([Vector2(x0, _edges[k]), Vector2(x1, _edges[k + 1]), Vector2(x1, bottom), Vector2(x0, bottom)])
		var shape := CollisionShape2D.new()
		shape.shape = block
		solid.add_child(shape)
	var rows := {}
	for cell in cells:
		if cells[cell] == ArenaGen.GROUND:
			continue  # the ground's blocks are above
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell.x)
	for row in rows:
		var cols: Array = rows[row]
		cols.sort()
		var start: int = cols[0]
		for i in range(1, cols.size() + 1):
			if i == cols.size() or cols[i] != cols[i - 1] + 1:  # a strip ends at a gap or at the end of the row
				_add_strip(solid, start, cols[i - 1], row)
				if i < cols.size():
					start = cols[i]


func _add_strip(body: StaticBody2D, c0: int, c1: int, row: int) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var t := float(ArenaGen.TILE)
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
		var size := sprite.texture.get_size()
		sprite.flip_h = rng.randf() < 0.5
		# Stand the prop on the slope it is on: its two feet sit on the smooth ground either side of it, and it is tilted
		# to match, with its bottom edge three pixels into the surface so no part of it floats above the ground.
		var x := roundf(ArenaGen.column_x(c) + rng.randf_range(-6.0, 6.0))
		var left := _ground_y(x - size.x * 0.5)
		var right := _ground_y(x + size.x * 0.5)
		var lean := atan2(right - left, size.x)
		var middle := Vector2(x, (left + right) * 0.5)
		sprite.rotation = lean
		sprite.position = middle + Vector2(0, 3.0) - Vector2(0, size.y * 0.5).rotated(lean)
		sprite.z_index = -1
		add_child(sprite)


## The height of the smooth ground at an x position, as the terrain draws it.
func _ground_y(x: float) -> float:
	var k := (x - ArenaGen.FIRST_COL * float(ArenaGen.TILE)) / EDGE_STEP
	var i := clampi(int(floor(k)), 0, _edges.size() - 2)
	return lerpf(_edges[i], _edges[i + 1], clampf(k - i, 0.0, 1.0))


const HALL_CHUNK := 40  # columns of a castle's inside painted as one piece

var _rock_world: RockWorld
var _tile_state := {}  # tile -> 1 if it and all its neighbours are rock, 0 if all are air, 2 if an outline runs near it (see solid_at)
var _changed: Array[Rect2] = []  # where pits have been dug, so the tiles no longer tell what is ground there
var _solid: StaticBody2D  # the waiting room's solid ground, made again when a pit is dug


## The height of the drawn ground at an x, near a row's height: the outline is rounded off, so it is not the same as the row's own top. The
## height given back is the one of the outline's own that lies closest to y (within a couple of tiles), or y itself where there is none.
func surface_near(x: float, y: float) -> float:
	var best := y
	var gap := float(ArenaGen.TILE) * 2.0
	for loop: PackedVector2Array in air_loops:
		for k in loop.size():
			var a := loop[k]
			var b := loop[(k + 1) % loop.size()]
			if (a.x <= x) == (b.x <= x) or a.x == b.x:
				continue
			var at := a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x)
			if absf(at - y) < gap:
				gap = absf(at - y)
				best = at
	return best


## Turns the world's solid tiles into rock with smooth edges, the way the waiting room ground is one smooth line: the
## outlines of the caves are traced and rounded off, then drawn (with a grass band along every surface facing up) and made
## solid a chunk at a time, see RockWorld. The castle is stone on top of that, drawn in brick.
func _build_contour() -> void:
	var size := ArenaGen.world_size
	var t := float(ArenaGen.TILE)
	var loops := Contour.trace(cells, false)
	var rock := CaveDraw.new()
	rock.kind = "rock"
	rock.z_index = -11
	rock.earth = earth_texture
	rock.world = Vector2(size) * t
	rock.sky = _sky_polygon()
	add_child(rock)
	air_loops = loops.filter(func(points: PackedVector2Array) -> bool: return Contour.area(points) < 0.0)
	_rock_world = RockWorld.new()
	_rock_world.earth = earth_texture
	_rock_world.grass_texture = lip
	var snow_spans := []
	for span: Dictionary in ArenaGen.biome_spans:  # each biome's grass is cut from its own tiles
		var entry := {"a": span["a"] * t, "b": (span["b"] + 1) * t, "texture": load("res://art/tiles/lip_%s.png" % span["tiles"])}
		if span.has("snow"):  # the high ground of a biome is snowy
			snow_lip = load("res://art/tiles/lip_snow.png")  # drifts along the ridges, and a pack of snow over the high rock (see tools/prepare_earth.py)
			snow_pack = load("res://art/tiles/earth_snow.png")
			entry["high"] = snow_lip
			entry["line"] = float(WorldGraph.SURFACE_ROW - span["snow"]) * t
			snow_spans.append({"a": entry["a"], "b": entry["b"], "line": entry["line"], "texture": snow_pack})
		_rock_world.grass_spans.append(entry)
	rock.snow = snow_spans
	_rock_world.sky = _sky_polygon()
	add_child(_rock_world)
	_rock_world.setup(loops)
	if not ArenaGen.castle_hall.is_empty():
		var last_chunk := 0
		for tiles: Rect2i in ArenaGen.castle_hall:
			last_chunk = maxi(last_chunk, tiles.position.x / HALL_CHUNK)
		for chunk in last_chunk + 1:  # the dark inside of the castle, over the sky and under the brick: a piece at a time, so the pieces off screen are not drawn
			var inside := CaveDraw.new()
			inside.z_index = -10
			inside.kind = "hall"
			inside.chunk = chunk
			inside.earth = earth_texture
			add_child(inside)
	var stone_loops := Contour.trace(cells, true)
	if not stone_loops.is_empty():
		var bricks := CaveDraw.new()  # the castle: the rough stone of the ground, with dark windows
		bricks.z_index = 0  # over the rock's own front, which is drawn over the earth under it
		bricks.kind = "solid"
		bricks.earth = earth_texture
		bricks.loops = stone_loops
		add_child(bricks)
		_rock_world.dug.connect(bricks.cut)  # a pit dug in the castle takes the brick away with the stone


## Digs a pit into the open ground at a point (see RockWorld.dig). False when this ground cannot be dug.
## How deep a pit is at a place across it, as a share of its depth: `u` is 0 at its left side and 1 at its right. A pit with no profile has steep
## walls and a flat floor; one with a profile (see Sinkhole.profile_of) is the shape of what was drawn.
static func pit_share(u: float, profile: PackedFloat32Array) -> float:
	if profile.is_empty():
		return clampf(minf(u, 1.0 - u) * 5.0, 0.0, 1.0)
	var at := clampf(u, 0.0, 1.0) * (profile.size() - 1)
	var i := mini(int(at), profile.size() - 2)
	return lerpf(profile[i], profile[i + 1], at - i)


func dig(at: Vector2, half_width: float, depth: float, profile := PackedFloat32Array()) -> bool:
	var area := Rect2(at - Vector2(half_width + 16.0, 48.0), Vector2(half_width * 2.0 + 32.0, depth + 112.0))
	if tiled:
		if _rock_world == null:
			return false
		about_to_change.emit(area)
		var dug := _rock_world.dig(at, half_width, depth, profile)
		if dug:
			_changed.append(area)
			changed.emit(area)
		return dug
	if _edges.is_empty() or absf(at.y - _ground_y(at.x)) > 48.0:
		return false
	about_to_change.emit(area)
	# The waiting room's ground is one line of heights: sink the columns under the pit, steep at the sides and flat at the bottom.
	var bottom := (ArenaGen.GROUND_ROW + ArenaGen.DEPTH) * float(ArenaGen.TILE) - 64.0
	for k in _edges.size():
		var u := (ArenaGen.FIRST_COL * float(ArenaGen.TILE) + k * EDGE_STEP - (at.x - half_width)) / (half_width * 2.0)
		if u < 0.0 or u > 1.0:
			continue
		_edges[k] = minf(_edges[k] + depth * pit_share(u, profile), bottom)
	_solid.queue_free()
	_build_collision()
	queue_redraw()
	changed.emit(area)
	return true


## The outlines of open air that come near a rectangle of the world, or none where the ground has no outlines of its own (the waiting room).
func air_in(area: Rect2) -> Array:
	return _rock_world.air_in(area) if tiled and _rock_world != null else []


## True where a point is inside the ground (or stone), whatever the ground is made of. Liquid asks this to know where it can flow.
## True where a pit has been dug (its box, not only its hole): there the tiles no longer say what is ground, and `solid_at` must be asked.
func is_dug(point: Vector2) -> bool:
	for area: Rect2 in _changed:
		if area.has_point(point):
			return true
	return false


func solid_at(point: Vector2) -> bool:
	if tiled:
		if _rock_world == null:
			return false
		# Far from any outline the tiles say it at once; only a point beside an edge needs the smoothed outlines.
		var grid: TileGrid = cells
		var tile := Vector2i(floori(point.x / ArenaGen.TILE), floori(point.y / ArenaGen.TILE))
		if not grid.inside(tile - Vector2i.ONE) or not grid.inside(tile + Vector2i.ONE):
			return _rock_world.solid_at(point)
		for area: Rect2 in _changed:
			if area.has_point(point):
				return _rock_world.solid_at(point)
		var state: int = _tile_state.get(tile, -1)
		if state < 0:
			var solid_tiles := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if grid.has(tile + Vector2i(dx, dy)):
						solid_tiles += 1
			state = 1 if solid_tiles == 9 else (0 if solid_tiles == 0 else 2)
			_tile_state[tile] = state
		if state == 2:
			return _rock_world.solid_at(point)
		return state == 1
	if not _edges.is_empty() and point.y > _ground_y(point.x):
		return true
	return cells.get(Vector2i(floori(point.x / ArenaGen.TILE), floori(point.y / ArenaGen.TILE)), -1) == ArenaGen.STONE


## Draws the rock round these world positions, and frees what is far from all of them. at_once makes it all now.
func watch(positions: Array[Vector2], at_once := false) -> void:
	if _rock_world != null:
		_rock_world.watch(positions, at_once)


## The sky: everything above the surface's ground, from the top of the world, a little under the ground line so it never
## leaves a gap along it.
func _sky_polygon() -> PackedVector2Array:
	var polygon := PackedVector2Array()
	if ArenaGen.sky_floor.is_empty():
		return polygon
	var t := float(ArenaGen.TILE)
	var count := ArenaGen.sky_floor.size()
	polygon.append(Vector2(ArenaGen.sky_xl * t, 0.0))
	polygon.append(Vector2((ArenaGen.sky_xl + count) * t, 0.0))
	for i in range(count - 1, -1, -1):
		polygon.append(Vector2((ArenaGen.sky_xl + i + 0.5) * t, ArenaGen.sky_floor[i] * t + 8.0))
	return polygon



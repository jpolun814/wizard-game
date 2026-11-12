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
const SNOW_FADE := 640.0  # pixels over which snow thins out below the snow line
const GRASS_BAND := 24.0  # how deep the grass along the top of the ground is, in world pixels
const EDGE_STEP := 8.0  # pixels between two of the waiting room's ground heights: fine enough for a pit to keep the shape that was drawn
var _edges := PackedFloat32Array()  # the ground's top edge height every EDGE_STEP pixels, left to right
var _first_edges := PackedFloat32Array()  # the same, as built, before any pit was dug (see mend)
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
	_first_edges = _edges.duplicate()


## A repeating texture cut from one piece of the biome's atlas.
func _piece_texture(atlas: Texture2D, piece: Vector2i) -> Texture2D:
	var image := atlas.get_image()
	if image.is_compressed():
		image.decompress()
	var source := Rect2i(piece * ATLAS_CELL + Vector2i(ATLAS_PAD, ATLAS_PAD), Vector2i(ATLAS_TILE, ATLAS_TILE))
	return ImageTexture.create_from_image(image.get_region(source))


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


const RIM := Color("#0d0916")
const WALL := Color("#3a2e50")
const STONE_FILL := Color(0.25, 0.16, 0.36)
const HALL := Color(0.12, 0.11, 0.18)
const BLEED := 14.0  # how far the painting of a room runs under the stone round it
const HALL_TILES := 9  # rows the hall's picture is stretched over: the hall's full height
const STRIP := 640.0  # how wide the strips are that stone is cut into round a room
const WINDOW_AREA_MOST := 12.0 * 32.0 * 32.0  # the air inside the stone that is only a window, in square pixels: larger is a room
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
		var atlas: Texture2D = load("res://art/tiles/%s.png" % span["tiles"])
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


## The waiting room's ground between two points across, put back as it was built: every pit dug there is filled again (the training arena, between
## bouts). A world's tiled rock is not mended.
func mend(from_x: float, to_x: float) -> void:
	if tiled or _edges.size() != _first_edges.size():
		return
	var mended := false
	for k in _edges.size():
		var x := ArenaGen.FIRST_COL * float(ArenaGen.TILE) + k * EDGE_STEP
		if x >= from_x and x <= to_x and _edges[k] != _first_edges[k]:
			_edges[k] = _first_edges[k]
			mended = true
	if not mended:
		return
	var area := Rect2(from_x, 0.0, to_x - from_x, (ArenaGen.GROUND_ROW + ArenaGen.DEPTH + 1) * float(ArenaGen.TILE))
	about_to_change.emit(area)
	_solid.queue_free()
	_build_collision()
	queue_redraw()
	changed.emit(area)


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


## The rock under everything, the inside of the castle, or its brick.
class CaveDraw extends Node2D:
	const HALL_PICTURE := preload("res://art/backgrounds/church/hall.png")
	var kind := "rock"     # "rock", "hall" or "solid"
	var chunk := -1        # a hall is painted in pieces of HALL_CHUNK columns: this is the one this paints
	var loops: Array = []  # outlines, with rock on the right of the way they run
	var pits: Array = []   # the pits dug since, each cut out of the stone as it was drawn
	var openings: Array = []  # the part of a slab between two storeys that a pit went through: the hall shows through it
	var cuts: Array = []   # the whole shape of every pit dug, with the air above it
	var rims: Array = []   # the lines round the pits that lie inside the stone
	var hollows: Array = []  # the stone that the pits took away, which is painted as the dark inside of the castle
	var earth: Texture2D
	var world := Vector2.ZERO
	var sky := PackedVector2Array()  # the part of the world that is open sky
	var snow: Array = []  # {"a", "b": pixels across, "line": height, "texture"}: the rock above the line, in these columns, is under snow

	func _ready() -> void:
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	## Takes a pit's shape out of the brick, so that what was dug is seen to be dug.
	func cut(shape: PackedVector2Array) -> void:
		var pit := PackedVector2Array(shape)
		if Contour.area(pit) < 0.0:
			pit.reverse()  # whichever way it was dug, the shape is cut out the same way
		cuts.append(pit)
		var pit_box := Rect2(pit[0], Vector2.ZERO)
		for point in pit:
			pit_box = pit_box.expand(point)
		var kept: Array = []
		var rooms: Array = []
		for points: PackedVector2Array in loops:
			if Contour.area(points) < 0.0 and absf(Contour.area(points)) >= WINDOW_AREA_MOST:
				var room := PackedVector2Array(points)
				room.reverse()
				rooms.append(room)
		for points: PackedVector2Array in loops:
			var box := Rect2(points[0], Vector2.ZERO)
			for point in points:
				box = box.expand(point)
			if Contour.area(points) < 0.0 or not box.intersects(pit_box):
				kept.append(points)  # a window, or stone the pit does not touch
				continue
			var standing := false  # a slab standing in a room is inside the room's outline; the rest of the stone has the rooms taken out of it
			for room: PackedVector2Array in rooms:
				standing = standing or Geometry2D.clip_polygons(points, room).is_empty()  # all of it is inside the room
			# Only the part of the pit that is in stone is cut: the part in the room's air was never stone.
			var parts: Array = [pit]
			if not standing:
				for room: PackedVector2Array in rooms:
					var left: Array = []
					for part: PackedVector2Array in parts:
						left.append_array(Geometry2D.clip_polygons(part, room))
					parts = left
			var rest: Array = [points]
			for part: PackedVector2Array in parts:
				if Contour.area(part) < 0.0:
					continue
				for gone: PackedVector2Array in Geometry2D.intersect_polygons(points, part):
					var under := false  # a room lies under it: it is a hole through a floor, and the hall shows through
					var bottom := gone[0]
					for point in gone:
						if point.y > bottom.y:
							bottom = point
					for room: PackedVector2Array in rooms:
						under = under or Geometry2D.is_point_in_polygon(bottom + Vector2(0.0, 6.0), room)
					if under:
						openings.append(gone)
					else:
						hollows.append(gone)
				var next: Array = []
				for stone: PackedVector2Array in rest:
					for piece: PackedVector2Array in Geometry2D.clip_polygons(stone, part):
						if Contour.area(piece) < 0.0:
							piece.reverse()  # the pit lies inside the stone's outline, so it is a hole in it
							pits.append(piece)
							var closed := PackedVector2Array(piece)
							closed.append(piece[0])
							if standing:
								rims.append(closed)
							else:  # its edge along the floor it was dug through is open air, and has no line
								var shown: Array = [closed]
								for room: PackedVector2Array in rooms:
									for edge: PackedVector2Array in Geometry2D.offset_polygon(room, 2.0):
										var outside: Array = []
										for line: PackedVector2Array in shown:
											outside.append_array(Geometry2D.clip_polyline_with_polygon(line, edge))
										shown = outside
								rims.append_array(shown)
						else:
							next.append(piece)
				rest = next
			kept.append_array(rest)
		loops = kept
		queue_redraw()

	func _draw() -> void:
		var t := float(ArenaGen.TILE)
		if kind == "rock":
			# The earth under the sky: everything in the world but the sky, which is left open for the biome's backdrop to show through.
			var whole := PackedVector2Array([Vector2.ZERO, Vector2(world.x, 0.0), world, Vector2(0.0, world.y)])
			for part: PackedVector2Array in (Geometry2D.clip_polygons(whole, sky) if not sky.is_empty() else [whole]):
				var uvs := PackedVector2Array()
				for point in part:
					uvs.append(point / earth.get_size())
				draw_polygon(part, PackedColorArray([Color.WHITE]), uvs, earth)
			# Snow over the high rock, thinning out to nothing at the snow line.
			var rock_parts: Array = Geometry2D.clip_polygons(whole, sky) if not sky.is_empty() else [whole]
			for cap: Dictionary in snow:
				var texture: Texture2D = cap["texture"]
				var left: float = cap["a"]
				var right: float = cap["b"]
				var line: float = cap["line"]
				var top := line - SNOW_FADE
				for edge in [[0.0, top, Color.WHITE, Color.WHITE], [top, line, Color.WHITE, Color(1, 1, 1, 0)]]:
					var band := PackedVector2Array([Vector2(left, edge[0]), Vector2(right, edge[0]), Vector2(right, edge[1]), Vector2(left, edge[1])])
					for rock_part: PackedVector2Array in rock_parts:
						for piece: PackedVector2Array in Geometry2D.intersect_polygons(band, rock_part):
							if Contour.area(piece) < 1.0 or Geometry2D.triangulate_polygon(piece).is_empty():
								continue
							var snow_uvs := PackedVector2Array()
							var shades := PackedColorArray()
							for point in piece:
								snow_uvs.append(point / texture.get_size())
								shades.append(edge[2].lerp(edge[3], clampf((point.y - edge[0]) / maxf(edge[1] - edge[0], 1.0), 0.0, 1.0)))
							draw_polygon(piece, shades, snow_uvs, texture)
			return
		if kind == "hall":
			# The inside of a cathedral, from the church backdrop: columns, windows and candles, as tall as the hall's tallest part,
			# standing on the floor, so a low stretch of hall shows only the bottom of the picture.
			var picture: Texture2D = HALL_PICTURE
			var zoom := t * float(Terrain.HALL_TILES) / picture.get_height()
			var first_column := 1 << 30
			var last_column := -1
			var ground_row := -1  # the row under the castle's ground floor, which keeps its edge
			for tiles: Rect2i in ArenaGen.castle_hall:
				first_column = mini(first_column, tiles.position.x)
				last_column = maxi(last_column, tiles.position.x)
				ground_row = maxi(ground_row, tiles.end.y)
			for tiles: Rect2i in ArenaGen.castle_hall:
				if chunk >= 0 and tiles.position.x / Terrain.HALL_CHUNK != chunk:
					continue
				var rect := Rect2(Vector2(tiles.position) * t, Vector2(tiles.size) * t + Vector2(0.0, 1.0))
				# The painting runs a little under the stone round it (the brick is drawn over it), so that where the smoothed edge of a
				# stair or a wall cuts across a tile, the sky does not show through the corner. The castle's two ends stay as they are.
				var bleed_left := 0.0 if tiles.position.x == first_column else BLEED
				var bleed_right := 0.0 if tiles.position.x == last_column else BLEED
				var bleed_down := 0.0 if tiles.end.y == ground_row else BLEED
				rect = Rect2(rect.position - Vector2(bleed_left, BLEED), rect.size + Vector2(bleed_left + bleed_right, BLEED + bleed_down))
				draw_rect(rect, Terrain.HALL)
				var width := t / zoom
				var height := minf(rect.size.y / zoom, float(picture.get_height()))
				# The picture runs along the hall and back again, so that it never jumps where its ends meet.
				var travel := picture.get_width() - width
				var along := fposmod(rect.position.x / zoom, travel * 2.0)
				var mirrored := along > travel
				var across := travel * 2.0 - along if mirrored else along
				var size := Vector2(picture.get_size())
				var u0 := across / size.x
				var u1 := (across + width) / size.x
				if mirrored:
					var swap := u0
					u0 = u1
					u1 = swap
				var v0 := (size.y - height) / size.y
				var corners := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0.0), rect.end, rect.position + Vector2(0.0, rect.size.y)])
				draw_polygon(corners, PackedColorArray([Color.WHITE]), PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, 1.0), Vector2(u0, 1.0)]), picture)
			return
		# Brick is drawn over every piece of stone, with the castle's rooms cut out of it so that the hall painted under it shows (a polygon cannot
		# have a hole, so the stone is cut into strips across a room, and each strip has the room taken out of it).
		var rooms: Array = []
		var stone: Array = []
		for points: PackedVector2Array in loops:
			if Contour.area(points) >= 0.0:
				stone.append(points)
			elif absf(Contour.area(points)) >= WINDOW_AREA_MOST:
				var room := PackedVector2Array(points)
				room.reverse()
				rooms.append(room)
		for room: PackedVector2Array in rooms:
			stone = _without(stone, room, true)
		for pit: PackedVector2Array in pits:
			stone = _without(stone, pit, false)
		for gone: PackedVector2Array in hollows:  # what a pit took out of the stone is the castle's dark inside now
			if Contour.area(gone) > 1.0 and not Geometry2D.triangulate_polygon(gone).is_empty():
				draw_colored_polygon(gone, Terrain.HALL)
		for gone: PackedVector2Array in openings:
			_show_hall(gone)
		for points: PackedVector2Array in stone:
			for piece: PackedVector2Array in Geometry2D.offset_polygon(points, 0.0):
				if Contour.area(piece) > 0.0:
					_lay(piece, earth, 1.0)
		for points: PackedVector2Array in loops:
			if Contour.area(points) < 0.0 and absf(Contour.area(points)) < WINDOW_AREA_MOST:
				draw_colored_polygon(points, Terrain.WALL)  # a window: air inside the stone
			var closed := PackedVector2Array(points)
			closed.append(points[0])
			var lines: Array = [closed]
			if Contour.area(points) < 0.0:  # a room's edge is open where a pit was dug through its floor
				for cut_shape: PackedVector2Array in cuts:
					var left: Array = []
					for line: PackedVector2Array in lines:
						left.append_array(Geometry2D.clip_polyline_with_polygon(line, cut_shape))
					lines = left
			for line: PackedVector2Array in lines:
				draw_polyline(line, Terrain.RIM, 3.0)
		for line: PackedVector2Array in rims:
			draw_polyline(line, Terrain.RIM, 3.0)

	## The hall's picture over a hole through a floor, as the room under it goes on up: the top of the picture, turned over, so that it joins the room's own
	## picture at the hole's lower edge. It is laid a column at a time, as the hall is, so that each column is the part of the picture the room has there.
	func _show_hall(hole: PackedVector2Array) -> void:
		if Contour.area(hole) < 1.0:
			return
		var t := float(ArenaGen.TILE)
		var picture: Texture2D = HALL_PICTURE
		var zoom := t * float(Terrain.HALL_TILES) / picture.get_height()
		var size := Vector2(picture.get_size())
		var width := t / zoom
		var travel := size.x - width
		var box := Rect2(hole[0], Vector2.ZERO)
		for point in hole:
			box = box.expand(point)
		var column := floorf(box.position.x / t)
		while column * t < box.end.x:
			var strip := PackedVector2Array([Vector2(column * t, box.position.y - 4.0), Vector2((column + 1.0) * t, box.position.y - 4.0), Vector2((column + 1.0) * t, box.end.y + 4.0), Vector2(column * t, box.end.y + 4.0)])
			var along := fposmod(column * t / zoom, travel * 2.0)
			var mirrored := along > travel
			var across := travel * 2.0 - along if mirrored else along
			for part: PackedVector2Array in Geometry2D.intersect_polygons(hole, strip):
				if Contour.area(part) < 1.0 or Geometry2D.triangulate_polygon(part).is_empty():
					continue
				var uvs := PackedVector2Array()
				for point in part:
					var u := (across + (1.0 - (point.x - column * t) / t if mirrored else (point.x - column * t) / t) * width) / size.x
					uvs.append(Vector2(u, clampf((box.end.y - point.y) / (zoom * size.y), 0.0, 1.0)))
				draw_colored_polygon(part, Terrain.HALL)
				draw_polygon(part, PackedColorArray([Color.WHITE]), uvs, picture)
			column += 1.0

	## A piece of stone in its colour with a texture over it, at a scale of the texture's own size. A piece that cannot be cut into triangles whole (an edge
	## touching itself) is laid in convex parts.
	func _lay(piece: PackedVector2Array, texture: Texture2D, scale: float) -> void:
		if Contour.area(piece) < 1.0:
			return
		var parts: Array = [piece] if not Geometry2D.triangulate_polygon(piece).is_empty() else Geometry2D.decompose_polygon_in_convex(piece)
		for part: PackedVector2Array in parts:
			draw_colored_polygon(part, Terrain.STONE_FILL)
			var uvs := PackedVector2Array()
			for point in part:
				uvs.append(point / (texture.get_size() * scale))
			draw_polygon(part, PackedColorArray([Color.WHITE]), uvs, texture)

	## Outlines of stone with a room taken out of them: cut into strips across the room, each strip minus the room, so no piece has a hole in it.
	static func _without(stone: Array, room: PackedVector2Array, inside_stays: bool) -> Array:
		var box := Rect2(room[0], Vector2.ZERO)
		for point in room:
			box = box.expand(point)
		var out: Array = []
		for points: PackedVector2Array in stone:
			var around := Rect2(points[0], Vector2.ZERO)
			for point in points:
				around = around.expand(point)
			if not around.intersects(box):
				out.append(points)
				continue
			if Geometry2D.clip_polygons(points, room).is_empty():  # all of it inside
				if inside_stays:
					out.append(points)  # (a slab standing in the room is stone inside its outline, and stays)
				continue  # (and a piece all inside a pit is gone)
			var left := box.position.x - 64.0
			var far := Vector2(-1.0e6, 1.0e6)  # what lies beside the strips, left and right of them, is stone as it was
			for edge in [[far.x, left], [left + ceilf((box.end.x - left) / STRIP) * STRIP - 2.0, far.y]]:
				var side := PackedVector2Array([Vector2(edge[0], around.position.y - 8.0), Vector2(edge[1], around.position.y - 8.0), Vector2(edge[1], around.end.y + 8.0), Vector2(edge[0], around.end.y + 8.0)])
				for part: PackedVector2Array in Geometry2D.intersect_polygons(points, side):
					out.append(part)
			while left < box.end.x:
				var strip := PackedVector2Array([Vector2(left - 2.0, around.position.y - 8.0), Vector2(left + STRIP + 2.0, around.position.y - 8.0), Vector2(left + STRIP + 2.0, around.end.y + 8.0), Vector2(left - 2.0, around.end.y + 8.0)])
				for part: PackedVector2Array in Geometry2D.intersect_polygons(points, strip):
					for rest: PackedVector2Array in Geometry2D.clip_polygons(part, room):
						if Contour.area(rest) < 0.0:
							rest.reverse()  # (the cutting has no holes to leave, so a piece the other way round is stone, not a gap)
						out.append(rest)
				left += STRIP
		return out

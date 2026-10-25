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
var air_loops: Array = []  # the traced outlines of the open air, in world pixels; pools are drawn only inside them
var cells := {}
var biome := "cemetery"
var _textures := {}  # material -> atlas texture
const GRASS_BAND := 16.0  # how deep the grass along the top of the ground is, in world pixels
var _edges := PackedFloat32Array()  # the ground's top edge height at each column boundary, left to right
var earth_texture: Texture2D  # the biome's plain earth, which repeats under the surface
var _grass_texture: Texture2D  # the biome's grassy top, its first few pixels repeat along the surface


## Builds everything from the generated cells. Call once, after adding the terrain to the tree.
func build(map_cells: Dictionary, biome_name: String, rng: RandomNumberGenerator) -> void:
	cells = map_cells
	biome = biome_name
	var tiles: String = ArenaGen.BIOMES[biome]["tiles"]
	_textures[ArenaGen.GROUND] = load("res://art/tiles/%s.png" % tiles)
	_textures[ArenaGen.STONE] = load("res://art/tiles/stone.png")
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	earth_texture = _piece_texture(_textures[ArenaGen.GROUND], CENTER)  # the lit, rocky middle of the earth, not the black depths
	_grass_texture = _piece_texture(_textures[ArenaGen.GROUND], TOP)
	if tiled:
		_build_contour()
	else:
		_build_edges()
	_build_collision()
	if not tiled:
		_scatter_props(rng)
	queue_redraw()


## The ground's top edge: one height at each column boundary, the average of the columns either side. Drawing and
## collision both follow these edges, so a slope between two columns is a straight, smooth ramp.
func _build_edges() -> void:
	var heights := PackedFloat32Array()
	for h in ArenaGen.column_heights:
		heights.append((ArenaGen.GROUND_ROW + h) * float(ArenaGen.TILE))  # the smooth heights, not the rounded ones
	_edges.clear()
	_edges.append(heights[0])
	for k in range(1, heights.size()):
		_edges.append((heights[k - 1] + heights[k]) * 0.5)
	_edges.append(heights[heights.size() - 1])


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
		top.append(Vector2((ArenaGen.FIRST_COL + k) * ArenaGen.TILE, _edges[k]))
	var bottom := (ArenaGen.GROUND_ROW + ArenaGen.DEPTH + 1) * float(ArenaGen.TILE)
	var fill := PackedVector2Array(top)
	fill.append(Vector2(top[top.size() - 1].x, bottom))
	fill.append(Vector2(top[0].x, bottom))
	var fill_uvs := PackedVector2Array()
	for p in fill:
		fill_uvs.append(p / float(ArenaGen.TILE))
	draw_polygon(fill, PackedColorArray([Color("#2a1f1a")]))  # an opaque base, so the earth is never see-through
	draw_polygon(fill, PackedColorArray([Color.WHITE]), fill_uvs, earth_texture)
	var band := PackedVector2Array(top)
	var uvs := PackedVector2Array()
	for p in top:
		uvs.append(Vector2(p.x, 0.0) / float(ArenaGen.TILE))
	for i in range(top.size() - 1, -1, -1):
		band.append(top[i] + Vector2(0, GRASS_BAND))
		uvs.append(Vector2(top[i].x, GRASS_BAND) / float(ArenaGen.TILE))
	draw_polygon(band, PackedColorArray([Color.WHITE]), uvs, _grass_texture)


## One static body for solid stone. Stone's runs of cells become single strips. The ground is a row of sloped blocks under
## its smooth top, one per column, so walking up a slope never catches on a step.
func _build_collision() -> void:
	if tiled:
		return  # a world's rock is solid along its outlines, see _build_contour
	var solid := StaticBody2D.new()
	solid.collision_layer = 1
	add_child(solid)
	var bottom := (ArenaGen.GROUND_ROW + ArenaGen.DEPTH + 1) * float(ArenaGen.TILE)
	for k in range(_edges.size() - 1):
		var x0 := (ArenaGen.FIRST_COL + k) * float(ArenaGen.TILE)
		var x1 := x0 + ArenaGen.TILE
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
	var k := x / float(ArenaGen.TILE) - ArenaGen.FIRST_COL
	var i := clampi(int(floor(k)), 0, _edges.size() - 2)
	return lerpf(_edges[i], _edges[i + 1], clampf(k - i, 0.0, 1.0))


## Where the cave's air meets its rock, as closed outlines. Each cell of four tile centres has the outline pass through the
## middles of its edges, so a wall of tiles is a straight line on the tile boundary. The pieces name the edge middles.
const EDGE_PAIRS := {
	1: [["L", "T"]], 2: [["T", "R"]], 3: [["L", "R"]], 4: [["R", "B"]], 5: [["L", "T"], ["R", "B"]], 6: [["T", "B"]],
	7: [["L", "B"]], 8: [["L", "B"]], 9: [["T", "B"]], 10: [["T", "R"], ["L", "B"]], 11: [["R", "B"]], 12: [["L", "R"]],
	13: [["T", "R"]], 14: [["L", "T"]],
}
const CORNER_OF := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]  # TL, TR, BR, BL, in cells
const SPACING := 10.0      # pixels between the points of a smoothed outline
const SMOOTHING := 14      # passes that round an outline's corners
const SMALL_LOOP := 700.0  # an outline shorter than this (a stepping stone) is barely smoothed, so it stays itself
const RIM := Color("#0d0916")
const WALL := Color("#3a2e50")


func _solid_at(c: int, r: int, stone_only := false) -> bool:
	var size := ArenaGen.world_size
	if c < 0 or r < 0 or c >= size.x or r >= size.y:
		return not stone_only
	var material: int = cells.get(Vector2i(c, r), -1)
	return material == ArenaGen.STONE or (material == ArenaGen.GROUND and not stone_only)


## Turns the world's solid tiles into rock with smooth edges, the way the waiting room ground is one smooth line: the
## outlines of the caves are traced, rounded off, drawn with a grass band along every surface facing up, and made solid.
## The castle is stone on top of that, drawn in brick.
func _build_contour() -> void:
	var size := ArenaGen.world_size
	var t := float(ArenaGen.TILE)
	var loops := _trace(false)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	add_child(body)
	for points: PackedVector2Array in loops:
		var segments := PackedVector2Array()
		for k in points.size():
			segments.append(points[k])
			segments.append(points[(k + 1) % points.size()])
		var shape := ConcavePolygonShape2D.new()
		shape.segments = segments
		var holder := CollisionShape2D.new()
		holder.shape = shape
		body.add_child(holder)
	var rock := CaveDraw.new()
	rock.kind = "rock"
	rock.z_index = -11
	rock.earth = earth_texture
	rock.world = Vector2(size) * t
	add_child(rock)
	var cave := CaveDraw.new()
	cave.z_index = -10
	cave.earth = earth_texture
	cave.grass_texture = _grass_texture
	loops.sort_custom(func(a: PackedVector2Array, b: PackedVector2Array) -> bool: return absf(_area(a)) > absf(_area(b)))
	var islands: Array = []
	var airs: Array = []
	for points: PackedVector2Array in loops:
		(airs if _area(points) < 0.0 else islands).append(points)
	air_loops = airs
	cave.kind = "air"
	cave.loops = airs
	cave.sky = _sky_polygon()
	add_child(cave)
	var stone_loops := _trace(true)
	stone_loops.sort_custom(func(a: PackedVector2Array, b: PackedVector2Array) -> bool: return absf(_area(a)) > absf(_area(b)))
	if not stone_loops.is_empty():
		var bricks := CaveDraw.new()  # the castle: brick, with dark windows
		bricks.z_index = -9
		bricks.kind = "solid"
		bricks.earth = _piece_texture(_textures[ArenaGen.STONE], CENTER)
		bricks.loops = stone_loops
		add_child(bricks)
	if not islands.is_empty():
		var standing := CaveDraw.new()  # rock standing in the air, in front of any pool beside it
		standing.z_index = 0
		standing.kind = "solid"
		standing.earth = earth_texture
		standing.grass_texture = _grass_texture
		standing.loops = islands
		add_child(standing)


## The outlines between air and rock, or between air and stone alone, each smoothed.
func _trace(stone_only: bool) -> Array:
	var size := ArenaGen.world_size
	var t := float(ArenaGen.TILE)
	var width := size.x + 4
	var spots := {}   # edge key -> where the outline crosses that edge
	var onward := {}  # edge key -> the next edge key, with rock on the right
	for j in range(-1, size.y):
		for i in range(-1, size.x):
			var solid := [_solid_at(i, j, stone_only), _solid_at(i + 1, j, stone_only), _solid_at(i + 1, j + 1, stone_only), _solid_at(i, j + 1, stone_only)]
			var mask := (1 if solid[0] else 0) | (2 if solid[1] else 0) | (4 if solid[2] else 0) | (8 if solid[3] else 0)
			if mask == 0 or mask == 15:
				continue
			var keys := {"T": ((j + 1) * width + i + 1) * 2, "B": ((j + 2) * width + i + 1) * 2, "L": ((j + 1) * width + i + 1) * 2 + 1, "R": ((j + 1) * width + i + 2) * 2 + 1}
			var where := {"T": Vector2(i + 1, j + 0.5) * t, "B": Vector2(i + 1, j + 1.5) * t, "L": Vector2(i + 0.5, j + 1) * t, "R": Vector2(i + 1.5, j + 1) * t}
			for pair in EDGE_PAIRS[mask]:
				var a: String = pair[0]
				var b: String = pair[1]
				var heading: Vector2 = where[b] - where[a]
				var middle: Vector2 = (where[a] + where[b]) * 0.5
				var nearest := Vector2.ZERO
				var best := INF
				for k in 4:
					if solid[k]:
						var corner: Vector2 = (Vector2(i, j) + Vector2(0.5, 0.5) + CORNER_OF[k]) * t
						if corner.distance_to(middle) < best:
							best = corner.distance_to(middle)
							nearest = corner
				if Vector2(-heading.y, heading.x).dot(nearest - middle) < 0.0:
					var swap := a
					a = b
					b = swap
				spots[keys[a]] = where[a]
				spots[keys[b]] = where[b]
				onward[keys[a]] = keys[b]
	var loops: Array = []
	var seen := {}
	for first in onward:
		if seen.has(first):
			continue
		var points := PackedVector2Array()
		var at: int = first
		while not seen.has(at) and onward.has(at):
			seen[at] = true
			points.append(spots[at])
			at = onward[at]
		if points.size() >= 3:
			loops.append(_smooth(points))
	return loops


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


static func _area(points: PackedVector2Array) -> float:
	var sum := 0.0
	for k in points.size():
		var p := points[k]
		var q := points[(k + 1) % points.size()]
		sum += p.x * q.y - q.x * p.y
	return sum * 0.5


## An outline spread evenly along its length, then rounded off by averaging each point with its neighbours, then thinned
## where it runs straight.
static func _smooth(points: PackedVector2Array) -> PackedVector2Array:
	var length := 0.0
	for k in points.size():
		length += points[k].distance_to(points[(k + 1) % points.size()])
	var count := maxi(8, int(length / SPACING))
	var even := PackedVector2Array()
	var k := 0
	var run := 0.0  # how far along the outline the start of segment k is
	for n in count:
		var wanted := length * n / count
		while run + points[k].distance_to(points[(k + 1) % points.size()]) < wanted and k < points.size() - 1:
			run += points[k].distance_to(points[(k + 1) % points.size()])
			k += 1
		var seg := points[k].distance_to(points[(k + 1) % points.size()])
		even.append(points[k].lerp(points[(k + 1) % points.size()], clampf((wanted - run) / maxf(seg, 0.001), 0.0, 1.0)))
	var passes := 2 if length < SMALL_LOOP else SMOOTHING
	for pass_index in passes:
		var next := PackedVector2Array()
		for n in even.size():
			next.append(even[(n - 1 + even.size()) % even.size()] * 0.25 + even[n] * 0.5 + even[(n + 1) % even.size()] * 0.25)
		even = next
	var thin := PackedVector2Array()
	thin.append(even[0])
	for n in range(1, even.size()):
		var after := even[(n + 1) % even.size()]
		var line := after - thin[thin.size() - 1]
		if line.length() < 0.01 or absf(line.normalized().cross(even[n] - thin[thin.size() - 1])) > 0.4:
			thin.append(even[n])
	return thin


## One layer of the cave: the rock under everything, the open air drawn over it, or solid things standing in it, each with
## a rim and grass.
class CaveDraw extends Node2D:
	const SKY_TOP := Color("#1d2a5c")
	const SKY_HORIZON := Color("#c98c86")
	const SKY_BANDS := 24
	var kind := "air"      # "rock", "air" or "solid"
	var loops: Array = []  # outlines, biggest first, with rock on the right of the way they run
	var sky := PackedVector2Array()
	var earth: Texture2D
	var grass_texture: Texture2D
	var world := Vector2.ZERO

	func _ready() -> void:
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func _draw() -> void:
		var t := float(ArenaGen.TILE)
		if kind == "rock":
			draw_texture_rect(earth, Rect2(Vector2.ZERO, world), true)
			return
		for points: PackedVector2Array in loops:
			if kind == "air":
				draw_colored_polygon(points, Terrain.WALL)
				if not sky.is_empty():
					_paint_sky(points)
			elif Terrain._area(points) < 0.0:
				draw_colored_polygon(points, Terrain.WALL)  # a window: air inside the stone
			else:
				var uvs := PackedVector2Array()
				for p in points:
					uvs.append(p / t)
				draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, earth)
			var closed := PackedVector2Array(points)
			closed.append(points[0])
			draw_polyline(closed, Terrain.RIM, 3.0)
		if grass_texture != null:
			_grass()

	## The part of an outline's air that is above the ground, in bands from the dark top of the sky to the glow at the horizon.
	func _paint_sky(points: PackedVector2Array) -> void:
		var low := 0.0
		for p in sky:
			low = maxf(low, p.y)
		var step := low / SKY_BANDS
		for piece in Geometry2D.intersect_polygons(points, sky):
			for band in SKY_BANDS:
				var strip := PackedVector2Array([Vector2(-10.0, band * step), Vector2(1.0e5, band * step), Vector2(1.0e5, (band + 1) * step + 1.0), Vector2(-10.0, (band + 1) * step + 1.0)])
				var color := SKY_TOP.lerp(SKY_HORIZON, pow(float(band) / (SKY_BANDS - 1), 1.6))
				for part in Geometry2D.intersect_polygons(piece, strip):
					draw_colored_polygon(part, color)

	func _grass() -> void:
		var t := float(ArenaGen.TILE)
		for points: PackedVector2Array in loops:
			_grass_along(points, t)
		if not _grass_points.is_empty():
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = _grass_points
			arrays[Mesh.ARRAY_TEX_UV] = _grass_uvs
			arrays[Mesh.ARRAY_INDEX] = _grass_index
			_mesh = ArrayMesh.new()
			_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			draw_mesh(_mesh, grass_texture)  # every band in one go, so the screen is not paying for the ones it cannot see

	const BAND := 24.0  # how deep the grass along a surface is, in pixels
	var _mesh: ArrayMesh  # kept so the drawing is not freed before it is shown
	var _grass_points := PackedVector2Array()
	var _grass_uvs := PackedVector2Array()
	var _grass_index := PackedInt32Array()

	## A band of grass along each stretch of outline where the air is above the rock.
	func _grass_along(points: PackedVector2Array, t: float) -> void:
		var count := points.size()
		var faces_up := []
		for k in count:
			var heading := (points[(k + 1) % count] - points[k]).normalized()
			faces_up.append(-heading.x < -0.4)  # the air is on the left of the way the outline runs
		var begin := 0
		while begin < count and faces_up[begin]:
			begin += 1
		if begin == count:
			begin = 0
		var run := PackedVector2Array()
		for step in count + 1:
			var k := (begin + step) % count
			if step < count and faces_up[k]:
				if run.is_empty():
					run.append(points[k])
				run.append(points[(k + 1) % count])
			elif not run.is_empty():
				_band(run, t)
				run = PackedVector2Array()

	func _band(line: PackedVector2Array, t: float) -> void:
		var drop := Vector2(0, BAND)
		var along := 0.0  # the way the grass texture runs follows the surface, so a slope is not stretched
		for k in line.size() - 1:
			var a := line[k]
			var b := line[k + 1]
			var reach := along + a.distance_to(b)
			var first := _grass_points.size()
			_grass_points.append_array(PackedVector2Array([a, b, b + drop, a + drop]))
			_grass_uvs.append_array(PackedVector2Array([Vector2(along, 0.0) / t, Vector2(reach, 0.0) / t, Vector2(reach, BAND) / t, Vector2(along, BAND) / t]))
			_grass_index.append_array(PackedInt32Array([first, first + 1, first + 2, first, first + 2, first + 3]))
			along = reach

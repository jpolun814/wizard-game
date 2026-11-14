class_name Minimap
extends Control

## A small map of the whole arena, with only the player marked: it shows the map, not who is on it. Shown when revealed.
## It sizes itself to the map: long maps get smaller tiles so the minimap never grows past MAX_WIDTH.
## The terrain is painted once into a picture, a pixel to a tile, and only the marks are drawn each frame.

const MAX_CELL := 3.0      # pixels per tile, for small maps
const MAX_WIDTH := 320.0   # the minimap never gets wider than this
const MARGIN := 16.0
const SKY_ROWS := 40       # rows of sky kept above the highest ground
const SIDE_COLS := 8
const ROCK_ROWS := 24      # and of rock kept under the lowest air
const TILE_COLORS := {
	ArenaGen.GROUND: Color("#7a5a8a"),
	ArenaGen.STONE: Color("#8d8f96"),
}

var arena: Node2D
var _picture: ImageTexture
var _origin := Vector2i.ZERO  # the top-left tile of the map
var _cell := MAX_CELL


func _ready() -> void:
	var terrain: Variant = arena.map_cells()
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	var image: Image
	if terrain is TileGrid:
		lo = Vector2i.ZERO
		hi = terrain.size - Vector2i.ONE
		# Rock with nothing in it all the way across, far under the surface, and sky above the highest peak are left off the map, so that the
		# map is mostly the place that is played in and not mostly solid ground.
		var width: int = terrain.size.x
		var total_rows: int = terrain.size.y
		var first_air := total_rows
		var last_air := 0
		var first_solid := total_rows
		for row in total_rows:
			var solid := 0
			for col in range(SIDE_COLS, width - SIDE_COLS):  # (the walls at the two ends of the world do not count)
				if terrain.data[row * width + col] != 0:
					solid += 1
			if solid < width - SIDE_COLS * 2:
				first_air = mini(first_air, row)
				last_air = row
			if solid > 0:
				first_solid = mini(first_solid, row)
		lo.y = maxi(first_solid - SKY_ROWS, 0)
		hi.y = mini(last_air + ROCK_ROWS, total_rows - 1)
		if ArenaGen.air_rows != Vector2i.ZERO:  # the sky: the map is the air, which is where everyone is, and not the rock under it that no one sees
			lo.y = ArenaGen.air_rows.x
			hi.y = ArenaGen.air_rows.y
	else:
		for cell in terrain:
			lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.y))
			hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.y))
	_origin = lo
	var cols := hi.x - lo.x + 1
	var rows := hi.y - lo.y + 1
	image = Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	if terrain is TileGrid:
		var bytes := PackedByteArray()
		bytes.resize(cols * rows * 4)
		var full_width: int = terrain.size.x
		var ground: Color = TILE_COLORS[ArenaGen.GROUND]
		var stone: Color = TILE_COLORS[ArenaGen.STONE]
		for row in rows:
			for col in cols:
				var value: int = terrain.data[(row + lo.y) * full_width + col + lo.x]
				if value != 0:
					var k := row * cols + col
					var color := ground if value == ArenaGen.GROUND + 1 else stone
					bytes[k * 4] = color.r8
					bytes[k * 4 + 1] = color.g8
					bytes[k * 4 + 2] = color.b8
					bytes[k * 4 + 3] = 255
		image = Image.create_from_data(cols, rows, false, Image.FORMAT_RGBA8, bytes)
	else:
		for cell in terrain:
			image.set_pixel(cell.x - lo.x, cell.y - lo.y, TILE_COLORS[terrain[cell]])
	image.generate_mipmaps()
	_picture = ImageTexture.create_from_image(image)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cell = minf(MAX_CELL, MAX_WIDTH / cols)
	custom_minimum_size = Vector2(cols * _cell, rows * _cell)
	size = custom_minimum_size
	_place()
	get_viewport().size_changed.connect(_place)  # a window that is resized or made full screen keeps the map in the top right corner


## Puts the map in the top right corner of whatever the window is now.
func _place() -> void:
	position = Vector2(get_viewport_rect().size.x - size.x - MARGIN, MARGIN + 60.0)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()  # only the marks move


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	draw_texture_rect(_picture, Rect2(Vector2.ZERO, size), false)
	draw_circle(_to_map(arena.player.center()), 2.5, Color("#7fe0ff"))


func _to_map(world: Vector2) -> Vector2:
	return Vector2(world.x / ArenaGen.TILE - _origin.x, world.y / ArenaGen.TILE - _origin.y) * _cell

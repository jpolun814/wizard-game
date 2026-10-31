class_name Minimap
extends Control

## A small map of the whole arena, with only the player marked: it shows the map, not who is on it. Shown when revealed.
## It sizes itself to the map: long maps get smaller tiles so the minimap never grows past MAX_WIDTH.
## The terrain is painted once into a picture, a pixel to a tile, and only the marks are drawn each frame.

const MAX_CELL := 3.0      # pixels per tile, for small maps
const MAX_WIDTH := 320.0   # the minimap never gets wider than this
const MARGIN := 16.0
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
		var ground: Color = TILE_COLORS[ArenaGen.GROUND]
		var stone: Color = TILE_COLORS[ArenaGen.STONE]
		for k in terrain.data.size():
			var value: int = terrain.data[k]
			if value != 0:
				var colour := ground if value == ArenaGen.GROUND + 1 else stone
				bytes[k * 4] = colour.r8
				bytes[k * 4 + 1] = colour.g8
				bytes[k * 4 + 2] = colour.b8
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

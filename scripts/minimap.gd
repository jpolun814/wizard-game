class_name Minimap
extends Control

## A small map of the whole arena, with mobs and the player marked. Shown when revealed.
## It sizes itself to the map: long maps get smaller tiles so the minimap never grows past MAX_WIDTH.

const MAX_CELL := 3.0      # pixels per tile, for small maps
const MAX_WIDTH := 240.0   # the minimap never gets wider than this
const MARGIN := 16.0
const TILE_COLORS := {
	0: Color("#5fae3c"),  # grass
	1: Color("#7a5230"),  # dirt
	2: Color("#7d7f86"),  # stone
	3: Color("#9a6a3a"),  # wood
}

var arena: Node2D
var _terrain := {}
var _origin := Vector2i.ZERO  # the top-left tile of the map
var _cell := MAX_CELL


func _ready() -> void:
	_terrain = arena._terrain()
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for cell in _terrain:
		lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.y))
		hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.y))
	_origin = lo
	var cols := hi.x - lo.x + 1
	var rows := hi.y - lo.y + 1
	_cell = minf(MAX_CELL, MAX_WIDTH / cols)
	custom_minimum_size = Vector2(cols * _cell, rows * _cell)
	size = custom_minimum_size
	position = Vector2(get_viewport_rect().size.x - size.x - MARGIN, MARGIN)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	for cell in _terrain:
		var pos := Vector2(cell.x - _origin.x, cell.y - _origin.y) * _cell
		draw_rect(Rect2(pos, Vector2(_cell, _cell)), TILE_COLORS[_terrain[cell]])
	for mob in get_tree().get_nodes_in_group("mobs"):
		draw_circle(_to_map(mob.global_position), 2.0, Color("#ff5050"))
	draw_circle(_to_map(arena.player.global_position), 2.5, Color("#7fe0ff"))


func _to_map(world: Vector2) -> Vector2:
	return Vector2(world.x / 16.0 - _origin.x, world.y / 16.0 - _origin.y) * _cell

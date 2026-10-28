class_name WorldNav
extends RefCounted

## The ways about a world for a wizard on foot: every tile one can stand on, joined by the moves between them (see Walkways), and a search for
## the shortest way from one to another. Building it takes a fraction of a second.

var _ways: Walkways
var _astar := AStar2D.new()
var _width := 0


## Builds the map of the ways. blocked is {Vector2i: true}: tiles that bar the way (lava, a gate), which no path goes through. Only the tiles that can
## be left as well as come to, from the tile the map is anchored on, are kept: a wizard that drops into a pit with no way out would be there for good.
func build(cells: TileGrid, bottom: int, blocked := {}, anchor := Vector2i(-1, -1)) -> void:
	_width = cells.size.x
	_ways = Walkways.new(cells, bottom, blocked)
	var tiles := _ways.standing()
	var out := {}  # id -> the ids it leads to
	var back := {}  # id -> the ids that lead to it
	for tile in tiles:
		var from := _id(tile)
		if not out.has(from):
			out[from] = PackedInt32Array()
		for to in _ways.moves(tile):
			out[from].append(_id(to))
			if not back.has(_id(to)):
				back[_id(to)] = PackedInt32Array()
			back[_id(to)].append(from)
	var keep := {}
	if anchor.x >= 0 and not tiles.is_empty():
		var start := tiles[0]  # the place to stand that is nearest the anchor
		for tile in tiles:
			if Vector2(tile).distance_squared_to(Vector2(anchor)) < Vector2(start).distance_squared_to(Vector2(anchor)):
				start = tile
		var forward := _reach(out, _id(start))
		var home := _reach(back, _id(start))
		for id: int in forward:
			if home.has(id):
				keep[id] = true
	else:
		for id: int in out:
			keep[id] = true
	_astar.reserve_space(keep.size())
	for id: int in keep:
		_astar.add_point(id, Vector2(_tile(id)))
	for id: int in keep:
		for to in out[id]:
			if keep.has(to):
				_astar.connect_points(id, to, false)


## Every id that can be got to from one, along these links.
func _reach(links: Dictionary, from: int) -> Dictionary:
	var seen := {from: true}
	var queue := [from]
	while not queue.is_empty():
		var id: int = queue.pop_back()
		for next in links.get(id, PackedInt32Array()):
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen


## How many tiles one can stand on.
func size() -> int:
	return _astar.get_point_count()


func _id(tile: Vector2i) -> int:
	return tile.y * _width + tile.x


func _tile(id: int) -> Vector2i:
	return Vector2i(id % _width, id / _width)


## The tile to stand on that is nearest a point given in tiles, or (-1, -1) when the map is empty.
func nearest(tile: Vector2i) -> Vector2i:
	if _astar.get_point_count() == 0:
		return Vector2i(-1, -1)
	return _tile(_astar.get_closest_point(Vector2(tile)))


## The tiles to go through, from one tile to another, the first being where it starts; empty when there is no way.
func path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not _astar.has_point(_id(from)) or not _astar.has_point(_id(to)):
		return out
	for id in _astar.get_id_path(_id(from), _id(to)):
		out.append(_tile(id))
	return out


## The tiles one can get to from a tile in one move.
func moves(tile: Vector2i) -> Array[Vector2i]:
	return _ways.moves(tile)


## A picture of the map round a tile (see Walkways.sketch).
func sketch(at: Vector2i) -> String:
	return _ways.sketch(at)


## True when one can stand on this tile.
func can_stand(tile: Vector2i) -> bool:
	return _astar.has_point(_id(tile))

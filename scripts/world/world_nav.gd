class_name WorldNav
extends RefCounted

## The ways about a world for a wizard on foot: every tile one can stand on, joined by the moves between them (see Walkways), and a search for
## the shortest way from one to another. Building it takes a fraction of a second.

## What is given when there is no tile (a room's tiles run negative, so (-1, -1) is a place).
const NONE := Vector2i(-1000000, -1000000)

## What a jump really costs over a walk, in tiles of walking: it spends stamina (Wizard.JUMP_COST), which comes back only while standing still (at
## Wizard.STAMINA_REGEN a second), and a wizard in the air goes no faster than it walks, so a jump is never quicker, only dearer.
const JUMP_COST := Wizard.JUMP_COST / Wizard.STAMINA_REGEN * WizardRoute.WALK / WizardRoute.TILE
const SHORT_JUMP := 4  # columns: a jump this short or less might be a walk instead

var _ways: Walkways
var _astar := _Search.new()
var _width := 0
## Where the map's own (0, 0) lies in the world's tiles. A world's map starts at its corner (so this is zero); a room whose columns and rows run negative
## (the tutorial) builds its map from the corner and sets this, and everything asked of the map and given back by it is in the world's tiles.
var origin := Vector2i.ZERO
var version := 0  # counts the times the map has been built, so that a wizard can tell the ways have changed
var _tolls := {}  # key -> the ids of the tiles that cross a gate a wizard needs a spell to pass
var _toll_at := {}  # id -> key


## Builds the map of the ways. blocked is {Vector2i: true}: tiles that bar the way (lava, a gate), which no path goes through. Only the tiles that can
## be left as well as come to, from the tile the map is anchored on, are kept: a wizard that drops into a pit with no way out would be there for good.
func build(cells: TileGrid, bottom: int, blocked := {}, anchor := Vector2i(-1, -1), tolls := {}, links := [], climbs := []) -> void:
	_astar.clear()
	_tolls.clear()
	_toll_at.clear()
	version += 1
	_width = cells.size.x
	_astar.width = _width
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
	var standing := {}
	for tile in tiles:
		standing[tile] = true
	_add_lifts(links, standing, out, back)
	_add_climbs(climbs, standing, out, back)
	var keep := _keep_the_ways_home(tiles, out, back, anchor)
	_astar.reserve_space(keep.size())
	for id: int in keep:
		_astar.add_point(id, Vector2(_tile(id)))
	for id: int in keep:
		for to in out[id]:
			if keep.has(to):
				_astar.connect_points(id, to, false)
	for key: String in tolls:
		_tolls[key] = PackedInt32Array()
		for tile: Vector2i in tolls[key]:
			if _astar.has_point(_id(tile)):
				_tolls[key].append(_id(tile))
				_toll_at[_id(tile)] = key
				_astar.set_point_disabled(_id(tile), true)  # (a crossing is walked only when a path is asked for it: see path)


## The moves up onto a wall and down off it, for each link: moves no one makes without a lift.
func _add_lifts(links: Array, standing: Dictionary, out: Dictionary, back: Dictionary) -> void:
	for link: Dictionary in links:  # up onto a wall, and down off it: moves no one makes without a lift
		for side in ["left", "right"]:
			var top: Vector2i = link["top_" + side]
			var floor_tile := Vector2i(-1, -1)
			for rows in [0, -1, 1, -2, 2, -3, 3]:
				var tile := Vector2i(link[side].x, link[side].y + rows)
				if floor_tile.x < 0 and standing.has(tile):
					floor_tile = tile
			if floor_tile.x >= 0 and standing.has(top):
				for id in [_id(top), _id(floor_tile)]:
					if not back.has(id):
						back[id] = PackedInt32Array()
				out[_id(floor_tile)].append(_id(top))
				out[_id(top)].append(_id(floor_tile))
				back[_id(top)].append(_id(floor_tile))
				back[_id(floor_tile)].append(_id(top))


## Up a vine, or up or down a stair (a fall from a vine's ledge is a move the walking already holds).
func _add_climbs(climbs: Array, standing: Dictionary, out: Dictionary, back: Dictionary) -> void:
	for climb: Dictionary in climbs:  # up a vine, or up or down a stair (a fall from a vine's ledge is a move the walking already holds)
		if standing.has(climb["from"]) and standing.has(climb["to"]):
			out[_id(climb["from"])].append(_id(climb["to"]))
			if not back.has(_id(climb["to"])):
				back[_id(climb["to"])] = PackedInt32Array()
			back[_id(climb["to"])].append(_id(climb["from"]))


## The ids worth keeping: those that can be left as well as come to, from the tile nearest the anchor (all of them when there is no anchor).
func _keep_the_ways_home(tiles: Array[Vector2i], out: Dictionary, back: Dictionary, anchor: Vector2i) -> Dictionary:
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
	return keep


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
func nearest(tile: Vector2i, standing := false) -> Vector2i:
	tile -= origin
	if _astar.get_point_count() == 0:
		return NONE
	if standing and _toll_at.has(_id(tile)) and _astar.has_point(_id(tile)):  # `standing`: the tile is where a wizard is, and it is on a crossing already (on top of a wall it was lifted over): that is where it stands
		return tile + origin
	return _tile(_astar.get_closest_point(Vector2(tile))) + origin


## The tiles to go through, from one tile to another, the first being where it starts; empty when there is no way. `shut` lists the
## crossings (by key) that the one asking cannot pass: the way does not go over them, and nearest() never lands on one.
func path(from: Vector2i, to: Vector2i, shut := []) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	from -= origin
	to -= origin
	if not _astar.has_point(_id(from)) or not _astar.has_point(_id(to)):
		return out
	for key: String in _tolls:
		for id in _tolls[key]:
			_astar.set_point_disabled(id, shut.has(key))
	for id in _astar.get_id_path(_id(from), _id(to)):
		out.append(_tile(id) + origin)
	for key: String in _tolls:
		for id in _tolls[key]:
			_astar.set_point_disabled(id, true)
	return out


## The key of the crossing a tile lies on, or "".
func toll_at(tile: Vector2i) -> String:
	tile -= origin
	return _toll_at.get(_id(tile), "")


## The tiles one can get to from a tile in one move.
func moves(tile: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for to in _ways.moves(tile - origin):
		out.append(to + origin)
	return out


## A picture of the map round a tile (see Walkways.sketch).
func sketch(at: Vector2i) -> String:
	return _ways.sketch(at - origin)


## True when one can stand on this tile.
func can_stand(tile: Vector2i) -> bool:
	tile -= origin
	return _astar.has_point(_id(tile))


## The search itself: each move costs its length, and a jump what it costs besides, so a way that can be walked is walked.
class _Search extends AStar2D:
	var width := 1

	func _compute_cost(from_id: int, to_id: int) -> float:
		var dx := absi(from_id % width - to_id % width)
		var dy := to_id / width - from_id / width
		var dist := sqrt(float(dx * dx + dy * dy))
		if dx >= 2 and dx <= SHORT_JUMP and absi(dy) < WizardRoute.CLIMB_ROWS:  # (a long leap over a pit has no walk to be chosen instead)
			return dist + JUMP_COST
		return dist

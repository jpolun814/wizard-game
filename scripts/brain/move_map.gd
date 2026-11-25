class_name MoveMap
extends RefCounted

## The ground as the AI pictures it: which tiles are rock, where a wizard can stand, and where each of those places leads on foot (Walkways). One is made for a world and shared by
## all its wizards; what each of them has seen of it is asked of them by whoever plans (MovePlan).

const TILE := ArenaGen.TILE

var origin := Vector2i.ZERO
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var width := 0
var height := 0
var grid := PackedByteArray()   # which tiles are rock, row by row
var _ways: Walkways
var _steps := {}      # tile id -> the tiles one walk, fall or jump leads to, found once asked for
var _climbs := {}     # tile -> the tiles a vine or a stair of the world's leads to from it
var edges := {}       # what the spells do from a place, once worked out: the same for every wizard (MovePlan)
var _lips := {}       # column -> the floors that end there: [row, the open side (-1 or 1)]
var _turns := {}      # tile id -> whether the walking ends near it: where it may pay to try a spell


func _init(cells: TileGrid, bottom: int, at := Vector2i.ZERO, hazards := {}, climbs := []) -> void:
	origin = at
	width = cells.size.x
	height = cells.size.y
	grid = cells.data
	_ways = Walkways.new(cells, bottom, hazards)
	for climb: Dictionary in climbs:
		var from: Vector2i = climb["from"] + origin
		if not _climbs.has(from):
			_climbs[from] = []
		_climbs[from].append(climb["to"] + origin)
	_find_lips()


func solid(tile: Vector2i) -> bool:
	var c := tile.x - origin.x
	var r := tile.y - origin.y
	if c < 0 or c >= width:
		return true  # the sides of the map
	return r >= 0 and r < height and grid[r * width + c] != 0


func solid_at(point: Vector2) -> bool:
	return solid(Vector2i(floori(point.x / TILE), floori(point.y / TILE)))


## Rock anywhere on an upright line.
func solid_span(x: float, top: float, bottom: float) -> bool:
	var c := floori(x / TILE) - origin.x
	if c < 0 or c >= width:
		return true
	for r in range(maxi(floori(top / TILE) - origin.y, 0), mini(floori(bottom / TILE) - origin.y, height - 1) + 1):
		if grid[r * width + c] != 0:
			return true
	return false


## Rock anywhere on a level line.
func solid_row(left: float, right: float, y: float) -> bool:
	var r := floori(y / TILE) - origin.y
	if r < 0 or r >= height:
		return false
	for c in range(floori(left / TILE) - origin.x, floori(right / TILE) - origin.x + 1):
		if c < 0 or c >= width or grid[r * width + c] != 0:
			return true
	return false


func can_stand(tile: Vector2i) -> bool:
	return _ways.can_stand(tile - origin)


## Below this a fall is for good.
func bottom_y() -> float:
	return float((origin.y + height) * TILE)


func id(tile: Vector2i) -> int:
	return (tile.y - origin.y + 64) * (width + 2) + tile.x - origin.x + 1  # (a body may hang above the top of the map)


## The places one move on foot leads to.
func steps(tile: Vector2i) -> Array[Vector2i]:
	var key := id(tile)
	if not _steps.has(key):
		var found: Array[Vector2i] = []
		var far := {}
		for to in _ways.moves(tile - origin):
			if not far.has(to):
				far[to] = true
				found.append(to + origin)
		for to: Vector2i in _climbs.get(tile, []):
			if can_stand(to) and not far.has(to):
				found.append(to)
		_steps[key] = found
	return _steps[key]


## Whether a move on foot is a climb or a stair of the world's.
func climbs(from: Vector2i, to: Vector2i) -> bool:
	return _climbs.has(from) and to in _climbs[from]


## The soles of a wizard standing on a tile.
static func feet(tile: Vector2i) -> Vector2:
	return Vector2((tile.x + 0.5) * TILE, (tile.y + 1.0) * TILE)


## Whether a walk along the floor goes on from a tile to the next column (level, or a tile up or down).
func walks_on(tile: Vector2i, dir: int) -> bool:
	for dy in [0, -1, 1]:
		if can_stand(tile + Vector2i(dir, dy)):
			return true
	return false


## Whether it may pay to try a spell from here: the walking ends within a few columns (at a drop or a face), or there is the edge of a floor overhead to come up past.
func turns(tile: Vector2i, within: int) -> bool:
	var key := id(tile)
	if not _turns.has(key):
		_turns[key] = _is_turn(tile, within)
	return _turns[key]


func _is_turn(tile: Vector2i, within: int) -> bool:
	for dir: int in [-1, 1]:
		var here := tile
		for k in within:
			if not walks_on(here, dir):
				return true
			for dy in [0, -1, 1]:
				if can_stand(here + Vector2i(dir, dy)):
					here += Vector2i(dir, dy)
					break
	for rise in range(4, 20):
		if solid(tile + Vector2i(0, -rise)):
			break
		for dir: int in [-1, 1]:
			for k in range(1, 4):
				var over := tile + Vector2i(dir * k, -rise)
				if can_stand(over) and not walks_on(over, -dir):
					return true
	return false


## How many rows up it would come level with the floors that end near here and are open toward it, on a side (-1 or 1), up to so many rows: the heights worth leaning over at.
func ledges(tile: Vector2i, dir: int, across: int, up: int) -> Array[int]:
	var out: Array[int] = []
	for k in range(1, across + 1):
		for lip: Vector2i in _lips.get(tile.x + dir * k, []):
			var rise := tile.y - lip.x
			if lip.y == -dir and rise >= 2 and rise <= up and not out.has(rise):
				out.append(rise)
	return out


func _find_lips() -> void:
	for at in _ways.standing():
		var tile := at + origin
		for dir: int in [-1, 1]:
			if not walks_on(tile, dir) and not solid(tile + Vector2i(dir, 0)):
				if not _lips.has(tile.x):
					_lips[tile.x] = []
				_lips[tile.x].append(Vector2i(tile.y, dir))

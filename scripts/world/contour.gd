class_name Contour
extends RefCounted

## Traces the edge between rock and open air in a TileGrid into smooth closed outlines.
##
## Each window of four tile centres has the outline pass through the middles of its edges (marching squares), so a wall of tiles
## is a straight line on the tile boundary and a staircase of tiles is a slope. The outlines are then spread evenly, rounded off
## and thinned where they run straight. Walking a whole world's tiles one by one would take seconds, so each row is read as runs
## of rock with the packed array's own search, and only the windows where a row differs from the one below it, or where a run
## starts or ends, are looked at.

const EDGE_PAIRS := {
	1: [["L", "T"]], 2: [["T", "R"]], 3: [["L", "R"]], 4: [["R", "B"]], 5: [["L", "T"], ["R", "B"]], 6: [["T", "B"]],
	7: [["L", "B"]], 8: [["L", "B"]], 9: [["T", "B"]], 10: [["T", "R"], ["L", "B"]], 11: [["R", "B"]], 12: [["L", "R"]],
	13: [["T", "R"]], 14: [["L", "T"]],
}
const CORNER_OF := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]  # TL, TR, BR, BL, in cells
const SPACING := 10.0      # pixels between the points of a smoothed outline
const SMOOTHING := 14      # passes that round an outline's corners
const SMALL_LOOP := 700.0  # an outline shorter than this (a stepping stone) is barely smoothed, so it stays itself

var _grid: TileGrid
var _stone_only := false
var _stone_zone := Rect2i()  # the tiles around castle stone: outlines there keep their square edges
var _has_stone := false


## The outlines between air and rock (or, with stone_only, between air or rock and castle stone), each smoothed. Rock is on the
## right of the way an outline runs. The edge of the world counts as rock.
static func trace(grid: TileGrid, stone_only: bool) -> Array:
	var contour := Contour.new()
	contour._grid = grid
	contour._stone_only = stone_only
	contour._find_stone()
	return contour._run()


func _find_stone() -> void:
	var w := _grid.size.x
	var first := Vector2i(1 << 20, 1 << 20)
	var last := Vector2i(-1, -1)
	for r in _grid.size.y:
		var row := _grid.data.slice(r * w, (r + 1) * w)
		var at := row.find(ArenaGen.STONE + 1)
		if at < 0:
			continue
		var back := row.rfind(ArenaGen.STONE + 1)
		first = Vector2i(mini(first.x, at), mini(first.y, r))
		last = Vector2i(maxi(last.x, back), maxi(last.y, r))
	_has_stone = last.x >= 0
	if _has_stone:
		_stone_zone = Rect2i(first - Vector2i(2, 2), last - first + Vector2i(5, 5))


func _run() -> Array:
	var size := _grid.size
	var t := float(ArenaGen.TILE)
	var width := size.x + 4
	var spots := {}   # edge key -> where the outline crosses that edge
	var onward := {}  # edge key -> the next edge key, with rock on the right
	var upper := _runs(-1)
	for j in range(-1, size.y):
		var lower := _runs(j + 1)
		for i in _windows(upper, lower, size.x):
			var solid := [_solid(i, j), _solid(i + 1, j), _solid(i + 1, j + 1), _solid(i, j + 1)]
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
		upper = lower
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


## True when a tile is rock (or castle stone, when tracing that), counting everything outside the world as rock.
func _solid(c: int, r: int) -> bool:
	var size := _grid.size
	if c < 0 or r < 0 or c >= size.x or r >= size.y:
		return not _stone_only
	var value := _grid.data[r * size.x + c]
	return value == ArenaGen.STONE + 1 if _stone_only else value != 0


## The runs of rock in a row, as [start, end, start, end, ...] with the end not included, from column -1 to the one past the world's
## end. A row above or below the world is rock all the way across, unless only castle stone is wanted.
func _runs(r: int) -> PackedInt32Array:
	var w := _grid.size.x
	var out := PackedInt32Array()
	if r < 0 or r >= _grid.size.y:
		if not _stone_only:
			out.append(-1)
			out.append(w + 1)
		return out
	var row := _grid.data.slice(r * w, (r + 1) * w)
	var solid_values := [ArenaGen.STONE + 1] if _stone_only else [ArenaGen.GROUND + 1, ArenaGen.STONE + 1]
	var air_values := [0, ArenaGen.GROUND + 1] if _stone_only else [0]
	var at := 0
	while at < w:
		var start := _first(row, at, solid_values)
		if start >= w:
			break
		var end := _first(row, start, air_values)
		out.append(start)
		out.append(end)
		at = end
	if not _stone_only:
		# The columns just outside the world are rock, and join the runs at either end.
		if out.is_empty() or out[0] > 0:
			out.insert(0, -1)
			out.insert(1, 0)
		else:
			out[0] = -1
		if out[out.size() - 1] < w:
			out.append(w)
			out.append(w + 1)
		else:
			out[out.size() - 1] = w + 1
	return out


static func _first(row: PackedByteArray, from: int, values: Array) -> int:
	var best := row.size()
	for value: int in values:
		var found := row.find(value, from)
		if found >= 0 and found < best:
			best = found
	return best


static func _covered(runs: PackedInt32Array, column: int) -> bool:
	for k in range(0, runs.size(), 2):
		if column >= runs[k] and column < runs[k + 1]:
			return true
	return false


## The first column of every window between two rows that is not all rock or all air: where a run starts or ends in either row,
## and where one row is rock and the other is not. In order, each once.
static func _windows(upper: PackedInt32Array, lower: PackedInt32Array, width: int) -> PackedInt32Array:
	var marks := PackedInt32Array()
	marks.append_array(upper)
	marks.append_array(lower)
	marks.sort()
	var picked := PackedInt32Array()
	for e in marks:
		picked.append(e - 1)  # the window across a run's edge
	for k in range(marks.size() - 1):
		if marks[k] == marks[k + 1]:
			continue
		if _covered(upper, marks[k]) != _covered(lower, marks[k]):
			for column in range(marks[k] - 1, marks[k + 1]):  # one row is rock here and the other is not
				picked.append(column)
	picked.sort()
	var out := PackedInt32Array()
	for column in picked:
		if column >= -1 and column < width and (out.is_empty() or out[out.size() - 1] != column):
			out.append(column)
	return out


## True when a point of an outline is beside castle stone.
func _near_stone(point: Vector2) -> bool:
	if not _has_stone:
		return false
	var t := float(ArenaGen.TILE)
	var column := int(floor(point.x / t))
	var row := int(floor(point.y / t))
	if not _stone_zone.has_point(Vector2i(column, row)):
		return false
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c := column + dx
			var r := row + dy
			if c >= 0 and r >= 0 and c < _grid.size.x and r < _grid.size.y and _grid.data[r * _grid.size.x + c] == ArenaGen.STONE + 1:
				return true
	return false


## An outline spread evenly along its length, then rounded off by averaging each point with its neighbours, then thinned
## where it runs straight.
func _smooth(points: PackedVector2Array) -> PackedVector2Array:
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
	# Castle stone keeps the edges it was built with: straight walls, flat tops and square towers, not rounded hills.
	var firm := PackedByteArray()
	for point in even:
		firm.append(1 if _near_stone(point) else 0)
	for pass_index in passes:
		var next := PackedVector2Array()
		for n in even.size():
			if firm[n] == 1:
				next.append(even[n])
			else:
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


static func area(points: PackedVector2Array) -> float:
	var sum := 0.0
	for k in points.size():
		var p := points[k]
		var q := points[(k + 1) % points.size()]
		sum += p.x * q.y - q.x * p.y
	return sum * 0.5

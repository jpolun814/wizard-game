class_name LiquidGrid
extends RefCounted

## Water (or lava) that really flows. The space round a pool is cut into small square cells, each holding an amount of liquid from nothing to
## a full cell. Every step, each cell gives some of what it holds to the cell below, then to the cells either side, and pushes up when it holds
## more than it should (so a full tube lifts the liquid in its other arm). From just that, liquid falls, spreads out flat, fills a pit dug
## beside it, and settles level in vessels that join, with nothing aimed at any of them. It is the way a tile game like Terraria does it.
##
## Only the cells with liquid in them are worked on, and once nothing moves any more the grid goes to sleep and costs nothing until
## something wakes it (see Pond, which wakes it when the ground changes).

const LEFT := 1
const RIGHT := 2
const UP := 4
const DOWN := 8
const CELL := 16.0
const MAX_MASS := 1.0       # what a cell holds before it is full
const MAX_COMPRESS := 0.02  # how much more a cell under a full column holds, which is what pushes liquid back up
const MIN_MASS := 0.01      # less than this in a cell is too little to see or to wade in (it is still there, and still flows)
const MIN_FLOW := 0.005     # flows smaller than this are not eased, so a trickle still reaches the end
const MAX_SPEED := 1.0      # the most a cell gives to one neighbour in a step
const SIDE_RATE := 0.4      # the share of the difference between two neighbours that flows across in a step
const SIDE_EASE := 0.8      # and how much of that is let through, which keeps the surface from sloshing
const QUIET_STEPS := 12     # steps in which almost nothing moves before the grid goes to sleep
const QUIET_FLOW := 0.012

var cols := 0
var rows := 0
var origin := Vector2.ZERO  # the world position of the top left corner of the first cell
var solid := PackedByteArray()  # 1 where a cell is ground
var mass := PackedFloat32Array()
var asleep := true
var version := 0  # goes up whenever the liquid changes, so a drawing can tell it is out of date

var _next := PackedFloat32Array()
var _quiet := 0
var _band := Rect2i()  # the columns and rows that hold liquid, with one to spare


## Lays out the cells over a rectangle of the world, widened to whole cells. Nothing is solid and nothing is wet yet.
func setup(area: Rect2) -> void:
	var first := Vector2(floorf(area.position.x / CELL), floorf(area.position.y / CELL))
	var last := Vector2(ceilf(area.end.x / CELL), ceilf(area.end.y / CELL))
	origin = first * CELL
	cols = int(last.x - first.x)
	rows = int(last.y - first.y)
	solid.resize(cols * rows)
	solid.fill(0)
	mass.resize(cols * rows)
	mass.fill(0.0)
	_next = mass.duplicate()


## Adds cells on any side, for liquid that has run to the edge of the grid. The new cells are ground until they are read (see read_ground), so liquid
## stays where it is until the ground there is known.
func grow(left: int, right: int, up: int, down: int) -> void:
	var new_cols := cols + left + right
	var new_rows := rows + up + down
	var wall_left := PackedByteArray()
	wall_left.resize(left)
	wall_left.fill(1)
	var wall_right := PackedByteArray()
	wall_right.resize(right)
	wall_right.fill(1)
	var wall_row := PackedByteArray()
	wall_row.resize(new_cols)
	wall_row.fill(1)
	var dry_left := PackedFloat32Array()
	dry_left.resize(left)
	var dry_right := PackedFloat32Array()
	dry_right.resize(right)
	var dry_row := PackedFloat32Array()
	dry_row.resize(new_cols)
	var new_solid := PackedByteArray()
	var new_mass := PackedFloat32Array()
	for r in new_rows:
		var old_row := r - up
		if old_row < 0 or old_row >= rows:
			new_solid.append_array(wall_row)
			new_mass.append_array(dry_row)
		else:
			new_solid.append_array(wall_left)
			new_solid.append_array(solid.slice(old_row * cols, (old_row + 1) * cols))
			new_solid.append_array(wall_right)
			new_mass.append_array(dry_left)
			new_mass.append_array(mass.slice(old_row * cols, (old_row + 1) * cols))
			new_mass.append_array(dry_right)
	origin -= Vector2(left, up) * CELL
	cols = new_cols
	rows = new_rows
	solid = new_solid
	mass = new_mass
	_next = mass.duplicate()
	wake()


## Which edges of the grid have liquid against them, as a set of the four flags: LEFT, RIGHT, UP and DOWN. Liquid that has run that far wants more room.
func edges_wet(least: float) -> int:
	var found := 0
	for r in rows:
		if mass[r * cols] > least:
			found |= LEFT
		if mass[r * cols + cols - 1] > least:
			found |= RIGHT
	for c in cols:
		if mass[c] > least:
			found |= UP
		if mass[(rows - 1) * cols + c] > least:
			found |= DOWN
	return found


func world_rect() -> Rect2:
	return Rect2(origin, Vector2(cols, rows) * CELL)


func center_of(column: int, row: int) -> Vector2:
	return origin + (Vector2(column, row) + Vector2(0.5, 0.5)) * CELL


## Marks which cells are ground, by asking `is_solid` about each cell's middle. Only the cells inside `area` are looked at again.
func read_ground(is_solid: Callable, area := Rect2()) -> void:
	var c0 := 0
	var c1 := cols - 1
	var r0 := 0
	var r1 := rows - 1
	if area.has_area():
		c0 = clampi(int(floorf((area.position.x - origin.x) / CELL)), 0, cols - 1)
		c1 = clampi(int(floorf((area.end.x - origin.x) / CELL)), 0, cols - 1)
		r0 = clampi(int(floorf((area.position.y - origin.y) / CELL)), 0, rows - 1)
		r1 = clampi(int(floorf((area.end.y - origin.y) / CELL)), 0, rows - 1)
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var ground: bool = is_solid.call(center_of(c, r))
			solid[r * cols + c] = 1 if ground else 0
			if ground:
				mass[r * cols + c] = 0.0
	wake()


## Reads the ground for some whole rows only, without waking the liquid: a pool does a few rows a frame so that making it never stalls the game.
func read_rows(is_solid: Callable, first_row: int, last_row: int) -> void:
	for r in range(first_row, mini(last_row, rows - 1) + 1):
		for c in cols:
			var ground: bool = is_solid.call(center_of(c, r))
			solid[r * cols + c] = 1 if ground else 0


## The columns that hold liquid, as a first and a last (with one to spare), so a drawing need not look at the rest.
func wet_columns() -> Vector2i:
	return Vector2i(maxi(_band.position.x - 1, 0), mini(_band.end.x + 1, cols - 1))


## Fills every open cell whose middle lies in a rectangle of the world with liquid.
func fill(area: Rect2) -> void:
	for r in rows:
		for c in cols:
			var i := r * cols + c
			if solid[i] == 0 and area.has_point(center_of(c, r)):
				mass[i] = MAX_MASS
	wake()


## Puts liquid into the cell at a point, and into the cells above it when that one is full. Returns how much went in (all of it, unless the
## point is outside the grid or buried in ground).
func add(point: Vector2, amount: float) -> float:
	var cell := cell_at(point)
	if cell.x < 0 or cell.y < 0 or cell.x >= cols or cell.y >= rows:
		return 0.0
	var left := amount
	var r := cell.y
	while left > 0.0 and r >= 0:
		var i := r * cols + cell.x
		if solid[i] == 0:
			var room := MAX_MASS - mass[i]
			var put := minf(left, maxf(room, 0.0))
			mass[i] += put
			left -= put
		r -= 1
	wake()
	return amount - left


## Takes liquid from the cells whose middles lie in a rectangle, the highest first, up to an amount. Returns how much was taken.
func take(area: Rect2, amount: float) -> float:
	var left := amount
	var first := cell_at(area.position)
	var last := cell_at(area.end)
	for r in range(maxi(first.y, 0), mini(last.y, rows - 1) + 1):
		for c in range(maxi(first.x, 0), mini(last.x, cols - 1) + 1):
			if left <= 0.0:
				break
			var i := r * cols + c
			if mass[i] > 0.0 and area.has_point(center_of(c, r)):
				var took := minf(mass[i], left)
				mass[i] -= took
				left -= took
	if left < amount:
		wake()
	return amount - left


func wake() -> void:
	asleep = false
	_quiet = 0
	version += 1
	_band = Rect2i(0, 0, cols, rows)


## How much liquid there is in all, which only a thing that adds or takes liquid away changes.
func total() -> float:
	var sum := 0.0
	for m in mass:
		sum += m
	return sum


func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori((point.x - origin.x) / CELL), floori((point.y - origin.y) / CELL))


func mass_at(point: Vector2) -> float:
	var cell := cell_at(point)
	if cell.x < 0 or cell.y < 0 or cell.x >= cols or cell.y >= rows:
		return 0.0
	return mass[cell.y * cols + cell.x]


## True where a point is under the liquid's surface.
func wet_at(point: Vector2) -> bool:
	var cell := cell_at(point)
	if cell.x < 0 or cell.y < 0 or cell.x >= cols or cell.y >= rows:
		return false
	var i := cell.y * cols + cell.x
	if mass[i] <= MIN_MASS:
		return false
	# A cell that is not full is wet only below its own surface.
	if mass[i] < MAX_MASS and (i - cols < 0 or mass[i - cols] <= MIN_MASS):
		return point.y >= origin.y + (cell.y + 1.0 - mass[i]) * CELL
	return true


## The height of the liquid's surface in the column at a world x: the top of the highest liquid there. INF where the column is dry.
func surface_at(x: float) -> float:
	var c := floori((x - origin.x) / CELL)
	if c < 0 or c >= cols:
		return INF
	for r in rows:
		var m := mass[r * cols + c]
		if m > MIN_MASS:
			return origin.y + (r + 1.0 - minf(m, MAX_MASS)) * CELL
	return INF


## The stretches of liquid in a column, top to bottom, each as [top height, bottom height, open to the air above, ground to the left, ground to the right,
## ground below]: what a drawing needs.
func runs_in(c: int) -> Array:
	var out := []
	var top := -1
	for r in range(maxi(_band.position.y - 1, 0), mini(_band.end.y + 2, rows + 1)):
		var wet := r < rows and mass[r * cols + c] > MIN_MASS
		if wet and top < 0:
			top = r
		elif not wet and top >= 0:
			var m := mass[top * cols + c]
			var start := origin.y + (top + 1.0 - minf(m, MAX_MASS)) * CELL if (top == 0 or mass[(top - 1) * cols + c] <= MIN_MASS) else origin.y + top * CELL
			var mid := (top + r - 1) / 2
			out.append([start, origin.y + r * CELL, top > 0 and solid[(top - 1) * cols + c] == 0,
					c == 0 or solid[mid * cols + c - 1] == 1, c == cols - 1 or solid[mid * cols + c + 1] == 1, r < rows and solid[r * cols + c] == 1])
			top = -1
	return out


## What a cell should hold, with the one above it, if it were to carry its share of the pressure (the "stable" mass of the bottom cell).
static func _stable(total_mass: float) -> float:
	if total_mass <= MAX_MASS:
		return MAX_MASS
	if total_mass < 2.0 * MAX_MASS + MAX_COMPRESS:
		return (MAX_MASS * MAX_MASS + total_mass * MAX_COMPRESS) / (MAX_MASS + MAX_COMPRESS)
	return (total_mass + MAX_COMPRESS) / 2.0


## One step of flow. Returns true while the liquid is still moving; when it comes to rest the grid sleeps.
func step() -> bool:
	if asleep:
		return false
	_next = mass.duplicate()
	var first_row := rows
	var last_row := -1
	var first_col := cols
	var last_col := -1
	var moved := 0.0
	var r0 := maxi(_band.position.y, 0)
	var r1 := mini(_band.end.y - 1, rows - 1)
	var c0 := maxi(_band.position.x, 0)
	var c1 := mini(_band.end.x - 1, cols - 1)
	for r in range(r0, r1 + 1):
		var base := r * cols
		for c in range(c0, c1 + 1):
			var i := base + c
			var remaining := mass[i]
			if remaining <= 0.0:
				continue
			if r < first_row:
				first_row = r
			if r > last_row:
				last_row = r
			if c < first_col:
				first_col = c
			if c > last_col:
				last_col = c
			# Down first: liquid falls whenever there is room.
			if r + 1 < rows and solid[i + cols] == 0:
				var below := mass[i + cols]
				var flow := _stable(remaining + below) - below
				if flow > MIN_FLOW:
					flow *= 0.5
				flow = clampf(flow, 0.0, minf(MAX_SPEED, remaining))
				if flow > 0.0:
					_next[i] -= flow
					_next[i + cols] += flow
					remaining -= flow
					moved = maxf(moved, flow)
			if remaining <= 0.0:
				continue
			# Then out to either side, from the fuller cell to the emptier one.
			if c > 0 and solid[i - 1] == 0:
				var flow := (remaining - mass[i - 1]) * SIDE_RATE
				if flow > MIN_FLOW:
					flow *= SIDE_EASE
				flow = clampf(flow, 0.0, remaining)
				if flow > 0.0:
					_next[i] -= flow
					_next[i - 1] += flow
					remaining -= flow
					moved = maxf(moved, flow)
			if remaining <= 0.0:
				continue
			if c + 1 < cols and solid[i + 1] == 0:
				var flow := (remaining - mass[i + 1]) * SIDE_RATE
				if flow > MIN_FLOW:
					flow *= SIDE_EASE
				flow = clampf(flow, 0.0, remaining)
				if flow > 0.0:
					_next[i] -= flow
					_next[i + 1] += flow
					remaining -= flow
					moved = maxf(moved, flow)
			if remaining <= 0.0:
				continue
			# And up, when this cell holds more than the weight above it allows.
			if r > 0 and solid[i - cols] == 0:
				var flow := remaining - _stable(remaining + mass[i - cols])
				if flow > MIN_FLOW:
					flow *= 0.5
				flow = clampf(flow, 0.0, minf(MAX_SPEED, remaining))
				if flow > 0.0:
					_next[i] -= flow
					_next[i - cols] += flow
					moved = maxf(moved, flow)
	var swap := mass
	mass = _next
	_next = swap
	if last_row < 0:
		asleep = true
		version += 1
		return false
	_band = Rect2i(maxi(first_col - 1, 0), maxi(first_row - 1, 0), mini(last_col + 2, cols) - maxi(first_col - 1, 0), mini(last_row + 2, rows) - maxi(first_row - 1, 0))
	version += 1
	if moved < QUIET_FLOW:
		_quiet += 1
		if _quiet >= QUIET_STEPS:
			asleep = true
	else:
		_quiet = 0
	return not asleep

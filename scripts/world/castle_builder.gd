class_name CastleBuilder
extends RefCounted

## A castle on level ground, in stone, with battlements, and rooms on six floors inside it: a cellar under the ground, the ground floor, and four floors
## over it. Everything is carved out of solid stone, so nothing floats: floors and ceilings are stone, and walls stand between the rooms of a floor
## with a doorway in each, tall enough for a giant. The floors lie one over another, a whole way through the castle: three rooms in a row from the gate
## to the back door on every floor. In each room a stairwell is cut up through the floors, with swinging stairs hung in it (see SwingStair), so the floors
## are joined by whichever way the stairs have swung; only the middle room's goes down to the cellar. The towers are stone with small windows, only there to be seen.
## Returns {"hall": the rooms inside, as one rectangle of tiles per column, so they can be painted as the inside of a building,
## "planks": [{"hinge", "ends": the places its free end can be, in pixels, "ways": the {from, to} landing tiles each joins}], one for every swinging stair.

const AIR := 9  # rows of air in a hall or a room
const SLAB := 2  # rows of stone between the storeys
const DOOR := 8  # rows tall a doorway is: tall enough for a giant to walk through
const TOWER := 63  # rows the gate tower and the back tower stand above the ground, a little over the rest of the castle
const WELL_WIDTH := 11  # eleven wide, so a plank across it climbs at about 45 degrees
const WIDTH := 90  # columns the castle takes on the surface (SurfaceGen keeps the same)
const ROWS: Array[Vector2i] = [Vector2i(4, 27), Vector2i(30, 53), Vector2i(56, 79)]  # the rooms of a floor, as the first and last column of each; the walls between them take the two columns after each room

var _cells: TileGrid
var _ground: int  # the row of the ground the castle stands on
var _x: int  # the first column of the castle
var _hall: Array = []
var _planks: Array = []  # {"hinge", "ends": the places its free end can be, in pixels, "ways": the {from, to} tiles each joins}

var _floor_1 := AIR + SLAB  # height of the first floor's floor
var _floor_2 := _floor_1 + AIR + SLAB  # and of each of the floors over it
var _floor_3 := _floor_2 + AIR + SLAB
var _floor_4 := _floor_3 + AIR + SLAB
var _top_4 := _floor_4 + AIR - 1  # the highest row of air in the castle
var _floor_cellar := -(AIR + SLAB)  # the cellar's floor: a whole storey down, under the ground floor's slab


func _init(cells: TileGrid, ground: int, x: int) -> void:
	_cells = cells
	_ground = ground
	_x = x


## `gate` is true when there is a castle before this one (its outer wall has a doorway), `back` when there is one after it.
func build(gate := true, back := true) -> Dictionary:
	_raise_walls()
	_cut_entrance(gate)
	_cut_floors()
	_cut_back(back)
	_cut_stairwells()
	_cut_windows()
	return {"hall": _hall, "planks": _planks}


## The whole of it, solid: the towers at each end, with merlons on top.
func _raise_walls() -> void:
	for i in WIDTH:
		var top := _top_4 + 1 + SLAB
		if i < 10 or i >= WIDTH - 8:
			top = TOWER
		if (i / 2) % 2 == 0:
			top += 2  # a merlon
		for h in range(_floor_cellar - SLAB, top):  # from under the cellar's floor: the slabs of the two lowest floors are brick like the rest, not the ground's rock
			_cells.put(Vector2i(_x + i, _ground - 1 - h), ArenaGen.STONE)


## Air, from height low to height high inclusive in one column, painted as a room.
func _carve(i: int, low: int, high: int) -> void:
	for h in range(low, high + 1):
		_cells.erase(Vector2i(_x + i, _ground - 1 - h))
	_hall.append(Rect2i(_x + i, _ground - 1 - high, 1, high - low + 1))


## A room: columns from first to last inclusive, from the floor to the top of its air.
func _room(first: int, last: int, floor_h: int, high: int) -> void:
	for i in range(first, last + 1):
		_carve(i, floor_h, high)


## A wall between two rooms, two columns thick, with a doorway through it.
func _door(i: int, floor_h: int) -> void:
	for k in 2:
		_carve(i + k, floor_h, floor_h + DOOR - 1)


## The gate: a doorway in the outer wall, which opens on the next castle's back door (the first has none: nothing is outside it), and a porch behind it.
func _cut_entrance(gate: bool) -> void:
	if gate:
		_door(0, 0)
	_carve(2, 0, AIR - 1)
	_carve(3, 0, AIR - 1)


## The back door out of the last room, the room behind it, and the door in the outer wall at the back.
func _cut_back(back: bool) -> void:
	_door(80, 0)  # the back door
	_room(82, 85, 0, AIR - 1)
	_carve(86, 0, AIR - 1)
	_carve(87, 0, AIR - 1)
	if back:
		_door(88, 0)


## Every floor, cellar to top, as three rooms in a row with a doorway through each wall between them.
func _cut_floors() -> void:
	for k in ROWS.size():
		for floor_h: int in [_floor_cellar, 0, _floor_1, _floor_2, _floor_3, _floor_4]:
			_room(ROWS[k].x, ROWS[k].y, floor_h, floor_h + AIR - 1)
			if k + 1 < ROWS.size():
				_door(ROWS[k].y + 1, floor_h)


## Stairwells: a shaft cut through the floors, with planks hung in it. Each plank is hinged at a landing on one side of the shaft and swings among
## landings on the other, so the floors are joined by whichever way the planks have swung (see SwingStair).
func _cut_stairwells() -> void:
	var up := [[-1, _floor_1, [0, _floor_1, _floor_2]], [1, _floor_2, [_floor_1, _floor_2, _floor_3]], [-1, _floor_3, [_floor_2, _floor_3, _floor_4]], [1, _floor_4, [_floor_3, _floor_4]]]
	_well(ROWS[1].x + 6, _floor_cellar, [[1, 0, [_floor_cellar, 0, _floor_1]]] + up)  # the middle room's goes down to the cellar too
	for k in [0, 2]:
		_well(ROWS[k].x + 6, 0, up)  # (the ground floor is solid under the others, and walked across)


## One stairwell. A spec is [which side the plank is fastened on (-1 the left, 1 the right), the floor it is fastened at, the floors its free end swings among].
func _well(left_col: int, low: int, specs: Array) -> void:
	var right_col: int = left_col + WELL_WIDTH - 1
	for i in range(left_col, right_col + 1):
		_carve(i, low, _top_4)
	var well_left: int = _x + left_col
	var well_right: int = _x + right_col + 1
	for spec: Array in specs:
		var hinge_side: int = spec[0]
		var hinge_floor: int = spec[1]
		var ends: Array = []
		var ways: Array = []
		var from := Vector2i(well_left - 1 if hinge_side < 0 else well_right, _ground - 1 - hinge_floor)
		for h: int in spec[2]:
			ends.append(Vector2(float(well_right if hinge_side < 0 else well_left) * ArenaGen.TILE, float(_ground - h) * ArenaGen.TILE))
			ways.append({"from": from, "to": Vector2i(well_right if hinge_side < 0 else well_left - 1, _ground - 1 - h)})
		_planks.append({"hinge": Vector2(float(well_left if hinge_side < 0 else well_right) * ArenaGen.TILE, float(_ground - hinge_floor) * ArenaGen.TILE), "ends": ends, "ways": ways})


## Windows: pockets of air in the solid stone of the towers, seen from outside as dark slits.
func _cut_windows() -> void:
	for i in [1, 83, WIDTH - 2]:
		for h in [12, 24, 36, 48]:
			for row in 3:
				_cells.erase(Vector2i(_x + i, _ground - 1 - (h + row)))

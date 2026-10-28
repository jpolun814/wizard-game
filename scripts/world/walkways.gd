class_name Walkways
extends RefCounted

## Where a wizard can stand in a world, and where each of those places leads: a walk to the next column (level, or a tile up), a fall off an
## edge, or a jump (up to JUMP_ROWS higher, across at the same height, or down to a lower landing). The generator uses it to test that every
## room can be reached, and the wizards that walk the world use it to find their way. It is a little stricter than the real jump, so a world
## that passes is walkable. The tiles worth standing on are worked out once, in packed arrays, and the moves only read them: a world is
## hundreds of thousands of tiles.

var _w := 0
var _h := 0
var _bottom := 0
var _solid := PackedByteArray()
var _clear_at := PackedByteArray()  # WorldBuilder.HEADROOM clear tiles from here up
var _stand := PackedByteArray()     # clear, supported from below, and not in lava


## cells is the world's TileGrid; bottom the row below which a fall does not count; hazards the tiles ({Vector2i: true}) one cannot stand in.
func _init(cells: TileGrid, bottom: int, hazards := {}) -> void:
	_w = cells.size.x
	_h = cells.size.y
	_bottom = bottom
	_solid = cells.data
	_clear_at.resize(_w * _h)
	_stand.resize(_w * _h)
	for r in range(WorldBuilder.HEADROOM - 1, _h):
		var row := r * _w
		for c in _w:
			var at := row + c
			if _solid[at] == 0 and _solid[at - _w] == 0 and _solid[at - _w - _w] == 0:
				_clear_at[at] = 1
				if r + 1 < _h and _solid[at + _w] != 0:
					_stand[at] = 1
	for cell: Vector2i in hazards:
		if cells.inside(cell):
			_stand[cell.y * _w + cell.x] = 0


## True when a wizard can stand on this tile.
func can_stand(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < _w and tile.y < _h and _stand[tile.y * _w + tile.x] == 1


## A picture of the tiles round one, for working out why a wizard cannot get on: # rock, o a place to stand, . open air, X the tile itself.
func sketch(at: Vector2i, across := 10, up := 8, down := 5) -> String:
	var out := ""
	for r in range(at.y - up, at.y + down + 1):
		var line := ""
		for c in range(at.x - across, at.x + across + 1):
			if c < 0 or r < 0 or c >= _w or r >= _h:
				line += " "
			elif Vector2i(c, r) == at:
				line += "X"
			elif _solid[r * _w + c] != 0:
				line += "#"
			else:
				line += "o" if _stand[r * _w + c] == 1 else "."
		out += line + "  %d
" % r
	return out


## Every tile a wizard can stand on, in the order of the rows.
func standing() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in _h:
		for c in _w:
			if _stand[r * _w + c] == 1:
				out.append(Vector2i(c, r))
	return out


## The tiles one can get to from a tile in one move.
func moves(at: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for dc in [-1, 1]:
		var c: int = at.x + dc
		if c < 0 or c >= _w:
			continue
		for dr in [0, -1]:
			var r: int = at.y + dr
			if r >= 0 and _stand[r * _w + c] == 1 and _clear_at[r * _w + at.x] == 1:
				found.append(Vector2i(c, r))
		# Walking off an edge: fall to the first thing below.
		if _clear_at[at.y * _w + c] == 1 and _stand[at.y * _w + c] == 0:
			var r := at.y
			while r < _bottom and _clear_at[r * _w + c] == 1 and _stand[r * _w + c] == 0:
				r += 1
			if r < _bottom and _stand[r * _w + c] == 1:
				found.append(Vector2i(c, r))
	# Jumps: up to JUMP_ROWS higher, across at the same height, or down to a lower landing.
	for height in range(-WorldBuilder.JUMP_ROWS, WorldBuilder.JUMP_ROWS + 1):
		var target_row: int = at.y - height
		if target_row < 0 or target_row >= _h:
			continue
		var span := WorldBuilder.JUMP_FAR if absi(height) <= 1 else WorldBuilder.JUMP_COLS
		for dc in range(-span, span + 1):
			if dc == 0 and height <= 0:
				continue
			var column: int = at.x + dc
			if column < 0 or column >= _w or _stand[target_row * _w + column] == 0:
				continue
			var open := true
			var top := mini(at.y, target_row) - WorldBuilder.HEADROOM + 1
			for c in range(mini(at.x, column), maxi(at.x, column) + 1):
				var last := at.y - 1 if c != column else target_row
				for r in range(maxi(top, 0), last + 1):
					if _solid[r * _w + c] != 0:
						open = false
						break
				if not open:
					break
			if open:
				found.append(Vector2i(column, target_row))
	return found

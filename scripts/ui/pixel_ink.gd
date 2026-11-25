class_name PixelInk
extends RefCounted

## Ink laid in whole pixels, for the strokes shown in the book and on the home page. A line is turned into the cells it passes through on a grid (a cell is
## one pixel of the book's own art, `Spellbook.CELL` screen pixels across), with no smoothing, so a drawn stroke is made of the same pixels as what it is
## drawn on. Cells are kept in a dictionary (Vector2i -> true) so that crossings and joins are laid once.


## The cells a straight line passes through, one cell wide with no gaps (Bresenham), added to `into`.
static func line_between(a: Vector2, b: Vector2, cell: float, into: Dictionary) -> void:
	var x0 := floori(a.x / cell)
	var y0 := floori(a.y / cell)
	var x1 := floori(b.x / cell)
	var y1 := floori(b.y / cell)
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var error := dx + dy
	while true:
		into[Vector2i(x0, y0)] = true
		if x0 == x1 and y0 == y1:
			return
		var twice := 2 * error
		if twice >= dy:
			error += dy
			x0 += sx
		if twice <= dx:
			error += dx
			y0 += sy


## The cells along a path of points.
static func along(path: PackedVector2Array, cell: float) -> Dictionary:
	var cells := {}
	for i in path.size() - 1:
		line_between(path[i], path[i + 1], cell, cells)
	if path.size() == 1:
		cells[Vector2i(floori(path[0].x / cell), floori(path[0].y / cell))] = true
	return cells


## The cells in a square block, `radius` cells out from the one holding this point (radius 1 is a 3 x 3 dot).
static func block(at: Vector2, radius: int, cell: float) -> Dictionary:
	var cells := {}
	var middle := Vector2i(floori(at.x / cell), floori(at.y / cell))
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			cells[middle + Vector2i(dx, dy)] = true
	return cells


## The cells touching these on a side, that are not in them: the ink bleeding a cell into the paper.
static func bleed(cells: Dictionary) -> Dictionary:
	var out := {}
	for cell: Vector2i in cells:
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not cells.has(cell + step):
				out[cell + step] = true
	return out


## The cells and the ones to their right and below them: a line two cells wide.
static func thick(cells: Dictionary) -> Dictionary:
	var out := cells.duplicate()
	for cell: Vector2i in cells:
		out[cell + Vector2i(1, 0)] = true
		out[cell + Vector2i(0, 1)] = true
		out[cell + Vector2i(1, 1)] = true
	return out


## The same cells moved over.
static func shifted(cells: Dictionary, by: Vector2i) -> Dictionary:
	var out := {}
	for cell: Vector2i in cells:
		out[cell + by] = true
	return out


## Paints cells, leaving out any that are in `skip`.
static func fill(canvas: CanvasItem, cells: Dictionary, cell: float, color: Color, skip := {}) -> void:
	for at: Vector2i in cells:
		if not skip.has(at):
			canvas.draw_rect(Rect2(Vector2(at) * cell, Vector2.ONE * cell), color)

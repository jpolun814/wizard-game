class_name MatchTrace
extends Control

## The damage dealt and taken through a match, drawn as two inked lines. The match is cut into the worlds it went through, each named across its stretch.

var dealt: Array
var taken: Array
var sections: Array  # [name, where it begins as a share of the match]

func _init(dealt_line: Array, taken_line: Array, stretches: Array) -> void:
	dealt = dealt_line
	taken = taken_line
	sections = stretches
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	# Every world the person was in is named, however short the stay. A name goes in the first row where it clears the one before, with its first letter
	# at its own mark, or as near it as the right edge allows; a stay too short for its name takes a row below, so no name is written over another.
	var font: Font = LibraryScreen.JERSEY
	var row_ends: Array[float] = []
	var spots: Array = []  # [name, x, row]
	for k in sections.size():
		var name: String = sections[k][0]
		var wide := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17).x
		var at := minf(size.x * float(sections[k][1]) + 4.0, maxf(size.x - wide - 2.0, 0.0))
		var row := 0
		while row < row_ends.size() and row_ends[row] > at:
			row += 1
		if row == row_ends.size():
			row_ends.append(0.0)
		row_ends[row] = at + wide + 6.0
		spots.append([name, at, row])
	var band := 4.0 + 17.0 * maxi(row_ends.size(), 1)  # the strip along the top that carries the names of the worlds
	for k in sections.size():
		var from_x: float = size.x * float(sections[k][1])
		var to_x: float = size.x * float(sections[k + 1][1]) if k + 1 < sections.size() else size.x
		if k % 2 == 0:
			draw_rect(Rect2(from_x, 0.0, to_x - from_x, size.y - 2.0), Color(Spellbook.PAPER_DARK, 0.3))
		if k > 0:
			draw_line(Vector2(from_x, 0.0), Vector2(from_x, size.y - 2.0), Color(Spellbook.SUBTLE, 0.7), 2.0)
	for spot: Array in spots:
		draw_string(font, Vector2(spot[1], 15.0 + 17.0 * int(spot[2])), spot[0], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Spellbook.TEXT_INK)
	draw_line(Vector2(0.0, size.y - 1.0), Vector2(size.x, size.y - 1.0), Color(Spellbook.PAPER_DARK, 0.7), 2.0)
	var top := 1.0
	for v: int in dealt + taken:
		top = maxf(top, float(v))
	var low := (band if not sections.is_empty() else 2.0)
	for pair in [[taken, Spellbook.SUBTLE], [dealt, Spellbook.HEADING]]:
		var line: Array = pair[0]
		if line.size() < 2:
			continue
		var points := PackedVector2Array()
		for k in line.size():
			points.append(Vector2(size.x * k / (line.size() - 1.0), low + (size.y - low - 4.0) * (1.0 - float(line[k]) / top)))
		draw_polyline(points, pair[1], 2.0, true)

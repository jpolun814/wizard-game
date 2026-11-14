class_name Lettering
extends RefCounted

## The face of titles, names and headings: Olde Tome, a gothic pixel font. It is drawn on a grid of 22 font pixels to the em, so it is only crisp at sizes
## that are a whole number of times that (22, 44, 66, 88). Any size asked for is moved to the nearest of those. The letters it lacks ( / ( ) ) come from
## the pixel font of the interface, which is also here (`PIXEL`) with the gold of the panels, for the screens that set text of their own.

const FACE := preload("res://fonts/olde_tome.tres")
const GRID := 22
const PIXEL := preload("res://fonts/Jersey15-Regular.ttf")  # the interface's plain pixel font: numbers and small words
const GOLD := Color("#c89a3c")  # the gold of a panel's edge and of its headings


## The size of Olde Tome nearest to this one, never smaller than one grid.
static func size_near(size: int) -> int:
	return maxi(1, roundi(float(size) / GRID)) * GRID


## A centred heading of a panel, in the interface's pixel font.
static func heading(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", PIXEL)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

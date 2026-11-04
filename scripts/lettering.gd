class_name Lettering
extends RefCounted

## The face of titles, names and headings: Olde Tome, a gothic pixel font. It is drawn on a grid of 22 font pixels to the em, so it is only crisp at sizes
## that are a whole number of times that (22, 44, 66, 88). Any size asked for is moved to the nearest of those. The letters it lacks ( / ( ) ) come from
## the pixel font of the interface.

const FACE := preload("res://fonts/olde_tome.tres")
const GRID := 22


## The size of Olde Tome nearest to this one, never smaller than one grid.
static func size_near(size: int) -> int:
	return maxi(1, roundi(float(size) / GRID)) * GRID

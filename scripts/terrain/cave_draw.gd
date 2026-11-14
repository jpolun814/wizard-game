class_name CaveDraw
extends Node2D

## The rock under everything, the inside of the castle, or its brick.

const RIM := Color("#0d0916")
const WALL := Color("#3a2e50")
const STONE_FILL := Color(0.25, 0.16, 0.36)
const HALL := Color(0.12, 0.11, 0.18)
const HALL_TILES := 9  # rows the hall's picture is stretched over: the hall's full height
const STRIP := 640.0  # how wide the strips are that stone is cut into round a room
const WINDOW_AREA_MOST := 12.0 * 32.0 * 32.0  # the air inside the stone that is only a window, in square pixels: larger is a room
const BLEED := 14.0  # how far the painting of a room runs under the stone round it
const SNOW_FADE := 640.0  # pixels over which snow thins out below the snow line
const HALL_PICTURE := preload("res://art/backgrounds/church/hall.png")
var kind := "rock"     # "rock", "hall" or "solid"
var chunk := -1        # a hall is painted in pieces of Terrain.HALL_CHUNK columns: this is the one this paints
var loops: Array = []  # outlines, with rock on the right of the way they run
var pits: Array = []   # the pits dug since, each cut out of the stone as it was drawn
var openings: Array = []  # the part of a slab between two storeys that a pit went through: the hall shows through it
var cuts: Array = []   # the whole shape of every pit dug, with the air above it
var rims: Array = []   # the lines round the pits that lie inside the stone
var hollows: Array = []  # the stone that the pits took away, which is painted as the dark inside of the castle
var earth: Texture2D
var world := Vector2.ZERO
var sky := PackedVector2Array()  # the part of the world that is open sky
var snow: Array = []  # {"a", "b": pixels across, "line": height, "texture"}: the rock above the line, in these columns, is under snow

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

## Takes a pit's shape out of the brick, so that what was dug is seen to be dug.
func cut(shape: PackedVector2Array) -> void:
	var pit := PackedVector2Array(shape)
	if Contour.area(pit) < 0.0:
		pit.reverse()  # whichever way it was dug, the shape is cut out the same way
	cuts.append(pit)
	var pit_box := Rect2(pit[0], Vector2.ZERO)
	for point in pit:
		pit_box = pit_box.expand(point)
	var kept: Array = []
	var rooms: Array = []
	for points: PackedVector2Array in loops:
		if Contour.area(points) < 0.0 and absf(Contour.area(points)) >= WINDOW_AREA_MOST:
			var room := PackedVector2Array(points)
			room.reverse()
			rooms.append(room)
	for points: PackedVector2Array in loops:
		var box := Rect2(points[0], Vector2.ZERO)
		for point in points:
			box = box.expand(point)
		if Contour.area(points) < 0.0 or not box.intersects(pit_box):
			kept.append(points)  # a window, or stone the pit does not touch
			continue
		var standing := false  # a slab standing in a room is inside the room's outline; the rest of the stone has the rooms taken out of it
		for room: PackedVector2Array in rooms:
			standing = standing or Geometry2D.clip_polygons(points, room).is_empty()  # all of it is inside the room
		# Only the part of the pit that is in stone is cut: the part in the room's air was never stone.
		var parts: Array = [pit]
		if not standing:
			for room: PackedVector2Array in rooms:
				var left: Array = []
				for part: PackedVector2Array in parts:
					left.append_array(Geometry2D.clip_polygons(part, room))
				parts = left
		var rest: Array = [points]
		for part: PackedVector2Array in parts:
			if Contour.area(part) < 0.0:
				continue
			for gone: PackedVector2Array in Geometry2D.intersect_polygons(points, part):
				var under := false  # a room lies under it: it is a hole through a floor, and the hall shows through
				var bottom := gone[0]
				for point in gone:
					if point.y > bottom.y:
						bottom = point
				for room: PackedVector2Array in rooms:
					under = under or Geometry2D.is_point_in_polygon(bottom + Vector2(0.0, 6.0), room)
				if under:
					openings.append(gone)
				else:
					hollows.append(gone)
			var next: Array = []
			for stone: PackedVector2Array in rest:
				for piece: PackedVector2Array in Geometry2D.clip_polygons(stone, part):
					if Contour.area(piece) < 0.0:
						piece.reverse()  # the pit lies inside the stone's outline, so it is a hole in it
						pits.append(piece)
						var closed := PackedVector2Array(piece)
						closed.append(piece[0])
						if standing:
							rims.append(closed)
						else:  # its edge along the floor it was dug through is open air, and has no line
							var shown: Array = [closed]
							for room: PackedVector2Array in rooms:
								for edge: PackedVector2Array in Geometry2D.offset_polygon(room, 2.0):
									var outside: Array = []
									for line: PackedVector2Array in shown:
										outside.append_array(Geometry2D.clip_polyline_with_polygon(line, edge))
									shown = outside
							rims.append_array(shown)
					else:
						next.append(piece)
			rest = next
		kept.append_array(rest)
	loops = kept
	queue_redraw()

func _draw() -> void:
	match kind:
		"rock":
			_draw_rock()
		"hall":
			_draw_hall()
		_:
			_draw_brick()


## The earth under the sky, with snow over the high rock.
func _draw_rock() -> void:
	# The earth under the sky: everything in the world but the sky, which is left open for the biome's backdrop to show through.
	var whole := PackedVector2Array([Vector2.ZERO, Vector2(world.x, 0.0), world, Vector2(0.0, world.y)])
	for part: PackedVector2Array in (Geometry2D.clip_polygons(whole, sky) if not sky.is_empty() else [whole]):
		var uvs := PackedVector2Array()
		for point in part:
			uvs.append(point / earth.get_size())
		draw_polygon(part, PackedColorArray([Color.WHITE]), uvs, earth)
	# Snow over the high rock, thinning out to nothing at the snow line.
	var rock_parts: Array = Geometry2D.clip_polygons(whole, sky) if not sky.is_empty() else [whole]
	for cap: Dictionary in snow:
		var texture: Texture2D = cap["texture"]
		var left: float = cap["a"]
		var right: float = cap["b"]
		var line: float = cap["line"]
		var top := line - SNOW_FADE
		for edge in [[0.0, top, Color.WHITE, Color.WHITE], [top, line, Color.WHITE, Color(1, 1, 1, 0)]]:
			var band := PackedVector2Array([Vector2(left, edge[0]), Vector2(right, edge[0]), Vector2(right, edge[1]), Vector2(left, edge[1])])
			for rock_part: PackedVector2Array in rock_parts:
				for piece: PackedVector2Array in Geometry2D.intersect_polygons(band, rock_part):
					if Contour.area(piece) < 1.0 or Geometry2D.triangulate_polygon(piece).is_empty():
						continue
					var snow_uvs := PackedVector2Array()
					var shades := PackedColorArray()
					for point in piece:
						snow_uvs.append(point / texture.get_size())
						shades.append(edge[2].lerp(edge[3], clampf((point.y - edge[0]) / maxf(edge[1] - edge[0], 1.0), 0.0, 1.0)))
					draw_polygon(piece, shades, snow_uvs, texture)


## The inside of a cathedral, drawn behind the castle's rooms.
func _draw_hall() -> void:
	var t := float(ArenaGen.TILE)
	# The inside of a cathedral, from the church backdrop: columns, windows and candles, as tall as the hall's tallest part,
	# standing on the floor, so a low stretch of hall shows only the bottom of the picture.
	var picture: Texture2D = HALL_PICTURE
	var zoom := t * float(HALL_TILES) / picture.get_height()
	var first_column := 1 << 30
	var last_column := -1
	var ground_row := -1  # the row under the castle's ground floor, which keeps its edge
	for tiles: Rect2i in ArenaGen.castle_hall:
		first_column = mini(first_column, tiles.position.x)
		last_column = maxi(last_column, tiles.position.x)
		ground_row = maxi(ground_row, tiles.end.y)
	for tiles: Rect2i in ArenaGen.castle_hall:
		if chunk >= 0 and tiles.position.x / Terrain.HALL_CHUNK != chunk:
			continue
		var rect := Rect2(Vector2(tiles.position) * t, Vector2(tiles.size) * t + Vector2(0.0, 1.0))
		# The painting runs a little under the stone round it (the brick is drawn over it), so that where the smoothed edge of a
		# stair or a wall cuts across a tile, the sky does not show through the corner. The castle's two ends stay as they are.
		var bleed_left := 0.0 if tiles.position.x == first_column else BLEED
		var bleed_right := 0.0 if tiles.position.x == last_column else BLEED
		var bleed_down := 0.0 if tiles.end.y == ground_row else BLEED
		rect = Rect2(rect.position - Vector2(bleed_left, BLEED), rect.size + Vector2(bleed_left + bleed_right, BLEED + bleed_down))
		draw_rect(rect, HALL)
		var width := t / zoom
		var height := minf(rect.size.y / zoom, float(picture.get_height()))
		# The picture runs along the hall and back again, so that it never jumps where its ends meet.
		var travel := picture.get_width() - width
		var along := fposmod(rect.position.x / zoom, travel * 2.0)
		var mirrored := along > travel
		var across := travel * 2.0 - along if mirrored else along
		var size := Vector2(picture.get_size())
		var u0 := across / size.x
		var u1 := (across + width) / size.x
		if mirrored:
			var swap := u0
			u0 = u1
			u1 = swap
		var v0 := (size.y - height) / size.y
		var corners := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0.0), rect.end, rect.position + Vector2(0.0, rect.size.y)])
		draw_polygon(corners, PackedColorArray([Color.WHITE]), PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, 1.0), Vector2(u0, 1.0)]), picture)


## The castle's brick, drawn over its stone.
func _draw_brick() -> void:
	# Brick is drawn over every piece of stone, with the castle's rooms cut out of it so that the hall painted under it shows (a polygon cannot
	# have a hole, so the stone is cut into strips across a room, and each strip has the room taken out of it).
	var rooms: Array = []
	var stone: Array = []
	for points: PackedVector2Array in loops:
		if Contour.area(points) >= 0.0:
			stone.append(points)
		elif absf(Contour.area(points)) >= WINDOW_AREA_MOST:
			var room := PackedVector2Array(points)
			room.reverse()
			rooms.append(room)
	for room: PackedVector2Array in rooms:
		stone = _without(stone, room, true)
	for pit: PackedVector2Array in pits:
		stone = _without(stone, pit, false)
	for gone: PackedVector2Array in hollows:  # what a pit took out of the stone is the castle's dark inside now
		if Contour.area(gone) > 1.0 and not Geometry2D.triangulate_polygon(gone).is_empty():
			draw_colored_polygon(gone, HALL)
	for gone: PackedVector2Array in openings:
		_show_hall(gone)
	for points: PackedVector2Array in stone:
		for piece: PackedVector2Array in Geometry2D.offset_polygon(points, 0.0):
			if Contour.area(piece) > 0.0:
				_lay(piece, earth, 1.0)
	for points: PackedVector2Array in loops:
		if Contour.area(points) < 0.0 and absf(Contour.area(points)) < WINDOW_AREA_MOST:
			draw_colored_polygon(points, WALL)  # a window: air inside the stone
		var closed := PackedVector2Array(points)
		closed.append(points[0])
		var lines: Array = [closed]
		if Contour.area(points) < 0.0:  # a room's edge is open where a pit was dug through its floor
			for cut_shape: PackedVector2Array in cuts:
				var left: Array = []
				for line: PackedVector2Array in lines:
					left.append_array(Geometry2D.clip_polyline_with_polygon(line, cut_shape))
				lines = left
		for line: PackedVector2Array in lines:
			draw_polyline(line, RIM, 3.0)
	for line: PackedVector2Array in rims:
		draw_polyline(line, RIM, 3.0)


## The hall's picture over a hole through a floor, as the room under it goes on up: the top of the picture, turned over, so that it joins the room's own
## picture at the hole's lower edge. It is laid a column at a time, as the hall is, so that each column is the part of the picture the room has there.
func _show_hall(hole: PackedVector2Array) -> void:
	if Contour.area(hole) < 1.0:
		return
	var t := float(ArenaGen.TILE)
	var picture: Texture2D = HALL_PICTURE
	var zoom := t * float(HALL_TILES) / picture.get_height()
	var size := Vector2(picture.get_size())
	var width := t / zoom
	var travel := size.x - width
	var box := Rect2(hole[0], Vector2.ZERO)
	for point in hole:
		box = box.expand(point)
	var column := floorf(box.position.x / t)
	while column * t < box.end.x:
		var strip := PackedVector2Array([Vector2(column * t, box.position.y - 4.0), Vector2((column + 1.0) * t, box.position.y - 4.0), Vector2((column + 1.0) * t, box.end.y + 4.0), Vector2(column * t, box.end.y + 4.0)])
		var along := fposmod(column * t / zoom, travel * 2.0)
		var mirrored := along > travel
		var across := travel * 2.0 - along if mirrored else along
		for part: PackedVector2Array in Geometry2D.intersect_polygons(hole, strip):
			if Contour.area(part) < 1.0 or Geometry2D.triangulate_polygon(part).is_empty():
				continue
			var uvs := PackedVector2Array()
			for point in part:
				var u := (across + (1.0 - (point.x - column * t) / t if mirrored else (point.x - column * t) / t) * width) / size.x
				uvs.append(Vector2(u, clampf((box.end.y - point.y) / (zoom * size.y), 0.0, 1.0)))
			draw_colored_polygon(part, HALL)
			draw_polygon(part, PackedColorArray([Color.WHITE]), uvs, picture)
		column += 1.0

## A piece of stone in its colour with a texture over it, at a scale of the texture's own size. A piece that cannot be cut into triangles whole (an edge
## touching itself) is laid in convex parts.
func _lay(piece: PackedVector2Array, texture: Texture2D, scale: float) -> void:
	if Contour.area(piece) < 1.0:
		return
	var parts: Array = [piece] if not Geometry2D.triangulate_polygon(piece).is_empty() else Geometry2D.decompose_polygon_in_convex(piece)
	for part: PackedVector2Array in parts:
		draw_colored_polygon(part, STONE_FILL)
		var uvs := PackedVector2Array()
		for point in part:
			uvs.append(point / (texture.get_size() * scale))
		draw_polygon(part, PackedColorArray([Color.WHITE]), uvs, texture)

## Outlines of stone with a room taken out of them: cut into strips across the room, each strip minus the room, so no piece has a hole in it.
static func _without(stone: Array, room: PackedVector2Array, inside_stays: bool) -> Array:
	var box := Rect2(room[0], Vector2.ZERO)
	for point in room:
		box = box.expand(point)
	var out: Array = []
	for points: PackedVector2Array in stone:
		var around := Rect2(points[0], Vector2.ZERO)
		for point in points:
			around = around.expand(point)
		if not around.intersects(box):
			out.append(points)
			continue
		if Geometry2D.clip_polygons(points, room).is_empty():  # all of it inside
			if inside_stays:
				out.append(points)  # (a slab standing in the room is stone inside its outline, and stays)
			continue  # (and a piece all inside a pit is gone)
		var left := box.position.x - 64.0
		var far := Vector2(-1.0e6, 1.0e6)  # what lies beside the strips, left and right of them, is stone as it was
		for edge in [[far.x, left], [left + ceilf((box.end.x - left) / STRIP) * STRIP - 2.0, far.y]]:
			var side := PackedVector2Array([Vector2(edge[0], around.position.y - 8.0), Vector2(edge[1], around.position.y - 8.0), Vector2(edge[1], around.end.y + 8.0), Vector2(edge[0], around.end.y + 8.0)])
			for part: PackedVector2Array in Geometry2D.intersect_polygons(points, side):
				out.append(part)
		while left < box.end.x:
			var strip := PackedVector2Array([Vector2(left - 2.0, around.position.y - 8.0), Vector2(left + STRIP + 2.0, around.position.y - 8.0), Vector2(left + STRIP + 2.0, around.end.y + 8.0), Vector2(left - 2.0, around.end.y + 8.0)])
			for part: PackedVector2Array in Geometry2D.intersect_polygons(points, strip):
				for rest: PackedVector2Array in Geometry2D.clip_polygons(part, room):
					if Contour.area(rest) < 0.0:
						rest.reverse()  # (the cutting has no holes to leave, so a piece the other way round is stone, not a gap)
					out.append(rest)
			left += STRIP
	return out

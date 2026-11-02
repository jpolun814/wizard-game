class_name MountainRidges
extends Node2D

## The snowy peaks' second range: ridges that stand behind the ground of the mountains and overlap it. Each is a shoulder of rock with a
## long slope up, a level top and a long slope down, and it lies over the same stretch of the world as the ground in front of it. A
## wizard can walk up a ridge from the ground, cross its top and come down the far side, or press S on top to drop to the ground in
## front, the way the stairs of a castle work. A ridge is hollow like those stairs: its slopes are one-way, so it is jumped up
## through and landed on from above.

const HEIGHT_LEAST := 4   # how many rows a ridge's top stands above the highest ground under it
const HEIGHT_MOST := 8
const LENGTH_LEAST := 8   # columns of level top
const LENGTH_MOST := 20
const GAP_LEAST := 14     # columns of the world between the end of one ridge's top and the start of the next's
const GAP_MOST := 34
const SLOPE_STEEPEST := 0.95  # the steepest a run of a flank is, in rows to a column: a little under the steepest a wizard can stand on
const BAND := 12.0        # how deep the lip along a ridge's top is, in pixels
## Each ridge is in the shade of the ground in front of it, so that it reads as farther off, and each is shaded a little differently from the
## ones either side of it, so that the ridges stand apart from one another and from the sky behind.
const SHADES := [Color(1.3, 1.3, 1.5), Color(1.1, 1.15, 1.35), Color(0.95, 1.0, 1.25)]
const OUTLINE := Color(0.04, 0.05, 0.12, 0.9)
const SNOW_FADE := 640.0  # pixels over which snow thins out below the snow line, as on the ground in front
const FOOT_SHARE := 0.4   # how dark the foot of a ridge is, against its crest
const FILL := 220.0       # how far under its lowest point the rock of a ridge is drawn

var floors: PackedInt32Array
var seed_value := 0
var tile := 32.0
var earth: Texture2D  # kept here because a texture loaded in _draw is freed before it is drawn
var lip: Texture2D
var snow: Texture2D       # the snow over the high rock of the ground in front, and the drifts along its ridges
var snow_lip: Texture2D
var snow_line := INF      # the height (y) above which the ground is snow, as the ground in front has it
const DIG_STEP := 16.0  # pixels between the points of a ridge's top once a pit has been dug in it
var _body: StaticBody2D
var ridges: Array = []   # each a PackedVector2Array of four points in the world: where it leaves the ground, the two ends of its top, and where it returns


## The ridges of a stretch of ground, from the seed alone, so every machine of a match has the same ones.
static func plan(ground: PackedInt32Array, margin: int, seed_for: int, tile_size: float) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for
	var out := []
	var column := margin + 24
	while column < ground.size() - margin - 24:
		var length := rng.randi_range(LENGTH_LEAST, LENGTH_MOST)
		var high := ground[column]
		var low := ground[column]
		for c in range(column, column + length + 1):
			high = mini(high, ground[c])
			low = maxi(low, ground[c])
		if low - high > 10:  # too steep and broken for a level top
			column += 5
			continue
		var top := high - rng.randi_range(HEIGHT_LEAST, HEIGHT_MOST)
		# Not a plain shoulder: each flank climbs in runs of different steepness with treads between, and the crest is broken, as the ground in front is.
		var down_left := _descend(ground, column, top, -1, margin, tile_size, rng)
		var down_right := _descend(ground, column + length, top, 1, margin, tile_size, rng)
		if down_left.is_empty() or down_right.is_empty():
			column += 5
			continue
		down_left.reverse()
		var outline := PackedVector2Array(down_left)  # from its foot on the left up to the crest's left end
		outline.append_array(_crest(outline[outline.size() - 1], down_right[0], tile_size, rng))
		outline.append_array(down_right)
		out.append(outline)
		column += length + rng.randi_range(GAP_LEAST, GAP_MOST)
	return out


## A flank from the end of a ridge's top down to where it meets the ground, in runs of different steepness: a steep face, a shallow one, a nearly level
## tread. The first point is the end of the top, the last is the foot, and every run is one a wizard can walk. An empty list where it never comes down
## into the ground within reach.
static func _descend(ground: PackedInt32Array, from_column: int, top: int, way: int, margin: int, tile_size: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2((from_column + 0.5) * tile_size, float(top) * tile_size)])
	var column := float(from_column) + 0.5
	var row := float(top)
	var steps := 0
	while steps < 70:
		var slope := rng.randf_range(0.05, 0.4) if rng.randf() < 0.3 else rng.randf_range(0.55, SLOPE_STEEPEST)
		for k in rng.randi_range(2, 7):
			column += way
			row += slope
			steps += 1
			var at := int(floorf(column))
			if at <= margin or at >= ground.size() - margin:
				return PackedVector2Array()
			if row >= float(ground[at]):
				points.append(Vector2(column * tile_size, row * tile_size))  # the foot is in the ground, which hides it
				return points
		points.append(Vector2(column * tile_size, row * tile_size))
	return PackedVector2Array()


## A few points along the crest that stand higher or lower than its two ends, so the top is not a level line.
static func _crest(from: Vector2, to: Vector2, tile_size: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := rng.randi_range(2, 4)
	var before := from
	for k in count:
		var along := (float(k) + rng.randf_range(0.2, 0.8)) / float(count)
		var x := lerpf(from.x, to.x, along)
		var reach := (x - before.x) * SLOPE_STEEPEST  # as steep as a flank may be, and no steeper
		var next := Vector2(x, clampf(from.y - rng.randf_range(-0.5, 2.0) * tile_size, before.y - reach, before.y + reach))
		points.append(next)
		before = next
	var last := points[points.size() - 1]  # the last of them must also be within a flank's steepness of the crest's far end
	last.y = clampf(last.y, to.y - (to.x - last.x) * SLOPE_STEEPEST, to.y + (to.x - last.x) * SLOPE_STEEPEST)
	points[points.size() - 1] = last
	return points


## The height of the top of a ridge at a place across the world, or INF where no ridge stands.
func top_at(x: float) -> float:
	for ridge: PackedVector2Array in ridges:
		if x < ridge[0].x or x > ridge[ridge.size() - 1].x:
			continue
		for k in ridge.size() - 1:
			if x <= ridge[k + 1].x and ridge[k + 1].x > ridge[k].x:
				return lerpf(ridge[k].y, ridge[k + 1].y, (x - ridge[k].x) / (ridge[k + 1].x - ridge[k].x))
	return INF


## True when a stroke drawn in this box is on a ridge's top, rather than on the ground in front of it.
func holds(box: Rect2) -> bool:
	var top := top_at(box.get_center().x)
	return top < INF and top >= box.position.y - 30.0 and top <= box.end.y + 30.0


## Digs a pit into the top of a ridge (see Terrain.dig): the top sinks the way the pit's profile says, and the walkable line and the picture
## follow. False where no ridge stands under the point.
func dig(at: Vector2, half_width: float, depth: float, profile := PackedFloat32Array()) -> bool:
	var top := top_at(at.x)
	if top == INF or absf(at.y - top) > 48.0:
		return false
	for index in ridges.size():
		var ridge: PackedVector2Array = ridges[index]
		if at.x < ridge[0].x or at.x > ridge[ridge.size() - 1].x:
			continue
		var dense := PackedVector2Array()
		var x := ridge[0].x
		while x < ridge[ridge.size() - 1].x:
			dense.append(Vector2(x, _line_y(ridge, x)))
			x += DIG_STEP
		dense.append(ridge[ridge.size() - 1])
		for k in dense.size():
			var u := (dense[k].x - (at.x - half_width)) / (half_width * 2.0)
			if u > 0.0 and u < 1.0:
				dense[k].y += depth * Terrain.pit_share(u, profile)
		ridges[index] = dense
		_rebuild_body()
		queue_redraw()
		return true
	return false


static func _line_y(ridge: PackedVector2Array, x: float) -> float:
	for k in ridge.size() - 1:
		if x <= ridge[k + 1].x and ridge[k + 1].x > ridge[k].x:
			return lerpf(ridge[k].y, ridge[k + 1].y, clampf((x - ridge[k].x) / (ridge[k + 1].x - ridge[k].x), 0.0, 1.0))
	return ridge[ridge.size() - 1].y


func _rebuild_body() -> void:
	if _body != null:
		_body.queue_free()
	_body = StaticBody2D.new()
	_body.collision_layer = 16  # a one-way platform, as the castle's stairs are
	_body.collision_mask = 0
	for ridge: PackedVector2Array in ridges:
		for k in ridge.size() - 1:
			var shape := CollisionShape2D.new()
			var line := SegmentShape2D.new()
			line.a = ridge[k]
			line.b = ridge[k + 1]
			shape.shape = line
			shape.one_way_collision = true
			shape.one_way_collision_margin = 6.0
			_body.add_child(shape)
	add_child(_body)


func _ready() -> void:
	add_to_group("ridges")
	z_index = -12  # behind the rock of the ground, so that the ground in front hides a ridge's foot
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ridges = plan(floors, SurfaceGen.MARGIN, seed_value, tile)
	_rebuild_body()
	queue_redraw()


## Draws what lies above the snow line of a shape in snow, thinning out below the line: the shape is cut at the line, and its colour fades
## with the height. `flat` is true for the lip, whose texture runs along the ridge and does not repeat down it.
func _draw_snow(shape: PackedVector2Array, texture: Texture2D, texture_size: Vector2, tint: Color, flat: bool) -> void:
	var reach := Rect2(Vector2(-1.0e6, -1.0e6), Vector2(2.0e6, 1.0e6 + snow_line + SNOW_FADE * 0.25 + 1.0e6 * 0.0))  # (everything above a little under the line)
	var cut := Geometry2D.intersect_polygons(shape, PackedVector2Array([
		reach.position, Vector2(reach.end.x, reach.position.y), reach.end, Vector2(reach.position.x, reach.end.y)]))
	for piece: PackedVector2Array in cut:
		var colours := PackedColorArray()
		var uvs := PackedVector2Array()
		for point in piece:
			var share := clampf((snow_line + SNOW_FADE * 0.25 - point.y) / (SNOW_FADE * 0.25), 0.0, 1.0)
			colours.append(Color(tint.r, tint.g, tint.b, share))
			uvs.append(Vector2(point.x / texture_size.x, (point.y - shape[0].y) / texture_size.y if flat else point.y / texture_size.y))
		draw_polygon(piece, colours, uvs, texture)


func _draw() -> void:
	if earth == null or lip == null:
		return
	for index in ridges.size():
		var ridge: PackedVector2Array = ridges[index]
		var tint: Color = SHADES[index % SHADES.size()]
		var deepest := 0.0
		for point in ridge:
			deepest = maxf(deepest, point.y)
		var rock := PackedVector2Array(ridge)
		rock.append(Vector2(ridge[ridge.size() - 1].x, deepest + FILL))
		rock.append(Vector2(ridge[0].x, deepest + FILL))
		var uvs := PackedVector2Array()
		for point in rock:
			uvs.append(point / earth.get_size())
		draw_polygon(rock, PackedColorArray([Color("#1c2438")]))  # an opaque base, so no sky shows through the rock
		var shades := PackedColorArray()  # light along the top, and darker toward the foot, so that a ridge is a mass of rock and not a flat sheet
		for k in rock.size():
			shades.append(tint if k < ridge.size() else tint.darkened(FOOT_SHARE))
		draw_polygon(rock, shades, uvs, earth)
		var band := PackedVector2Array(ridge)
		var band_uvs := PackedVector2Array()
		for point in ridge:
			band_uvs.append(Vector2(point.x / lip.get_width(), 0.0))
		for k in range(ridge.size() - 1, -1, -1):
			band.append(ridge[k] + Vector2(0.0, BAND))
			band_uvs.append(Vector2(ridge[k].x / lip.get_width(), BAND / lip.get_height()))
		draw_polygon(band, PackedColorArray([tint]), band_uvs, lip)  # the same lip as the ground in front, in the same shade as its ridge
		if snow != null and snow_lip != null:
			_draw_snow(rock, snow, snow.get_size(), tint, false)  # a ridge climbing above the snow line has its summit in snow, as the ground in front does
			_draw_snow(band, snow_lip, snow_lip.get_size(), tint, true)
		draw_polyline(ridge, OUTLINE, 3.0)

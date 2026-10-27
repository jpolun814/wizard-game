class_name RockWorld
extends Node2D

## A world's rock, drawn and made solid in square chunks. The outlines between rock and air (see Contour) are cut at the chunk
## edges once, and then only the chunks near a player are drawn: each is a canvas item of its own, so the engine skips the
## ones off screen, and a chunk is made when someone comes near and freed when they leave. Collision is one concave shape per
## chunk on a single static body, so a body is only ever tested against the outlines round it.

const CHUNK := 32         # tiles along a chunk's side
const NEAR := 2           # chunks round a watcher that are drawn
const FAR := 4            # chunks round a watcher that are kept; farther ones are freed
const PER_FRAME := 2      # chunks made in a frame, past the ones right beside a watcher
const BAND := 24.0        # how deep the grass along a surface is, in pixels
const RIM := Color("#0d0916")
const WALL := Color("#3a2e50")
const WALL_TINT := Color(1.0, 0.9, 1.0, 0.3)

var earth: Texture2D
var grass_texture: Texture2D       # the grass where no biome says otherwise
var grass_spans: Array = []         # [{"a": first pixel, "b": last pixel, "texture"}]: each biome has grass of its own
var sky := PackedVector2Array()  # everything above the surface's ground, a polygon

var _px := float(CHUNK * ArenaGen.TILE)
var _air: Array = []      # outlines of open air, each with its bounds: {"points", "box"}
var _islands: Array = []  # outlines of rock standing in air
var _segments := {}       # chunk -> PackedVector2Array of segment ends, in pairs
var _grass_back := {}     # chunk -> PackedVector2Array of three per band: its two ends, and how far along the surface they are
var _grass_front := {}
var _built := {}          # chunk -> [nodes]
var _wanted: Array[Vector2i] = []  # chunks to make, nearest first
var _watchers: Array[Vector2i] = []
var _sky_low := 0.0


## Cuts the outlines up. Call once, after adding to the tree.
func setup(loops: Array) -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for point in sky:
		_sky_low = maxf(_sky_low, point.y)
	for points: PackedVector2Array in loops:
		var entry := {"points": points, "box": _bounds(points)}
		var is_air := Contour.area(points) < 0.0
		(_air if is_air else _islands).append(entry)
		for k in points.size():
			for piece in _cut(points[k], points[(k + 1) % points.size()]):
				if not _segments.has(piece[2]):
					_segments[piece[2]] = PackedVector2Array()
				_segments[piece[2]].append(piece[0])
				_segments[piece[2]].append(piece[1])
		_find_grass(points, _grass_back if is_air else _grass_front)
	_build_collision()


func _bounds(points: PackedVector2Array) -> Rect2:
	var box := Rect2(points[0], Vector2.ZERO)
	for point in points:
		box = box.expand(point)
	return box


## A segment cut where it crosses the chunk edges: each piece is {a, b, the chunk it lies in}.
func _cut(from: Vector2, to: Vector2) -> Array:
	var ways: Array[float] = [0.0, 1.0]
	var d := to - from
	if absf(d.x) > 0.001:
		for i in range(floori(minf(from.x, to.x) / _px) + 1, ceili(maxf(from.x, to.x) / _px)):
			ways.append((i * _px - from.x) / d.x)
	if absf(d.y) > 0.001:
		for i in range(floori(minf(from.y, to.y) / _px) + 1, ceili(maxf(from.y, to.y) / _px)):
			ways.append((i * _px - from.y) / d.y)
	ways.sort()
	var out := []
	for k in ways.size() - 1:
		var a := from + d * ways[k]
		var b := from + d * ways[k + 1]
		if a.distance_squared_to(b) < 0.0001:
			continue
		var middle := (a + b) * 0.5
		out.append([a, b, Vector2i(floori(middle.x / _px), floori(middle.y / _px))])
	return out


func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	add_child(body)
	for key: Vector2i in _segments:
		var shape := ConcavePolygonShape2D.new()
		shape.segments = _segments[key]
		var holder := CollisionShape2D.new()
		holder.shape = shape
		body.add_child(holder)


## The stretches of an outline that face up, where the air is above the rock, cut into bands by chunk. The grass texture runs
## along the surface, so a slope is not stretched.
func _find_grass(points: PackedVector2Array, into: Dictionary) -> void:
	var count := points.size()
	var faces_up := []
	for k in count:
		var heading := (points[(k + 1) % count] - points[k]).normalized()
		faces_up.append(heading.x > 0.4)  # the air is on the left of the way the outline runs
	var begin := 0
	while begin < count and faces_up[begin]:
		begin += 1
	if begin == count:
		begin = 0
	var along := 0.0
	for step in count:
		var k := (begin + step) % count
		if not faces_up[k]:
			along = 0.0
			continue
		for piece in _cut(points[k], points[(k + 1) % count]):
			var reach: float = along + piece[0].distance_to(piece[1])
			if not into.has(piece[2]):
				into[piece[2]] = PackedVector2Array()
			into[piece[2]].append(piece[0])
			into[piece[2]].append(piece[1])
			into[piece[2]].append(Vector2(along, reach))
			along = reach


## Which chunks to have drawn: those near these world positions.
func watch(positions: Array[Vector2], at_once := false) -> void:
	var now: Array[Vector2i] = []
	for position_in_world in positions:
		now.append(Vector2i(floori(position_in_world.x / _px), floori(position_in_world.y / _px)))
	if now == _watchers and _wanted.is_empty():
		return
	_watchers = now
	_wanted.clear()
	for key in _built.keys():
		if _distance(key) > FAR:
			for node: Node in _built[key]:
				node.queue_free()
			_built.erase(key)
	for watcher in _watchers:
		for dx in range(-NEAR, NEAR + 1):
			for dy in range(-NEAR, NEAR + 1):
				var key := watcher + Vector2i(dx, dy)
				if not _built.has(key) and not _wanted.has(key) and _in_world(key):
					_wanted.append(key)
	_wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _distance(a) < _distance(b))
	var made := 0
	while not _wanted.is_empty() and (at_once or _distance(_wanted[0]) <= 1 or made < PER_FRAME):
		_make(_wanted.pop_front())
		made += 1


func _process(_delta: float) -> void:
	if _wanted.is_empty():
		return
	for k in mini(PER_FRAME, _wanted.size()):
		_make(_wanted.pop_front())


func _distance(key: Vector2i) -> int:
	var nearest := 1 << 20
	for watcher in _watchers:
		nearest = mini(nearest, maxi(absi(key.x - watcher.x), absi(key.y - watcher.y)))
	return nearest


func _in_world(key: Vector2i) -> bool:
	return key.x >= 0 and key.y >= 0 and key.x * _px < ArenaGen.world_size.x * ArenaGen.TILE and key.y * _px < ArenaGen.world_size.y * ArenaGen.TILE


func _make(key: Vector2i) -> void:
	if _built.has(key):
		return
	var nodes: Array = []
	var back := Face.new()
	back.world = self
	back.key = key
	back.z_index = -10
	add_child(back)
	nodes.append(back)
	if _segments.has(key) and not _islands.is_empty():
		var front := Face.new()
		front.world = self
		front.key = key
		front.front = true
		front.z_index = 0
		add_child(front)
		nodes.append(front)
	_built[key] = nodes


func chunks_built() -> int:
	return _built.size()


func _rect_of(key: Vector2i) -> Rect2:
	return Rect2(Vector2(key) * _px, Vector2(_px, _px))


static func _rectangle(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


## Paints a chunk. The back is the cave's air, with its sky, rim and grass; the front is the rock standing in the air. Returns
## what the drawing uses, which must be kept as long as it is shown.
func paint(canvas: CanvasItem, key: Vector2i, front: bool) -> Array:
	var keep := []
	var rect := _rect_of(key)
	var window := _rectangle(rect)
	var loops: Array = _islands if front else _air
	var edges := _segments.has(key)
	if not edges and not front:
		if _in_air(rect.get_center()):
			_paint_air(canvas, window, rect)
		return keep
	for entry: Dictionary in loops:
		if not (entry["box"] as Rect2).grow(4.0).intersects(rect):
			continue
		var points: PackedVector2Array = entry["points"]
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(points, window):
			if front:
				if Contour.area(piece) > 1.0:
					var uvs := PackedVector2Array()
					for point in piece:
						uvs.append(point / earth.get_size())  # the same picture, in the same place, as the rock behind
					canvas.draw_polygon(piece, PackedColorArray([Color.WHITE]), uvs, earth)
			else:
				_paint_air(canvas, piece, rect)
		var closed := PackedVector2Array(points)
		closed.append(points[0])
		for line: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(closed, window):
			canvas.draw_polyline(line, RIM, 3.0)
	var bands: PackedVector2Array = (_grass_front if front else _grass_back).get(key, PackedVector2Array())
	if not bands.is_empty() and grass_texture != null:
		keep.append_array(_paint_grass(canvas, bands))
	return keep


func _in_air(point: Vector2) -> bool:
	for entry: Dictionary in _air:
		if (entry["box"] as Rect2).has_point(point) and Geometry2D.is_point_in_polygon(point, entry["points"]):
			return true
	return false


func _paint_air(canvas: CanvasItem, piece: PackedVector2Array, rect: Rect2) -> void:
	var t := float(ArenaGen.TILE)
	# The open sky above the ground is not painted: the biome's backdrop shows there. Only the cave's air under it has a back wall.
	var parts: Array = [piece]
	if not sky.is_empty() and rect.position.y < _sky_low:
		parts = Geometry2D.clip_polygons(piece, sky)
	for part: PackedVector2Array in parts:
		if absf(Contour.area(part)) < 1.0 or Geometry2D.triangulate_polygon(part).is_empty():  # a sliver cannot be triangulated
			continue
		var uvs := PackedVector2Array()
		for p in part:
			uvs.append(p / (t * 2.0))  # the cave's back wall: the same rock, bigger and dimmer, so it sits behind the near rock
		canvas.draw_colored_polygon(part, WALL)
		canvas.draw_polygon(part, PackedColorArray([WALL_TINT]), uvs, earth)


func _paint_grass(canvas: CanvasItem, bands: PackedVector2Array) -> Array:
	var t := float(ArenaGen.TILE)
	var drop := Vector2(0.0, BAND)
	var made := {}  # texture -> {"points", "uvs", "index"}
	for k in range(0, bands.size(), 3):
		var a := bands[k]
		var b := bands[k + 1]
		var along: Vector2 = bands[k + 2]
		var texture := _grass_at((a + b) * 0.5)
		if not made.has(texture):
			made[texture] = {"points": PackedVector2Array(), "uvs": PackedVector2Array(), "index": PackedInt32Array()}
		var group: Dictionary = made[texture]
		var first: int = group["points"].size()
		group["points"].append_array(PackedVector2Array([a, b, b + drop, a + drop]))
		group["uvs"].append_array(PackedVector2Array([Vector2(along.x, 0.0) / t, Vector2(along.y, 0.0) / t, Vector2(along.y, BAND) / t, Vector2(along.x, BAND) / t]))
		group["index"].append_array(PackedInt32Array([first, first + 1, first + 2, first, first + 2, first + 3]))
	var meshes := []
	for texture: Texture2D in made:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = made[texture]["points"]
		arrays[Mesh.ARRAY_TEX_UV] = made[texture]["uvs"]
		arrays[Mesh.ARRAY_INDEX] = made[texture]["index"]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		canvas.draw_mesh(mesh, texture)
		meshes.append(mesh)
	return meshes


## The grass of the biome a point is in, or the snow if it is high enough for it.
func _grass_at(point: Vector2) -> Texture2D:
	for span: Dictionary in grass_spans:
		if point.x >= span["a"] and point.x <= span["b"]:
			if span.has("high") and point.y < span["line"]:
				return span["high"]
			return span["texture"]
	return grass_texture


## One chunk's drawing.
class Face extends Node2D:
	var world: RockWorld
	var key := Vector2i.ZERO
	var front := false
	var _keep := []  # the meshes drawn, so they are not freed while shown

	func _ready() -> void:
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func _draw() -> void:
		_keep = world.paint(self, key, front)

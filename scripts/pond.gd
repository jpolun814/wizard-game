class_name Pond
extends Area2D

## A pool sunk into the ground, of water or of lava. Its origin is the top-left corner of the surface.
## Walkers wade through water slowly. Lava burns whoever is in it, and sets plants alight. Frost Bridge freezes the
## water's surface into ice you can walk across; fire melts it again. A lily pad floats on water and burns on lava.
## Water puts out any fire shot that falls into it. The pool is drawn behind the ground, so only the hollow shows.
## Once someone comes near, the liquid is a LiquidGrid: it really flows, so a pit dug beside it fills and the pool's level drops.

const ICE_THICKNESS := 14.0
const ICE_SECONDS := 30.0
const EDGE := 28.0  # how far past its columns the fill reaches, to meet the smoothed edges of the hollow
const TICK := 0.5
const LAVA_DAMAGE := 8
const ICE_TEXTURE := preload("res://art/props/ice_fill.png")
const SIDE := 160.0       # how far to either side of the pool the liquid can spread, if the ground there is dug away
const HEADROOM := 32.0    # room above the surface, for liquid pushed up
const LOOSE_HEADROOM := 96.0  # and above a puddle, which has no pool under it: the water poured in lands high in the grid
const BELOW := 160.0      # and below the bed
const RIM_OVERLAP := 12.0 # how far liquid runs under the ground beside it, to hide the gap between a square cell and the smooth edge of the ground
const WATER_TOP := Color(0.2, 0.46, 0.72)     # the colours of water: lighter at the surface, darker below, with a bright edge
const WATER_BOTTOM := Color(0.07, 0.18, 0.38)
const WATER_RIM := Color(0.75, 0.92, 1.0)
const GROW := 12           # cells added at an edge the liquid has run up to
const EDGE_WET := 0.05     # how much liquid at the edge of its grid makes it grow
const MOST_COLS := 360     # the biggest a pool's grid can grow, so liquid spreading over a plain ends somewhere
const MOST_ROWS := 120
const ROWS_A_FRAME := 2   # rows of ground a pool reads in a frame while its liquid is being made
const WATER_STEP := 1.0 / 30.0  # seconds between rounds of flow: water, which takes two steps a round
const COOL_SECONDS := 22.0  # how long poured lava takes to cool to a crust
const CRUST := Color(0.16, 0.1, 0.1)
const LAVA_STEP := 1.0 / 10.0   # and lava, which is slower to move and takes one

var width := 200.0
var depth := 90.0
var lava := false
var cools := false  # lava from a volcano's eruption: once it stops pouring it darkens to a crust, stops burning, and is gone
var loose := false  # a puddle made by a spell, not a pool the world was dug with: it starts empty
var ground: Terrain  # the ground the pool sits in; when given, the liquid flows over it
var grid: LiquidGrid  # the flowing liquid, made when the pool first comes into view
var _making: LiquidGrid  # a grid whose ground is being read a few rows a frame, before it takes over
var _making_row := 0
var clip: Array = []  # outlines of the open air, in world pixels: when given, the pool fills only the hollow
var _slabs: Array[Dictionary] = []  # each {"body": StaticBody2D, "x0": float, "x1": float, "y": float (the water's surface), "age": float}
var _tick := 0.0
var _t := 0.0
var _pieces: Array = []  # the pool's fill, cut to the hollow it sits in: worked out once, since the cave never changes
var _seen := true        # false while the pool is off screen: nothing about it is drawn or animated then
var _flow_clock := 0.0
var _heat := 1.0         # how molten cooling lava still is: 1 is fresh, 0 is crust
var _reach: CollisionShape2D  # the area that finds the bodies near the liquid, kept as big as the grid
var _watch: VisibleOnScreenNotifier2D
var _runs: Array = []    # the grid's liquid as columns of stretches, worked out again when it changes
var _runs_version := -1
var _shapes: Array = []   # the polygons the liquid is drawn as, worked out when it changes: each {"points", "colours"}
var _edges: Array = []    # and the bright edges of its open surface: each {"line", "phase"}
var _air: Array = []      # the open air round the liquid, cut to its space, for cutting the liquid to the ground
var _air_area := Rect2()
var _air_dirty := true


func _ready() -> void:
	_reach = CollisionShape2D.new()
	_reach.shape = RectangleShape2D.new()
	add_child(_reach)
	_fit_reach()
	collision_mask = 6  # enemies and the player
	z_index = -1  # behind the ground: its slopes cover the pool's corners
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if lava:
		add_to_group("fires")
		add_to_group("danger")
	add_to_group("ponds")
	_pieces = _hollow()
	if ground != null:
		ground.about_to_change.connect(_on_ground_about_to_change)
		ground.changed.connect(_on_ground_changed)
	var notifier := VisibleOnScreenNotifier2D.new()
	_watch = notifier
	notifier.screen_entered.connect(func() -> void:
		_seen = true
		begin_grid()
		queue_redraw())
	notifier.screen_exited.connect(func() -> void: _seen = false)
	add_child(notifier)
	_fit_reach()
	_seen = false  # the notifier tells when it is on screen


func _physics_process(delta: float) -> void:
	_t += delta
	_tick -= delta
	if _seen:
		queue_redraw()
	var tick := _tick <= 0.0
	if tick:
		_tick = TICK
	_make_a_little()
	_flow(delta)
	for body in get_overlapping_bodies():
		if not SpellTargets.affects(body) or _flies(body) or _on_ice(body) or not holds(body):
			continue
		body.soak(Color(1.0, 0.55, 0.3) if lava else Color(0.55, 0.75, 1.0), surface_at(body.global_position.x), molten())
		if molten():
			if tick:
				SpellTargets.hurt(body, LAVA_DAMAGE, "Fire", false, true)
		elif body.is_in_group("mobs"):
			body.apply_slow(0.3)
		else:
			body.apply_debuff("slow", 0.3)
	_age_ice(delta)
	_cool(delta)
	if not lava:
		_douse_shots()


## Lava that has stopped pouring cools: it darkens and, once it is crust, no longer burns anything; when it is cold it is gone.
func _cool(delta: float) -> void:
	if not cools or _heat <= 0.0:
		return
	_heat = maxf(_heat - delta / COOL_SECONDS, 0.0)
	if _heat < 0.5 and is_in_group("fires"):
		remove_from_group("fires")
		remove_from_group("danger")
	if _heat <= 0.0 and grid != null:
		grid.take(grid.world_rect(), INF)
		queue_free()


## True while the lava is hot enough to burn.
func molten() -> bool:
	return lava and (not cools or _heat >= 0.5)


## The space the liquid can reach: the pool itself, and room round it for liquid to spread into if the ground there is dug away. Once the liquid
## is flowing this is its grid, which grows wherever the liquid runs up to its edge.
func region() -> Rect2:
	if grid != null and grid.cols > 0:
		return grid.world_rect()
	var above := LOOSE_HEADROOM if loose else HEADROOM
	return Rect2(global_position + Vector2(-SIDE, -above), Vector2(width + SIDE * 2.0, depth + above + BELOW))


## Keeps the area that finds nearby bodies, and the rectangle that says when the liquid is on screen, as big as the space the liquid has.
func _fit_reach() -> void:
	var space := region()
	(_reach.shape as RectangleShape2D).size = space.size
	_reach.position = space.position - global_position + space.size * 0.5
	if _watch != null:
		_watch.rect = Rect2(space.position - global_position - Vector2(16.0, 32.0), space.size + Vector2(32.0, 48.0))


## Makes the flowing liquid at once, full wherever the pool was, if it has not been made yet.
func ensure_grid() -> void:
	if grid != null or ground == null:
		return
	_making = null
	grid = LiquidGrid.new()
	grid.setup(region())
	grid.read_ground(ground.solid_at)
	if not loose:
		grid.fill(Rect2(global_position + Vector2(-EDGE, 0.0), Vector2(width + EDGE * 2.0, depth)))


## Starts making the liquid a few rows of ground a frame, so that a pool coming into view never stalls the game. It takes over when it is ready.
func begin_grid() -> void:
	if grid != null or _making != null or ground == null:
		return
	_making = LiquidGrid.new()
	_making.setup(region())
	_making_row = 0


func _make_a_little() -> void:
	if _making == null:
		return
	_making.read_rows(ground.solid_at, _making_row, _making_row + ROWS_A_FRAME - 1)
	_making_row += ROWS_A_FRAME
	if _making_row < _making.rows:
		return
	grid = _making
	_making = null
	if not loose:
		grid.fill(Rect2(global_position + Vector2(-EDGE, 0.0), Vector2(width + EDGE * 2.0, depth)))
	grid.wake()


func _flow(delta: float) -> void:
	if grid == null or grid.asleep:
		return
	_flow_clock += delta
	if _flow_clock >= (LAVA_STEP if lava else WATER_STEP):
		_flow_clock = 0.0  # (one step at most in a frame, however long the frame was)
		grid.step()
		if not lava:
			grid.step()
		_make_room()


## Liquid that has run to the edge of its grid gets more room there, as far as the ground lets it go.
func _make_room() -> void:
	var wanted := grid.edges_wet(EDGE_WET)
	if wanted == 0:
		return
	var left := GROW if wanted & LiquidGrid.LEFT != 0 and grid.cols + GROW <= MOST_COLS else 0
	var right := GROW if wanted & LiquidGrid.RIGHT != 0 and grid.cols + left + GROW <= MOST_COLS else 0
	var up := GROW if wanted & LiquidGrid.UP != 0 and grid.rows + GROW <= MOST_ROWS else 0
	var down := GROW if wanted & LiquidGrid.DOWN != 0 and grid.rows + up + GROW <= MOST_ROWS else 0
	if left + right + up + down == 0:
		return
	var before := grid.world_rect()
	grid.grow(left, right, up, down)
	var after := grid.world_rect()
	# Only the strips that were added are read.
	if left > 0:
		grid.read_ground(ground.solid_at, Rect2(after.position, Vector2(left * LiquidGrid.CELL, after.size.y)))
	if right > 0:
		grid.read_ground(ground.solid_at, Rect2(Vector2(before.end.x, after.position.y), Vector2(right * LiquidGrid.CELL, after.size.y)))
	if up > 0:
		grid.read_ground(ground.solid_at, Rect2(after.position, Vector2(after.size.x, up * LiquidGrid.CELL)))
	if down > 0:
		grid.read_ground(ground.solid_at, Rect2(Vector2(after.position.x, before.end.y), Vector2(after.size.x, down * LiquidGrid.CELL)))
	_fit_reach()


## The ground is about to be dug: make the liquid first, so it has the pool as it was.
func _on_ground_about_to_change(area: Rect2) -> void:
	if area.intersects(region()):
		ensure_grid()  # (at once: the pool as it was, before the pit)


## The ground has changed: the liquid looks at it again and flows into whatever was opened.
func _on_ground_changed(area: Rect2) -> void:
	_air_dirty = true
	if grid != null and area.intersects(region()):
		grid.read_ground(ground.solid_at, area.grow(LiquidGrid.CELL))


## True where a point is in the liquid.
func wet_at(point: Vector2) -> bool:
	if grid != null:
		return grid.wet_at(point)
	return Rect2(global_position, Vector2(width, depth)).has_point(point)


## The height of the liquid's surface where a body at this x would stand in it.
func surface_at(x: float) -> float:
	if grid != null:
		var level := grid.surface_at(x)
		if level < INF:
			return level
	return global_position.y


## Puts water in at a point of the world (a spring, a spill). Returns how much went in.
func pour(point: Vector2, amount: float) -> float:
	_heat = 1.0  # fresh lava heats the pool again
	if cools and lava and not is_in_group("fires"):
		add_to_group("fires")
		add_to_group("danger")
	ensure_grid()
	if grid == null:
		return 0.0
	var put := 0.0
	for dx in [-LiquidGrid.CELL, 0.0, LiquidGrid.CELL]:  # over three cells, so it runs out both ways
		put += grid.add(point + Vector2(dx, 0.0), amount / 3.0)
	return put


## Takes liquid out from the surface down within a rectangle of the world, up to an amount. Returns how much came out.
func draw_off(area: Rect2, amount: float) -> float:
	if grid == null:
		return 0.0
	return grid.take(area, amount)


## The pool whose liquid has room at a point of the world, or null if there is none.
static func water_near(tree: SceneTree, point: Vector2) -> Pond:
	for pond: Pond in tree.get_nodes_in_group("ponds"):
		if not pond.lava and pond.region().has_point(point):
			return pond
	return null


## The height of the water's surface at an x, when there is water within `reach` of a height `near` (a pad drawn there floats on it); INF if not.
static func surface_near(tree: SceneTree, x: float, near: float, reach: float) -> float:
	for pond: Pond in tree.get_nodes_in_group("ponds"):
		if pond.lava or pond.grid == null:
			continue
		var level := pond.grid.surface_at(x)
		if level < INF and absf(level - near) <= reach:
			return level
	return INF


## The puddle of lava that has room at a point of the world, or null if there is none. A pool the world was dug with is not one
## to join: lava poured beside it makes a puddle of its own, which flows into the pool if the ground slopes that way.
static func lava_near(tree: SceneTree, point: Vector2) -> Pond:
	for pond: Pond in tree.get_nodes_in_group("ponds"):
		if pond.lava and pond.loose and pond.region().has_point(point):
			return pond
	return null


## Water (or lava) spilt at a point: it joins the pool there, or, where there is none, makes a puddle of its own that runs over the ground.
static func spill(parent: Node, ground: Terrain, point: Vector2, amount: float, molten := false) -> Pond:
	var pond := lava_near(parent.get_tree(), point) if molten else water_near(parent.get_tree(), point)
	if pond == null:
		pond = Pond.new()
		pond.lava = molten
		pond.loose = true
		pond.width = 32.0
		pond.depth = 64.0
		pond.ground = ground
		pond.position = point - Vector2(16.0, 0.0)
		parent.add_child(pond)
	pond.pour(point, amount)
	return pond


## The stretch of liquid in the column at this x, as the heights of its top and bottom (the tallest, if there are several); (0, 0) when it is dry.
## Before the liquid flows it is the pool as it was dug.
func wet_span(x: float) -> Vector2:
	if grid == null:
		return Vector2(global_position.y, global_position.y + depth) if x >= global_position.x and x <= global_position.x + width else Vector2.ZERO
	var c := floori((x - grid.origin.x) / LiquidGrid.CELL)
	if c < 0 or c >= grid.cols:
		return Vector2.ZERO
	var best := Vector2.ZERO
	for run: Array in grid.runs_in(c):
		if run[1] - run[0] > best.y - best.x:
			best = Vector2(run[0], run[1])
	return best


## True when a body is in the liquid: its feet or its middle are.
func holds(body: Node2D) -> bool:
	return wet_at(body.global_position + Vector2(0.0, -4.0)) or wet_at(SpellTargets.center_of(body))


## A fire shot that drops into the water goes out in a puff of steam.
func _douse_shots() -> void:
	for shot in get_tree().get_nodes_in_group("shots"):
		if shot.is_in_group("fires") and wet_at(shot.global_position):
			Fx.smoke(get_parent(), shot.global_position, Color(0.9, 0.95, 1.0, 0.6), 4, 24.0, 40.0)
			Sfx.play("freeze", shot.global_position, -6.0)
			if shot.has_method("_finish"):
				shot._finish()
			else:
				shot.queue_free()


func _flies(body: Node2D) -> bool:
	return body.is_in_group("mobs") and body.KINDS[body.kind].role == "flyer"


## True when the body stands on frozen water rather than in it.
func _on_ice(body: Node2D) -> bool:
	for slab in _slabs:
		if body.global_position.x >= slab["x0"] and body.global_position.x <= slab["x1"] and body.global_position.y <= slab["y"] + 6.0:
			return true
	return false


## Freezes the surface between two x positions, as far as the pond reaches. Returns false for lava, which does not freeze.
func freeze_span(x0: float, x1: float) -> bool:
	if lava:
		return false
	var left := maxf(x0, global_position.x)
	var right := minf(x1, global_position.x + width)
	var level := global_position.y
	if grid != null:  # where the liquid flows, the ice lies on the surface as it is now, as far as that surface stays level
		var middle := (x0 + x1) * 0.5
		level = grid.surface_at(middle)
		if level == INF:
			return false
		left = middle
		right = middle
		while left - 8.0 >= x0 and absf(grid.surface_at(left - 8.0) - level) <= LiquidGrid.CELL:
			left -= 8.0
		while right + 8.0 <= x1 and absf(grid.surface_at(right + 8.0) - level) <= LiquidGrid.CELL:
			right += 8.0
	if right - left < 12.0:
		return false
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(right - left, ICE_THICKNESS)
	shape.shape = rect
	shape.position = Vector2((left + right) * 0.5 - global_position.x, level - global_position.y + ICE_THICKNESS * 0.5)
	body.add_child(shape)
	add_child(body)
	_slabs.append({"body": body, "x0": left, "x1": right, "y": level, "age": 0.0})
	Sfx.play("freeze", Vector2((left + right) * 0.5, level))
	Shatter.spawn(get_parent(), Vector2((left + right) * 0.5, level), Color("#cdeeff"))
	return true


## Ice lasts a while, and melts at once where fire reaches it.
func _age_ice(delta: float) -> void:
	for i in range(_slabs.size() - 1, -1, -1):
		var slab: Dictionary = _slabs[i]
		slab["age"] += delta
		var box := Rect2(slab["x0"], slab["y"], slab["x1"] - slab["x0"], ICE_THICKNESS)
		if slab["age"] >= ICE_SECONDS or SpellTargets.fire_touching(get_tree(), box):
			slab["body"].queue_free()
			Fx.smoke(get_parent(), box.get_center(), Color(0.85, 0.95, 1.0, 0.5), 5, 24.0, 30.0)
			_slabs.remove_at(i)
	if _seen:
		queue_redraw()


func danger_at(point: Vector2) -> bool:
	if grid != null:
		return molten() and grid.wet_at(point + Vector2(0.0, 20.0))
	return molten() and point.x >= global_position.x and point.x <= global_position.x + width and point.y > global_position.y - 20.0 and point.y < global_position.y + depth


## The pool's fill, cut to the open air round it when there are cave outlines to cut it to.
func _hollow() -> Array:
	# A little wider than the pool: the smoothed edges of the hollow bulge past the columns it is dug in, and the fill is cut to the hollow anyway.
	var fill := PackedVector2Array([Vector2(-EDGE, 2), Vector2(width + EDGE, 2), Vector2(width + EDGE, depth), Vector2(-EDGE, depth)])
	if clip.is_empty():
		return [fill]
	var window := Rect2(global_position - Vector2(16.0, 16.0), Vector2(width + 32.0, depth + 32.0))
	var pieces := []
	for outline: PackedVector2Array in clip:
		var bounds := Rect2(outline[0], Vector2.ZERO)
		for point in outline:
			bounds = bounds.expand(point)
		if not bounds.intersects(window):
			continue  # an outline whose box misses this pool cannot cut it (its points are far apart, so its box is what counts)
		var local := PackedVector2Array()
		for point in outline:
			local.append(point - global_position)
		for part: PackedVector2Array in Geometry2D.intersect_polygons(fill, local):
			pieces.append(part)
	return pieces


## The pool: a solid fill, lighter at the surface, with a moving bright edge, and ice where it is frozen.
func _draw() -> void:
	var top := Color(1.0, 0.5, 0.12) if lava else WATER_TOP
	var bottom := Color(0.55, 0.1, 0.05) if lava else WATER_BOTTOM
	var rim := Color(1.0, 0.8, 0.3) if lava else WATER_RIM
	if cools and lava:  # cooling lava goes dark
		var crust := 1.0 - _heat
		top = top.lerp(CRUST, crust)
		bottom = bottom.lerp(CRUST, crust)
		rim = rim.lerp(CRUST.lightened(0.25), crust)
	if grid != null:
		_draw_liquid(top, bottom, rim)
		_draw_ice()
		return
	for part: PackedVector2Array in _pieces:
		var colors := PackedColorArray()
		for point in part:
			colors.append(top.lerp(bottom, clampf(point.y / depth, 0.0, 1.0)))
		draw_polygon(part, colors)
	var surface := PackedVector2Array()
	for i in int((width + EDGE * 2.0) / 8.0) + 1:
		var x := minf(i * 8.0, width + EDGE * 2.0) - EDGE
		surface.append(Vector2(x, 1.0 + sin(_t * 2.0 + x * 0.08) * 1.5))
	for part: PackedVector2Array in _pieces:  # the bright edge only where there is hollow for it, never over the ground
		for line: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(surface, part):
			draw_polyline(line, rim, 2.0)
	_draw_ice()


func _draw_ice() -> void:
	for slab in _slabs:
		var rect := Rect2(slab["x0"] - global_position.x, slab["y"] - global_position.y, slab["x1"] - slab["x0"], ICE_THICKNESS)
		draw_texture_rect(ICE_TEXTURE, rect, true, Color(0.85, 0.95, 1.0))


## The height of the open surface in a column beside one being drawn, when it is near enough to run on from it; the height given when it is not.
func _surface_beside(c: int, height: float) -> float:
	if c < 0 or c >= _runs.size() or _runs[c] == null:
		return height
	for run: Array in _runs[c]:
		var other: float = run[0] - global_position.y
		if run[2] and absf(other - height) <= LiquidGrid.CELL * 1.6:
			return other
	return height


## The flowing liquid: each column's stretches of it as a block shaded from the surface down, and a bright edge on the open surface. Where
## the liquid lies against the ground it is cut to the smooth edge of the ground, so a slope looks as smooth with liquid on it as without.
func _draw_liquid(top: Color, bottom: Color, rim: Color) -> void:
	if _runs_version != grid.version or _air_dirty:
		_runs_version = grid.version
		_runs = []
		_runs.resize(grid.cols)
		var wet := grid.wet_columns()
		for c in range(wet.x, wet.y + 1):
			_runs[c] = grid.runs_in(c)
		_build_shapes(top, bottom)
	for shape: Dictionary in _shapes:
		draw_polygon(shape["points"], shape["colours"])
	for edge: Dictionary in _edges:
		var wobble := sin(_t * 2.0 + edge["phase"] * 0.08) * 1.5
		var line: PackedVector2Array = edge["line"]
		var moved := PackedVector2Array()
		for point in line:
			moved.append(point + Vector2(0.0, 1.0 + wobble))
		draw_polyline(moved, rim, 2.0)


## Works out the polygons of the liquid from its columns. Runs that lie against the ground reach into it by a whole cell and are then cut
## to the air, so nothing of them shows but the part in the open; the rest are plain blocks. An open surface meets the surface of the column
## beside it halfway, so the top runs on in a slope instead of a staircase of cells.
func _build_shapes(top: Color, bottom: Color) -> void:
	_shapes = []
	_edges = []
	var air := _air_pieces()
	var cell := LiquidGrid.CELL
	var shift := grid.origin - global_position
	for c in _runs.size():
		if _runs[c] == null:
			continue
		for run: Array in _runs[c]:
			var x0 := shift.x + c * cell
			var y0: float = run[0] - global_position.y
			var y1: float = run[1] - global_position.y
			var against: bool = run[3] or run[4] or run[5]
			var reach := cell if (against and not air.is_empty()) else RIM_OVERLAP
			var left := x0 - (reach if run[3] else 0.0)
			var right := x0 + cell + (reach if run[4] else 0.0)
			var low := y1 + (reach if run[5] else 0.0)
			var top_left := y0
			var top_right := y0
			if run[2]:
				top_left = (y0 + _surface_beside(c - 1, y0)) * 0.5 if not run[3] else y0
				top_right = (y0 + _surface_beside(c + 1, y0)) * 0.5 if not run[4] else y0
			var outline := PackedVector2Array([Vector2(left, top_left), Vector2(right, top_right), Vector2(right, low), Vector2(left, low)])
			var pieces: Array = [outline]
			if against and not air.is_empty():
				pieces = []
				for open: PackedVector2Array in air:
					pieces.append_array(Geometry2D.intersect_polygons(outline, open))
			for piece: PackedVector2Array in pieces:
				if Geometry2D.is_polygon_clockwise(piece) == false and piece.size() >= 3 and not Geometry2D.triangulate_polygon(piece).is_empty():
					var colours := PackedColorArray()
					for point in piece:
						colours.append(top.lerp(bottom, clampf(point.y / depth, 0.0, 1.0)))
					_shapes.append({"points": piece, "colours": colours})
			if run[2]:
				var surface := PackedVector2Array([Vector2(left, top_left), Vector2(right, top_right)])
				var lines: Array = [surface]
				if against and not air.is_empty():
					lines = []
					for open: PackedVector2Array in air:
						lines.append_array(Geometry2D.intersect_polyline_with_polygon(surface, open))
				for line: PackedVector2Array in lines:
					_edges.append({"line": line, "phase": x0 + cell * 0.5})


## The open air round the liquid, as polygons in the pool's own coordinates, or none where the ground has no smooth edge of its own (the
## waiting room's, which is drawn over the liquid). Made again when the ground changes or the liquid's space grows.
func _air_pieces() -> Array:
	if ground == null or not ground.tiled or grid == null:
		return []
	var area := grid.world_rect().grow(LiquidGrid.CELL * 2.0)
	if _air_dirty or area != _air_area:
		_air_dirty = false
		_air_area = area
		_air = []
		var window := PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])
		for outline: PackedVector2Array in ground.air_in(area):
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(outline, window):
				var local := PackedVector2Array()
				for point in piece:
					local.append(point - global_position)
				_air.append(local)
	return _air

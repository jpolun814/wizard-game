class_name Pond
extends Area2D

## A pool sunk into the ground, of water or of lava. Its origin is the top-left corner of the surface.
## Walkers wade through water slowly. Lava burns whoever is in it, and sets plants alight. Frost Bridge freezes the
## water's surface into ice you can walk across; fire melts it again. A lily pad floats on water and burns on lava.
## Water puts out any fire shot that falls into it. The pool is drawn behind the ground, so only the hollow shows.

const ICE_THICKNESS := 14.0
const ICE_SECONDS := 30.0
const TICK := 0.5
const LAVA_DAMAGE := 8
const ICE_TEXTURE := preload("res://art/props/ice_fill.png")

var width := 200.0
var depth := 90.0
var lava := false
var clip: Array = []  # outlines of the open air, in world pixels: when given, the pool fills only the hollow
var _slabs: Array[Dictionary] = []  # each {"body": StaticBody2D, "x0": float, "x1": float, "age": float}
var _tick := 0.0
var _t := 0.0


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, depth)
	shape.shape = rect
	shape.position = Vector2(width * 0.5, depth * 0.5)
	add_child(shape)
	collision_mask = 6  # enemies and the player
	z_index = -1  # behind the ground: its slopes cover the pool's corners
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if lava:
		add_to_group("fires")
		add_to_group("danger")
	add_to_group("ponds")


func _physics_process(delta: float) -> void:
	_t += delta
	_tick -= delta
	queue_redraw()
	var tick := _tick <= 0.0
	if tick:
		_tick = TICK
	for body in get_overlapping_bodies():
		if not SpellTargets.affects(body) or _flies(body) or _on_ice(body):
			continue
		body.soak(Color(1.0, 0.55, 0.3) if lava else Color(0.55, 0.75, 1.0))
		if lava:
			if tick:
				SpellTargets.hurt(body, LAVA_DAMAGE, "Fire")
		elif body.is_in_group("mobs"):
			body.apply_slow(0.3)
		else:
			body.apply_debuff("slow", 0.3)
	_age_ice(delta)
	if not lava:
		_douse_shots()


## A fire shot that drops into the water goes out in a puff of steam.
func _douse_shots() -> void:
	var water := Rect2(global_position, Vector2(width, depth))
	for shot in get_tree().get_nodes_in_group("shots"):
		if shot.is_in_group("fires") and water.has_point(shot.global_position):
			Fx.smoke(get_parent(), shot.global_position, Color(0.9, 0.95, 1.0, 0.6), 4, 24.0, 40.0)
			Sfx.play("freeze", shot.global_position, -6.0)
			if shot.has_method("_finish"):
				shot._finish()
			else:
				shot.queue_free()


func _flies(body: Node2D) -> bool:
	return body.is_in_group("mobs") and body.KINDS[body.kind]["role"] == "flyer"


## True when the body stands on frozen water rather than in it.
func _on_ice(body: Node2D) -> bool:
	for slab in _slabs:
		if body.global_position.x >= slab["x0"] and body.global_position.x <= slab["x1"] and body.global_position.y <= global_position.y + 6.0:
			return true
	return false


## Freezes the surface between two x positions, as far as the pond reaches. Returns false for lava, which does not freeze.
func freeze_span(x0: float, x1: float) -> bool:
	if lava:
		return false
	var left := maxf(x0, global_position.x)
	var right := minf(x1, global_position.x + width)
	if right - left < 12.0:
		return false
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(right - left, ICE_THICKNESS)
	shape.shape = rect
	shape.position = Vector2((left + right) * 0.5 - global_position.x, ICE_THICKNESS * 0.5)
	body.add_child(shape)
	add_child(body)
	_slabs.append({"body": body, "x0": left, "x1": right, "age": 0.0})
	Sfx.play("freeze", Vector2((left + right) * 0.5, global_position.y))
	Shatter.spawn(get_parent(), Vector2((left + right) * 0.5, global_position.y), Color("#cdeeff"))
	return true


## Ice lasts a while, and melts at once where fire reaches it.
func _age_ice(delta: float) -> void:
	for i in range(_slabs.size() - 1, -1, -1):
		var slab: Dictionary = _slabs[i]
		slab["age"] += delta
		var box := Rect2(slab["x0"], global_position.y, slab["x1"] - slab["x0"], ICE_THICKNESS)
		if slab["age"] >= ICE_SECONDS or SpellTargets.fire_touching(get_tree(), box):
			slab["body"].queue_free()
			Fx.smoke(get_parent(), box.get_center(), Color(0.85, 0.95, 1.0, 0.5), 5, 24.0, 30.0)
			_slabs.remove_at(i)
	queue_redraw()


func danger_at(point: Vector2) -> bool:
	return lava and point.x >= global_position.x and point.x <= global_position.x + width and point.y > global_position.y - 20.0


## The pool: a solid fill, lighter at the surface, with a moving bright edge, and ice where it is frozen.
func _draw() -> void:
	var top := Color(1.0, 0.5, 0.12) if lava else Color(0.2, 0.46, 0.72)
	var bottom := Color(0.55, 0.1, 0.05) if lava else Color(0.07, 0.18, 0.38)
	var rim := Color(1.0, 0.8, 0.3) if lava else Color(0.75, 0.92, 1.0)
	var fill := PackedVector2Array([Vector2(0, 2), Vector2(width, 2), Vector2(width, depth), Vector2(0, depth)])
	var pieces: Array = [fill]
	if not clip.is_empty():
		pieces = []
		for outline: PackedVector2Array in clip:
			var local := PackedVector2Array()
			for point in outline:
				local.append(point - global_position)
			for part: PackedVector2Array in Geometry2D.intersect_polygons(fill, local):
				pieces.append(part)
	for part: PackedVector2Array in pieces:
		var colors := PackedColorArray()
		for point in part:
			colors.append(top.lerp(bottom, clampf(point.y / depth, 0.0, 1.0)))
		draw_polygon(part, colors)
	var surface := PackedVector2Array()
	for i in int(width / 8.0) + 1:
		var x := minf(i * 8.0, width)
		surface.append(Vector2(x, 1.0 + sin(_t * 2.0 + x * 0.08) * 1.5))
	draw_polyline(surface, rim, 2.0)
	for slab in _slabs:
		var rect := Rect2(slab["x0"] - global_position.x, 0, slab["x1"] - slab["x0"], ICE_THICKNESS)
		draw_texture_rect(ICE_TEXTURE, rect, true, Color(0.85, 0.95, 1.0))

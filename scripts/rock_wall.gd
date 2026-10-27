class_name RockWall
extends StaticBody2D

## A wall of brick that bars a passage: eight rows high, a few columns thick, with room over the top to climb. It is as solid as rock until it
## is broken down: a boulder landing on it or beside it, an earthquake or a swing of an ogre's club wears it down, and it crumbles when
## it has taken enough.

const TEXTURE := preload("res://art/tiles/castle_brick.png")
const HEALTH := 150.0

var columns: Array = []  # {"x": column, "top": first row of the wall, "bottom": the floor's row}, in tiles
var _health := HEALTH
var _box := Rect2()


func _ready() -> void:
	add_to_group("breakables")
	collision_layer = 1
	collision_mask = 0
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var t := float(ArenaGen.TILE)
	var left := INF
	var right := -INF
	var top := INF
	var bottom := -INF
	for column: Dictionary in columns:
		var rect := Rect2(column["x"] * t, column["top"] * t, t, (column["bottom"] - column["top"]) * t)
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		add_child(shape)
		left = minf(left, rect.position.x)
		right = maxf(right, rect.end.x)
		top = minf(top, rect.position.y)
		bottom = maxf(bottom, rect.end.y)
	_box = Rect2(left, top, right - left, bottom - top)
	z_index = 1


## A blow from stone or a quake near the wall. True when it reached it.
func take_blow_near(point: Vector2, damage: float) -> bool:
	if not _box.grow(24.0).has_point(point):
		return false
	_health -= damage
	Fx.debris(get_parent(), point, Color("#6b5a6e"), 6, 160.0)
	Sfx.play("stones", point, -6.0)
	if _health <= 0.0:
		_gone()
	queue_redraw()
	return true


func _gone() -> void:
	Sfx.play("quake", _box.get_center())
	GameCamera.shake_scene(get_tree(), 0.5)
	for k in 4:
		Fx.debris(get_parent(), _box.position + Vector2(randf() * _box.size.x, randf() * _box.size.y), Color("#6b5a6e"), 8, 220.0)
	Fx.smoke(get_parent(), _box.get_center(), Color(0.5, 0.45, 0.5, 0.6), 10, 40.0, 40.0)
	queue_free()


## An earthquake shakes it, when it is within reach of a point.
func shake(point: Vector2, reach: float, damage: float) -> void:
	if _box.grow(reach).has_point(point):
		take_blow_near(_box.get_center(), damage)


## Is the point in the wall.
func covers(point: Vector2) -> bool:
	return _box.has_point(point)


func _draw() -> void:
	var t := float(ArenaGen.TILE)
	var wear := clampf(_health / HEALTH, 0.0, 1.0)
	for column: Dictionary in columns:
		var rect := Rect2(column["x"] * t, column["top"] * t, t, (column["bottom"] - column["top"]) * t)
		draw_texture_rect(TEXTURE, rect, true, Color(0.7 + 0.3 * wear, 0.65 + 0.35 * wear, 0.7 + 0.3 * wear))
	if wear < 0.7:  # cracks, more of them the more it has taken
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for k in int((1.0 - wear) * 14.0):
			var at := _box.position + Vector2(rng.randf() * _box.size.x, rng.randf() * _box.size.y)
			var bend := Vector2(rng.randf_range(-10, 10), rng.randf_range(8, 22))
			draw_polyline(PackedVector2Array([at, at + bend * 0.5 + Vector2(4, 0), at + bend]), Color(0.05, 0.03, 0.06, 0.8), 2.0)
	draw_rect(_box, Color(0.05, 0.03, 0.08), false, 2.0)

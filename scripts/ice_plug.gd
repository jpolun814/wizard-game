class_name IcePlug
extends StaticBody2D

## A plug of ice that fills a passage from the floor to the roof, a few columns thick. It is as solid as rock until it is
## gone: fire melts it (a steady fire in a few seconds, a fireball at once), and a blow from stone, a boulder or the like breaks it.

const TEXTURE := preload("res://art/props/ice_fill.png")
const HEALTH := 120.0
const MELT := 30.0  # health a steady fire takes off each second, for each point of its heat

var columns: Array = []  # {"x": column, "top": first row of ice, "bottom": the floor's row}, in tiles
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


func _physics_process(delta: float) -> void:
	var heat := SpellTargets.fire_heat_near(get_tree(), _box, 6.0)
	if heat > 0.0:
		_health -= heat * MELT * delta
		if randf() < delta * 6.0:
			Fx.smoke(get_parent(), _box.position + Vector2(randf() * _box.size.x, randf() * _box.size.y), Color(0.9, 0.95, 1.0, 0.5), 2, 18.0, 30.0)
	elif SpellTargets.fire_touching(get_tree(), _box):
		_health -= HEALTH  # a fireball
	if _health <= 0.0:
		_gone(true)
	queue_redraw()


## A blow from stone: a boulder, a wall, a club. True when it reached the ice.
func take_blow_near(point: Vector2, damage: float) -> bool:
	if not _box.grow(24.0).has_point(point):
		return false
	_health -= damage * 2.0
	Shatter.spawn(get_parent(), point, Color("#cdeeff"))
	Sfx.play("ice_shatter", point, -6.0)
	if _health <= 0.0:
		_gone(false)
	return true


func _gone(melted: bool) -> void:
	if melted:
		Fx.smoke(get_parent(), _box.get_center(), Color(0.9, 0.95, 1.0, 0.6), 10, 36.0, 40.0)
		Sfx.play("freeze", _box.get_center(), -2.0)
	else:
		Sfx.play("ice_shatter", _box.get_center())
		GameCamera.shake_scene(get_tree(), 0.2)
	Shatter.spawn(get_parent(), _box.get_center(), Color("#cdeeff"))
	queue_free()


## An earthquake shakes it, when it is within reach of a point.
func shake(point: Vector2, reach: float, damage: float) -> void:
	if _box.grow(reach).has_point(point):
		take_blow_near(_box.get_center(), damage)


## Is the point in the plug.
func covers(point: Vector2) -> bool:
	return _box.has_point(point)


func _draw() -> void:
	var t := float(ArenaGen.TILE)
	var wear := clampf(_health / HEALTH, 0.0, 1.0)
	for column: Dictionary in columns:
		var rect := Rect2(column["x"] * t, column["top"] * t, t, (column["bottom"] - column["top"]) * t)
		draw_texture_rect(TEXTURE, rect, true, Color(0.85, 0.95, 1.0, 0.55 + 0.4 * wear))
		draw_line(rect.position + Vector2(5, 0), rect.position + Vector2(5, rect.size.y), Color(1, 1, 1, 0.25 * wear), 2.0)

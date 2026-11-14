class_name BreakableBlock
extends StaticBody2D
## A block of whole columns that bars a passage and is as solid as rock until it is worn away: the plug of ice (IcePlug) and the wall of brick (RockWall).
## This holds what they share: the columns, the box round them, their health, and being shaken by an earthquake.

var columns: Array = []  # {"x": column, "top": first row of the block, "bottom": the floor's row}, in tiles
var _health := 0.0
var _box := Rect2()


## How much it takes to bring it down: each kind says its own.
func _max_health() -> float:
	return 1.0


func _ready() -> void:
	_health = _max_health()
	add_to_group("breakables")
	collision_layer = 1
	collision_mask = 0
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var left := INF
	var right := -INF
	var top := INF
	var bottom := -INF
	for column: Dictionary in columns:
		var rect := _rect_of(column)
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


## A blow from stone or a quake near the block. True when it reached it.
func take_blow_near(_point: Vector2, _damage: float) -> bool:
	return false


## An earthquake shakes it, when it is within reach of a point.
func shake(point: Vector2, reach: float, damage: float) -> void:
	if _box.grow(reach).has_point(point):
		take_blow_near(_box.get_center(), damage)


## Is the point in the block.
func covers(point: Vector2) -> bool:
	return _box.has_point(point)


## How much of it is left, from 1 whole to 0 gone.
func _wear() -> float:
	return clampf(_health / _max_health(), 0.0, 1.0)


## Where one of its columns is, in the block's own space.
func _rect_of(column: Dictionary) -> Rect2:
	var tile := float(ArenaGen.TILE)
	return Rect2(column["x"] * tile, column["top"] * tile, tile, (column["bottom"] - column["top"]) * tile)

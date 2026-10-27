class_name Gate
extends StaticBody2D

## A stone door across a tunnel. It keeps the way shut until it is opened.

var lock := -1  # the lock of the world's graph this door closes
var size := Vector2.ZERO


func _ready() -> void:
	add_to_group("gates")
	collision_layer = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	shape.position = size * 0.5
	add_child(shape)
	var face := Polygon2D.new()
	face.texture = load("res://art/tiles/stone.png")
	face.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	face.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)])
	face.uv = face.polygon
	face.color = Color(0.7, 0.7, 0.8)
	add_child(face)


func open() -> void:
	remove_from_group("gates")
	queue_free()

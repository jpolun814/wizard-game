class_name Crypt
extends Node2D

## A small stone tomb of the graveyard: a dark doorway between two statues, with a page lying in front of it and a skeleton on guard (the
## world raises the guard). It is only to be seen: its origin is on the ground at the middle of the doorway.

const DOOR := preload("res://art/props/door.png")
const STATUE := preload("res://art/props/statue.png")
const COLUMN := preload("res://art/props/church_column.png")


func _ready() -> void:
	z_index = -1
	for side in [-1.0, 1.0]:
		var column := Sprite2D.new()
		column.texture = COLUMN
		column.offset = Vector2(0.0, -COLUMN.get_height() * 0.5 + 3.0)
		column.position = Vector2(side * 56.0, 0.0)
		column.modulate = Color(0.7, 0.7, 0.8)
		add_child(column)
		var statue := Sprite2D.new()
		statue.texture = STATUE
		statue.offset = Vector2(0.0, -STATUE.get_height() * 0.5 + 3.0)
		statue.position = Vector2(side * 96.0, 0.0)
		statue.flip_h = side < 0.0
		add_child(statue)
	var door := Sprite2D.new()
	door.texture = DOOR
	door.scale = Vector2(2.0, 2.0)
	door.offset = Vector2(0.0, -DOOR.get_height() * 0.5 + 1.0)
	door.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(door)

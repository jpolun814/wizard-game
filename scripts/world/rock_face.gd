class_name RockFace
extends Node2D

## One chunk's drawing.

var world: RockWorld
var key := Vector2i.ZERO
var front := false
var _keep := []  # the meshes drawn, so they are not freed while shown

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func _draw() -> void:
	_keep = world.paint(self, key, front)

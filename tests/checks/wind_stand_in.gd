extends Node2D

## Moving air that is no spell: the one thing wind must do (see Elements).


func _ready() -> void:
	add_to_group("winds")


func blows_at(point: Vector2) -> bool:
	return point.distance_to(global_position) < 80.0

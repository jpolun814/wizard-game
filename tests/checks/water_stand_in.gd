extends Node2D

## Water that is no spell and no pond: the one thing a source of water must do (see Elements).


func _ready() -> void:
	add_to_group("waters")


func wets(point: Vector2) -> bool:
	return point.distance_to(global_position) < 80.0

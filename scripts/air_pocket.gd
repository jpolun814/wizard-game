class_name AirPocket
extends Node2D

## A pocket of air in a wreck on the sea floor (chapter 20): a hollow of the hull that the sea has not filled. Whoever stands in it is not under water, so
## they breathe again, and can cast fire and say a chant there. Its origin is the middle of its floor. It is only the room of the hull: the Pond leaves a
## body inside it dry (Pond.deep).

var size := Vector2(150.0, 110.0)  # the room, in pixels: its width, and how high it rises over the floor


func _ready() -> void:
	add_to_group("air_pockets")


## True when a point of the world lies in the room of the pocket.
func has_point(point: Vector2) -> bool:
	return Rect2(global_position + Vector2(-size.x * 0.5, -size.y), size).has_point(point)


## True when a point of the world lies in any air pocket.
static func holds(tree: SceneTree, point: Vector2) -> bool:
	for node: Node in tree.get_nodes_in_group("air_pockets"):
		if (node as AirPocket).has_point(point):
			return true
	return false

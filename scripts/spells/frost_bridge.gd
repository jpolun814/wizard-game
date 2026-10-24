class_name FrostBridge
extends Node

## Frost Bridge: a wavy line drawn across water freezes the surface under it into ice you can walk on. It does nothing
## where there is no water. Fire melts the ice, and it thaws by itself after a while (see Pond).

var line := PackedVector2Array()  # the drawn line, in world points; set before the effect enters the tree


func _ready() -> void:
	var box := GestureTemplates.bounds(line)
	var frozen := 0
	for pond in get_tree().get_nodes_in_group("ponds"):
		# The line must be drawn near the pond's surface: on it, or a little above or below.
		if box.end.y < pond.global_position.y - 120.0 or box.position.y > pond.global_position.y + pond.depth:
			continue
		if pond.freeze_span(box.position.x, box.end.x):
			frozen += 1
	if frozen == 0:
		FloatText.spawn(get_parent(), box.get_center() + Vector2(0, -20), "Nothing to freeze", Color("#9fd8ff"), 0.9)
	queue_free()

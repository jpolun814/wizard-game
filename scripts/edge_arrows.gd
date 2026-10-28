class_name EdgeArrows
extends Control

## Arrows at the edge of the screen that point to things that are off screen: the portal, and whoever is hexed (other than the
## wizard). Which things, and how they are named and coloured, is set by the group they are in.

@export var group := &"portals"
@export var caption := "Portal"
@export var colour := Color("#c9a3ff")
@export var outline := Color(0.1, 0.05, 0.15)

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var transform := get_viewport().get_canvas_transform()
	var font := get_theme_default_font()
	for thing in get_tree().get_nodes_in_group(group):
		var target: Node2D = thing.target if "target" in thing else thing
		if not is_instance_valid(target) or target.is_in_group("player"):
			continue
		var screen: Vector2 = transform * SpellTargets.center_of(target)
		if Rect2(Vector2.ZERO, view).grow(-30.0).has_point(screen):
			continue
		var dir := (screen - view * 0.5).normalized()
		var edge := Vector2(clampf(screen.x, 50.0, view.x - 50.0), clampf(screen.y, 90.0, view.y - 50.0))
		var tip := edge + dir * sin(_t * 5.0) * 4.0
		var arrow := PackedVector2Array([tip + dir * 16.0, tip + dir.rotated(2.4) * 14.0, tip + dir.rotated(-2.4) * 14.0])
		draw_colored_polygon(arrow, colour)
		draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]]), outline, 2.0)
		draw_string_outline(font, tip - dir * 30.0 + Vector2(-24, 6), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, outline)
		draw_string(font, tip - dir * 30.0 + Vector2(-24, 6), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, colour)

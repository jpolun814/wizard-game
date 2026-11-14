class_name BlankPage
extends Control

## A page with nothing on it yet: a faint hatching and a torn corner.

func _draw() -> void:
	for k in 5:
		var y := size.y * (0.2 + 0.12 * k)
		draw_line(Vector2(size.x * 0.12, y), Vector2(size.x * 0.88, y), Color(Spellbook.PAPER_DARK, 0.28), 2.0)
	var corner := PackedVector2Array([Vector2(size.x, size.y - 150.0), Vector2(size.x - 120.0, size.y - 60.0), Vector2(size.x - 60.0, size.y - 40.0), Vector2(size.x, size.y)])
	draw_colored_polygon(corner, Color(Spellbook.PAPER_DARK, 0.35))

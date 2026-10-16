class_name GestureTemplates

## Reference shapes the recognizer matches against, plus the simpler shapes the spellbook draws.

## Recognizer template name -> gesture name. Several templates can share a gesture.
const ALIASES := {"line": "flick", "zig_tall": "zigzag"}


## Templates for the $1 recognizer.
static func recognizer_templates() -> Dictionary:
	return {
		"line": PackedVector2Array([Vector2(0, 0), Vector2(100, 0)]),
		"circle_cw": _ring(false),
		"circle_ccw": _ring(true),
		"zig_tall": PackedVector2Array([Vector2(0, 0), Vector2(-40, 40), Vector2(0, 80), Vector2(-40, 120)]),
		"stonefall": _circle_and_drop(),
		"cross": PackedVector2Array([Vector2(0, 0), Vector2(100, 100), Vector2(50, 50), Vector2(100, 0), Vector2(0, 100)]),
	}


## Points the spellbook draws for each gesture, so the picture shows the direction that matters.
static func preview_points(gesture: String) -> PackedVector2Array:
	match gesture:
		"flick":
			return PackedVector2Array([Vector2(0, 0), Vector2(100, 0)])
		"flick_toward":
			return PackedVector2Array([Vector2(100, 0), Vector2(0, 0)])
		"wall":
			return PackedVector2Array([Vector2(0, -50), Vector2(0, 50)])
		"circle_cw":
			return _ring(false)
		"circle_ccw":
			return _ring(true)
		"zigzag":
			return recognizer_templates()["zig_tall"]
		"stonefall":
			return recognizer_templates()["stonefall"]
		"icicles":
			return PackedVector2Array([Vector2(-40, -40), Vector2(0, 30), Vector2(40, -40)])
		"snowfall":
			return _star_and_line()
		"circle_push":
			return _circle_and_line(-90.0)  # the line runs out and away from the circle
		"stone_wall":
			return PackedVector2Array([Vector2(0, 100), Vector2(100, 20)])
		"cross":
			return recognizer_templates()["cross"]
	return PackedVector2Array()


## A five-pointed star drawn in one swift stroke, crossing itself, then a level line out of its top point.
static func _star_and_line() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in [0, 2, 4, 1, 3, 0]:
		pts.append(Vector2.from_angle(-PI / 2.0 + TAU * k / 5.0) * 45.0)
	pts.append(Vector2(100, -45))
	return pts


static func _ring(ccw: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var direction := -1.0 if ccw else 1.0
	for i in range(33):
		pts.append(Vector2.from_angle(direction * TAU * i / 32.0) * 50.0)
	return pts


## A circle drawn in one stroke, then a line leaving its top and ending at line_end (y, in the same space).
static func _circle_and_line(line_end: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(33):
		pts.append(Vector2.from_angle(-PI / 2.0 + TAU * i / 32.0) * 40.0)
	for i in range(1, 9):
		pts.append(Vector2(0, -40.0 + (line_end + 40.0) * i / 8.0))
	return pts


## A circle drawn in one stroke, with a line running down from its top: the rock, then the drop.
static func _circle_and_drop() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(33):
		pts.append(Vector2.from_angle(-PI / 2.0 + TAU * i / 32.0) * 40.0)
	for i in range(1, 13):
		pts.append(Vector2(0, -40.0 + i * 15.0))
	return pts

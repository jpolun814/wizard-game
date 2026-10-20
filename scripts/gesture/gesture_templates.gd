class_name GestureTemplates

## Reference shapes the recognizer matches against, plus the simpler shapes the spellbook draws.
## The dark wizard draws its spells from the same preview shapes, so every shape here must be one the caster
## recognises (tests/test_gestures.gd checks that).

## Recognizer template name -> gesture name. Several templates can share a gesture. A circle counts the same
## whichever way round it is drawn.
const ALIASES := {"line": "flick", "zig_tall": "zigzag", "funnel": "tornado", "mountain": "volcano",
	"circle_cw": "circle", "circle_ccw": "circle"}


## Templates for the $1 recognizer.
static func recognizer_templates() -> Dictionary:
	return {
		"line": PackedVector2Array([Vector2(0, 0), Vector2(100, 0)]),
		"circle_cw": _ring(false),
		"circle_ccw": _ring(true),
		"zig_tall": PackedVector2Array([Vector2(0, 0), Vector2(-40, 40), Vector2(0, 80), Vector2(-40, 120)]),
		"stonefall": _circle_and_drop(),
		"cross": PackedVector2Array([Vector2(0, 0), Vector2(100, 100), Vector2(50, 50), Vector2(100, 0), Vector2(0, 100)]),
		"funnel": PackedVector2Array([Vector2(-50, -40), Vector2(50, -40), Vector2(0, 50), Vector2(-50, -40)]),
		"mountain": PackedVector2Array([Vector2(-50, 40), Vector2(0, -50), Vector2(50, 40), Vector2(-50, 40)]),
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
		"circle", "circle_cw":
			return _ring(false)
		"circle_ccw":
			return _ring(true)
		"zigzag":
			return recognizer_templates()["zig_tall"]
		"stonefall":
			return recognizer_templates()["stonefall"]
		"tornado":
			var zigzag := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0
				var half := lerpf(50.0, 12.0, t)
				zigzag.append(Vector2(half if i % 2 == 0 else -half, -50.0 + t * 100.0))
			return zigzag
		"volcano":
			return recognizer_templates()["mountain"]
		"icicles":
			return PackedVector2Array([Vector2(-25, -50), Vector2(0, 30), Vector2(25, -50)])
		"snowfall":
			return _star_and_line()
		"circle_push":
			return _circle_and_line(-140.0)  # the line runs out and away from the circle
		"stone_wall":
			return PackedVector2Array([Vector2(0, 100), Vector2(100, 20)])
		"cross":
			return recognizer_templates()["cross"]
		"spiral":
			return _spiral(60.0, 2.0)
		"cloud":
			return _cloud(4, 160.0, 26.0)
		"pit":
			return _pit(90.0, 60.0)
		"cone":
			return _cone(80.0, 0.5)
	return PackedVector2Array()


## Where the ground sits in a gesture's picture (its y), for spells that must be drawn starting on something solid,
## or NAN for spells drawn anywhere. The spellbook draws the ground there.
static func preview_ground(gesture: String) -> float:
	match gesture:
		"stone_wall":
			return 100.0
	return NAN


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


## A box drawn from its top-left corner, clockwise, back to where it started: the block of ice.
static func _square(side: float) -> PackedVector2Array:
	var h := side * 0.5
	var corners := [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h), Vector2(-h, -h)]
	var pts := PackedVector2Array()
	for i in 4:
		for k in 8:
			pts.append(corners[i].lerp(corners[i + 1], k / 8.0))
	pts.append(corners[4])
	return pts


## A spiral that starts wide and winds in to its middle: things being drawn into the well.
static func _spiral(outer: float, turns: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := int(turns * 32.0)
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(Vector2.from_angle(-PI * 0.5 + t * turns * TAU) * outer * (1.0 - t * 0.9))
	return pts


## The top of a cloud, drawn left to right: a row of round bumps.
static func _cloud(bumps: int, width: float, height: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := bumps * 10
	for i in steps + 1:
		var t := float(i) / steps
		var phase := fmod(t * bumps, 1.0)
		pts.append(Vector2(-width * 0.5 + width * t, -sin(phase * PI) * height))
	return pts


## A crack along the ground: a jagged line running sideways with small sharp zigs.
static func _cone(length: float, half_angle: float) -> PackedVector2Array:
	var top := Vector2.from_angle(-half_angle) * length
	var bottom := Vector2.from_angle(half_angle) * length
	return PackedVector2Array([top, Vector2.ZERO, bottom])


## A U: down one side, round the bottom and up the other. The pit the ground falls into.
static func _pit(width: float, depth: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 25:
		var a := PI - PI * i / 24.0
		pts.append(Vector2(cos(a) * width * 0.5, sin(a) * depth))
	return pts

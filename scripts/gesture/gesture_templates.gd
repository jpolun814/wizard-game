class_name GestureTemplates

## Reference shapes the recognizer matches against, plus the simpler shapes the spellbook draws.
## The dark wizard draws its spells from the same preview shapes, so every shape here must be one the caster
## recognises (tests/test_gestures.gd checks that).

## Recognizer template name -> gesture name. Several templates can share a gesture. A circle counts the same
## whichever way round it is drawn.
const ALIASES := {"line": "flick", "zig_tall": "zigzag", "mountain": "volcano",
	"circle_cw": "circle", "circle_ccw": "circle", "flame_cw": "flare", "flame_ccw": "flare",
	"eight_top_cw": "eight", "eight_top_ccw": "eight", "eight_mid_cw": "eight", "eight_mid_ccw": "eight",
	"geyser_peak": "geyser", "geyser_peak_r": "geyser", "vine_cw": "vine", "vine_ccw": "vine",
	"star_0": "pentagram", "star_1": "pentagram", "star_2": "pentagram", "star_3": "pentagram", "star_4": "pentagram",
	"star_0r": "pentagram", "star_1r": "pentagram", "star_2r": "pentagram", "star_3r": "pentagram", "star_4r": "pentagram",
	"crescent_cw": "crescent", "crescent_ccw": "crescent"}


## Templates for the $1 recognizer.
static func recognizer_templates() -> Dictionary:
	return {
		"line": PackedVector2Array([Vector2(0, 0), Vector2(100, 0)]),
		"earthquake": _three_peaks(),
		"circle_cw": _ring(false),
		"circle_ccw": _ring(true),
		"zig_tall": PackedVector2Array([Vector2(0, 0), Vector2(-40, 40), Vector2(0, 80), Vector2(-40, 120)]),
		"stonefall": _circle_and_drop(),
		"cross": PackedVector2Array([Vector2(0, 0), Vector2(100, 100), Vector2(50, 50), Vector2(100, 0), Vector2(0, 100)]),
		"mountain": PackedVector2Array([Vector2(-50, 40), Vector2(0, -50), Vector2(50, 40), Vector2(0, 40), Vector2(0, -50)]),  # a peak, its base, and the vent up through its middle
		"flame_cw": _flame(false),
		"flame_ccw": _flame(true),
		"eight_top_cw": _eight(0.0, false),
		"eight_top_ccw": _eight(0.0, true),
		"eight_mid_cw": _eight(PI * 0.5, false),
		"eight_mid_ccw": _eight(PI * 0.5, true),
		"geyser_peak": PackedVector2Array([Vector2(-50, 40), Vector2(0, -50), Vector2(50, 40), Vector2(0, 40), Vector2(0, -50)]),  # a volcano's shape, drawn with the water button
		"geyser_peak_r": PackedVector2Array([Vector2(50, 40), Vector2(0, -50), Vector2(-50, 40), Vector2(0, 40), Vector2(0, -50)]),
		"vine_cw": _leaf_and_stem(false),
		"vine_ccw": _leaf_and_stem(true),
		"star_0": _pentagram(0, false),
		"star_1": _pentagram(1, false),
		"star_2": _pentagram(2, false),
		"star_3": _pentagram(3, false),
		"star_4": _pentagram(4, false),
		"star_0r": _pentagram(0, true),
		"star_1r": _pentagram(1, true),
		"star_2r": _pentagram(2, true),
		"star_3r": _pentagram(3, true),
		"star_4r": _pentagram(4, true),
		"crescent_cw": _crescent(false),
		"crescent_ccw": _crescent(true),
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
			return _coil_down()
		"volcano":
			return recognizer_templates()["mountain"]
		"icicles":
			return PackedVector2Array([Vector2(-40, -30), Vector2(-20, 40), Vector2(0, -30), Vector2(20, 40), Vector2(40, -30)])
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
		"earthquake":
			return _three_peaks()
		"pit":
			return _pit(90.0, 60.0)
		"cone":
			return _cone(80.0, 0.5)
		"smoke":
			return _wavy_rise()
		"flare":
			return _flame(false)
		"wave":
			return _sine(180.0, 12.0, 3.0)
		"geyser":
			return recognizer_templates()["geyser_peak"]
		"vine":
			return _leaf_and_stem(false)
		"tsunami":
			return _big_wave()
		"bramble":
			return _sawtooth(5, 40.0, 22.0)
		"jaws":
			return PackedVector2Array([Vector2(-30, -40), Vector2(-15, 40), Vector2(0, -5), Vector2(15, 40), Vector2(30, -40)])
		"pads":
			return _loop_chain(3)
		"tree":
			return _lollipop()
		"eight":
			return _eight(0.0, false)
		"crescent":
			return _crescent(false)
		"pentagram":
			return _pentagram(0, false)
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


## Three mountain peaks along the ground: up and down, three times.
static func _three_peaks() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-60, 0), Vector2(-45, -30), Vector2(-30, 0), Vector2(-15, -30), Vector2(0, 0), Vector2(15, -30), Vector2(30, 0), Vector2(45, -30), Vector2(60, 0)])


## A teardrop with its point at the top: a flame. Drawn from the tip, down one side and round.
static func _flame(ccw: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 33:
		var t := TAU * i / 32.0
		var x := 42.0 * sin(t) * pow(sin(t * 0.5), 1.0)
		pts.append(Vector2(-x if ccw else x, -55.0 * cos(t)))
	return pts


## A figure of eight, standing up. start 0 begins at the top of the upper loop; PI/2 begins at the crossing.
static func _eight(start: float, ccw: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 49:
		var u := start + TAU * i / 48.0
		var x := 35.0 * sin(2.0 * u)
		pts.append(Vector2(-x if ccw else x, -50.0 * cos(u)))
	return pts


## A five-pointed star drawn in one stroke without lifting: from a point, straight to the point two along, and so on
## round until it closes. start picks which point it begins at, ccw the way round.
static func _pentagram(start: int, ccw: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for step in 6:
		var k := (start + step * (3 if ccw else 2)) % 5
		pts.append(Vector2.from_angle(-PI / 2.0 + TAU * k / 5.0) * 50.0)
	return pts


## A crescent: an open curve like a C, about two thirds of a circle.
static func _crescent(ccw: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 25:
		var a := deg_to_rad(-70.0 - 220.0 * i / 24.0)
		var p := Vector2(cos(a), sin(a)) * 50.0
		pts.append(Vector2(p.x, -p.y) if ccw else p)
	return pts


## A wavy line going up.
static func _wavy_rise() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 61:
		var t := float(i) / 60.0
		pts.append(Vector2(18.0 * sin(t * TAU * 3.0), 55.0 - 110.0 * t))
	return pts


## A sine wave drawn left to right.
static func _sine(width: float, height: float, waves: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 61:
		var t := float(i) / 60.0
		pts.append(Vector2(-width * 0.5 + width * t, height * sin(t * TAU * waves)))
	return pts


## A leaf and the vine growing from it: an almond standing on its point, drawn from the bottom point up one side, over the
## top and back down the other, then a straight line up from that point through the leaf and on above it.
static func _leaf_and_stem(ccw: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var side := -1.0 if ccw else 1.0
	for i in 21:
		var t := float(i) / 20.0
		pts.append(Vector2(side * 20.0 * sin(PI * t), 50.0 - 100.0 * t))
	for i in range(1, 21):
		var t := 1.0 - float(i) / 20.0
		pts.append(Vector2(-side * 20.0 * sin(PI * t), 50.0 - 100.0 * t))
	for i in range(1, 17):
		pts.append(Vector2(0.0, 50.0 - 150.0 * i / 16.0))
	return pts


## A big wave: a long, gentle rise that steepens toward a crest, then the crest curling over forward and down.
static func _big_wave() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 25:
		var t := float(i) / 24.0
		pts.append(Vector2(-90.0 + 150.0 * t, 50.0 - 90.0 * (t * t * (3.0 - 2.0 * t))))  # flat at both ends, steepest between
	for i in range(1, 25):
		var a := deg_to_rad(-90.0 + 200.0 * i / 24.0)
		pts.append(Vector2(60.0, -15.0) + Vector2(cos(a), sin(a)) * 25.0)
	return pts


## A coil going down, like a drill bit or a dust devil seen from the side.
static func _coil_down() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 97:
		var theta := TAU * 3.0 * i / 96.0
		pts.append(Vector2(22.0 * sin(theta), 28.0 * theta / TAU - 10.0 * cos(theta)))
	return pts


## A low row of sharp thorns: a sawtooth, drawn left to right.
static func _sawtooth(teeth: int, tooth_width: float, height: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var total := teeth * tooth_width
	for i in teeth * 2 + 1:
		pts.append(Vector2(-total * 0.5 + i * tooth_width * 0.5, 0.0 if i % 2 == 0 else -height))
	return pts


## A chain of low loops, drawn left to right.
static func _loop_chain(loops: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := loops * 24
	for i in steps + 1:
		var theta := TAU * loops * i / steps
		pts.append(Vector2(8.0 * theta - 18.0 * sin(theta) - 75.0, -14.0 * cos(theta)))
	return pts


## A tree: a trunk drawn up, then a round crown drawn round the top of it.
static func _lollipop() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 9:
		pts.append(Vector2(0, 70.0 - 70.0 * i / 8.0))  # the trunk, up from y = 70 to y = 0
	for i in range(1, 49):
		var a := PI * 0.5 + TAU * i / 48.0
		pts.append(Vector2(0, -35.0) + Vector2(cos(a), sin(a)) * 35.0)
	return pts


## The box a stroke fits in.
static func bounds(points: PackedVector2Array) -> Rect2:
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	return box

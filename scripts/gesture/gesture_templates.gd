class_name GestureTemplates

## Reference shapes the recognizer matches against, plus the simpler shapes the spellbook draws.
## The AI wizards draw their spells from the same preview shapes, so every shape here must be one the caster
## recognises (tests/checks/test_gestures.gd checks that).

## Recognizer template name -> gesture name. Several templates can share a gesture. A circle counts the same
## whichever way round it is drawn.
const ALIASES := {"line": "flick", "zig_tall": "zigzag",
	"circle_cw": "circle", "circle_ccw": "circle", "flame_cw": "flare", "flame_ccw": "flare",
	"eight_top_cw": "eight", "eight_top_ccw": "eight", "eight_mid_cw": "eight", "eight_mid_ccw": "eight",
	"vine_cw": "vine", "vine_ccw": "vine", "vine_cw_r": "vine", "vine_ccw_r": "vine",
	"star_0": "pentagram", "star_1": "pentagram", "star_2": "pentagram", "star_3": "pentagram", "star_4": "pentagram",
	"star_0r": "pentagram", "star_1r": "pentagram", "star_2r": "pentagram", "star_3r": "pentagram", "star_4r": "pentagram",
	"crescent_cw": "crescent", "crescent_ccw": "crescent", "double_ring_a": "double_ring", "double_ring_b": "double_ring",
	"eclipse_a": "eclipse", "eclipse_b": "eclipse", "eclipse_c": "eclipse", "eclipse_d": "eclipse",
	"lungs_a": "lungs", "lungs_b": "lungs", "lungs_c": "lungs", "lungs_d": "lungs", "lungs_e": "lungs", "lungs_f": "lungs",
	"silence_cw": "silence", "silence_ccw": "silence", "question_r": "question", "earthquake_r": "earthquake", "arrow_r2": "arrow", "arrow_l": "arrow", "arrow_l2": "arrow"}


## Templates for the $1 recognizer.
static func recognizer_templates() -> Dictionary:
	return {
		"line": PackedVector2Array([Vector2(0, 0), Vector2(100, 0)]),
		"earthquake": _double_arrow(false),
		"earthquake_r": _double_arrow(true),
		"circle_cw": _ring(false),
		"circle_ccw": _ring(true),
		"zig_tall": PackedVector2Array([Vector2(0, 0), Vector2(-40, 40), Vector2(0, 80), Vector2(-40, 120)]),
		"stonefall": _circle_and_drop(),
		"cross": PackedVector2Array([Vector2(0, 0), Vector2(100, 100), Vector2(50, 50), Vector2(100, 0), Vector2(0, 100)]),
		"flame_cw": _flame(false),
		"flame_ccw": _flame(true),
		"eight_top_cw": _eight(0.0, false),
		"eight_top_ccw": _eight(0.0, true),
		"eight_mid_cw": _eight(PI * 0.5, false),
		"eight_mid_ccw": _eight(PI * 0.5, true),
		"geyser": _arrow_up(),  # the jet going up, drawn with the water button
		"vine_cw": _leaf_and_stem(false),
		"vine_ccw": _leaf_and_stem(true),
		"vine_cw_r": _leaf_and_stem(false, true),
		"vine_ccw_r": _leaf_and_stem(true, true),
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
		"double_ring_a": _double_ring(false),
		"double_ring_b": _double_ring(true),
		"eclipse_a": _eclipse(false, false),
		"eclipse_b": _eclipse(true, false),
		"eclipse_c": _eclipse(false, true),
		"eclipse_d": _eclipse(true, true),
		"crescent_ccw": _crescent(true),
		"updraft": _arrow_up(),
		"rocket": _arrow_up(),  # the flame going up, drawn with the fire button
		"question": _question(false),
		"question_r": _question(true),
		"arrow": _arrow_side(false, false),
		"arrow_r2": _arrow_side(false, true),
		"arrow_l": _arrow_side(true, false),
		"arrow_l2": _arrow_side(true, true),
		"silence_cw": _slashed_ring(false),
		"silence_ccw": _slashed_ring(true),
		"lungs_a": _lungs(false, 0.0),
		"lungs_b": _lungs(true, 0.0),
		"lungs_c": _lungs(false, PI * 0.25),
		"lungs_d": _lungs(true, PI * 0.25),
		"lungs_e": _lungs(false, -PI * 0.25),
		"lungs_f": _lungs(true, -PI * 0.25),
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
		"stalagmite":
			return PackedVector2Array([Vector2(-40, 30), Vector2(-20, -40), Vector2(0, 30), Vector2(20, -40), Vector2(40, 30)])
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
			return _double_arrow(false)
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
			return _arrow_up()
		"vine":
			return _leaf_and_stem(false)
		"swell":
			return _swell()
		"bramble":
			return _sawtooth(3, 40.0, 22.0)
		"jaws":
			return PackedVector2Array([Vector2(-30, -40), Vector2(-15, 40), Vector2(0, -5), Vector2(15, 40), Vector2(30, -40)])
		"pads":
			return _circle_and_level_line()
		"tree":
			return _lollipop()
		"eight":
			return _eight(0.0, false)
		"crescent":
			return _crescent(false)
		"double_ring":
			return _double_ring(false)
		"eclipse":
			return _eclipse(false, false)
		"flame_wall":
			return _up_and_out()
		"pentagram":
			return _pentagram(0, false)
		"lungs":
			return _lungs(false, 0.0)
		"updraft":
			return _arrow_up()
		"question":
			return _question(false)
		"arrow":
			return _arrow_side(false, false)
		"silence":
			return _slashed_ring(false)
		"hailstorm":
			return _ring_and_hail()
		"feather":
			return _feather_stroke()
		"sphere":
			return _ball_and_roll()
		"latin_cross":
			return _cross_stroke()
		"thunderclap":
			return _cloud_and_bolt()
		"rocket":
			return _arrow_up()
		"portrait":
			return _portrait_stroke()
	return PackedVector2Array()


## Where the ground sits in a gesture's picture (its y), for spells that must be drawn starting on something solid,
## or NAN for spells drawn anywhere. The spellbook draws the ground there.
static func preview_ground(gesture: String) -> float:
	match gesture:
		"stone_wall":
			return 100.0
	return NAN


## A ring (the cloud), then a line out from its top (as far as the cloud runs), then a line down (the hail): a Hailstorm.
static func _ring_and_hail() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(33):
		pts.append(Vector2.from_angle(-PI / 2.0 + TAU * i / 32.0) * 28.0)
	for i in range(1, 9):
		pts.append(Vector2(90.0 * i / 8.0, -28.0))
	for i in range(1, 9):
		pts.append(Vector2(90.0, -28.0 + 66.0 * i / 8.0))
	return pts


## A cloud (a ring, begun at its bottom) and a bolt of lightning down out of it, in one stroke: a zigzag that bends across its way twice.
static func _cloud_and_bolt() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(33):
		pts.append(Vector2.from_angle(PI / 2.0 + TAU * i / 32.0) * 32.0 + Vector2(0.0, -32.0))
	for corner in [Vector2(-24, 24), Vector2(16, 34), Vector2(-14, 62), Vector2(8, 84)]:
		var from: Vector2 = pts[pts.size() - 1]
		for i in range(1, 7):
			pts.append(from.lerp(corner, float(i) / 6.0))
	return pts


## A feather drifting down, in one stroke: three sweeps across (right, back left, right again), each bent down in the middle and ending lower than it began.
static func _feather_stroke() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 3:
		var from_x := 0.0 if k % 2 == 0 else 100.0
		var to_x := 100.0 - from_x
		for i in range(1 if k > 0 else 0, 17):
			var t := float(i) / 16.0
			pts.append(Vector2(lerpf(from_x, to_x, t), 25.0 * k + 25.0 * t + 20.0 * sin(PI * t)))
	return pts


## A ring drawn from its bottom, then a level line out along the ground from there: a ball set rolling.
static func _ball_and_roll() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(33):
		pts.append(Vector2.from_angle(PI / 2.0 + TAU * i / 32.0) * 30.0)
	for i in range(1, 9):
		pts.append(Vector2(100.0 * i / 8.0, 30.0))
	return pts


## A tall box drawn in one go: down the left side, along the bottom, up the right and back across the top.
static func _portrait_stroke() -> PackedVector2Array:
	var corners := [Vector2(0, 0), Vector2(0, 100), Vector2(52, 100), Vector2(52, 0), Vector2(-2, 0)]
	var pts := PackedVector2Array()
	for k in corners.size() - 1:
		for i in range(8):
			pts.append(corners[k].lerp(corners[k + 1], float(i) / 8.0))
	pts.append(corners[corners.size() - 1])
	return pts


## A cross: down the stem from the top, back up to the bar, then across it one way and back the other.
static func _cross_stroke() -> PackedVector2Array:
	var corners := [Vector2(0, -50), Vector2(0, 50), Vector2(0, -22), Vector2(-30, -22), Vector2(30, -22)]
	var pts := PackedVector2Array()
	for k in corners.size() - 1:
		for i in range(8):
			pts.append(corners[k].lerp(corners[k + 1], float(i) / 8.0))
	pts.append(corners[corners.size() - 1])
	return pts


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


## An arrow with a head at both ends, in one stroke: the head at the left, the shaft across, then the head at the right. reversed starts at the
## right-hand head. The ground pulled both ways.
static func _double_arrow(reversed: bool) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(-30, -22), Vector2(-60, 0), Vector2(-30, 22), Vector2(-60, 0), Vector2(60, 0), Vector2(30, -22), Vector2(60, 0), Vector2(30, 22)])
	if reversed:
		pts = PackedVector2Array([Vector2(30, -22), Vector2(60, 0), Vector2(30, 22), Vector2(60, 0), Vector2(-60, 0), Vector2(-30, -22), Vector2(-60, 0), Vector2(-30, 22)])
	return pts


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


## An arrow pointing up, in one stroke: the shaft from the bottom to the tip, then down one side of the head and back, and down the other.
static func _arrow_up() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 60), Vector2(0, -60), Vector2(-30, -26), Vector2(0, -60), Vector2(30, -26)])


## The top of a question mark, in one stroke: up and over in a hook, then down toward the middle. mirror is the same hook the other way round.
static func _question(mirror: bool) -> PackedVector2Array:
	var side := -1.0 if mirror else 1.0
	var pts := PackedVector2Array()
	for i in 13:
		var angle := PI + PI * 1.25 * i / 12.0
		pts.append(Vector2(cos(angle) * 30.0 * side, -20.0 + sin(angle) * 30.0))
	for tail in [Vector2(9, 14), Vector2(0, 26), Vector2(0, 46)]:
		pts.append(Vector2(tail.x * side, tail.y))
	return pts


## An arrow pointing sideways, in one stroke: the shaft to the tip, then back along one side of the head and back, and along the other.
static func _arrow_side(left: bool, up_first: bool) -> PackedVector2Array:
	var d := -1.0 if left else 1.0
	var side := -32.0 if up_first else 32.0
	return PackedVector2Array([Vector2(-60.0 * d, 0), Vector2(60.0 * d, 0), Vector2(20.0 * d, side), Vector2(60.0 * d, 0), Vector2(20.0 * d, -side)])


## A ring with a slash through it, the sign for "do not enter": round once, then straight across the middle and out the far side.
static func _slashed_ring(ccw: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var direction := -1.0 if ccw else 1.0
	var start := -PI * 0.75
	for i in 33:
		pts.append(Vector2.from_angle(start + direction * TAU * i / 32.0) * 45.0)
	var through := Vector2.from_angle(start)
	for i in range(1, 9):
		pts.append(through * 45.0 - through * 100.0 * i / 8.0)
	return pts


## Two lungs: an infinity sign lying on its side, drawn in one stroke back to where it began. mirror starts on the left loop instead of the right,
## and start is how far round the sign it begins (0 is the outer edge of a loop; the crossing in the middle makes a poor place to start, since
## the recognizer turns a stroke by the line from its start to its middle). Starting downward instead of upward, or going the other way
## round, is this shape turned half way round.
static func _lungs(mirror: bool, start: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 60
	for i in steps + 1:
		var t := start + TAU * i / steps
		var x := 45.0 * cos(t)
		var y := 56.0 * sin(t) * cos(t)
		pts.append(Vector2(-x if mirror else x, y))
	return pts


## A five-pointed star drawn in one stroke without lifting: from a point, straight to the point two along, and so on
## round until it closes. start picks which point it begins at, ccw the way round.
static func _pentagram(start: int, ccw: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for step in 6:
		var k := (start + step * (3 if ccw else 2)) % 5
		pts.append(Vector2.from_angle(-PI / 2.0 + TAU * k / 5.0) * 50.0)
	return pts


## A line up and then a line out along the top, in one stroke: the height of the flames, then the width of the wall.
static func _up_and_out() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(9):
		pts.append(Vector2(0.0, 40.0 - 80.0 * i / 8.0))
	for i in range(1, 13):
		pts.append(Vector2(120.0 * i / 12.0, -40.0))
	return pts


## A star and the shell it blows off, in one stroke: a ring, then straight on into a wider ring round it, so the line spirals outward for two turns.
## ccw turns both loops the other way.
static func _double_ring(ccw: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var direction := -1.0 if ccw else 1.0
	for i in range(33):
		pts.append(Vector2.from_angle(direction * TAU * i / 32.0) * 26.0)
	for i in range(1, 41):
		var reach := lerpf(26.0, 58.0, minf(i / 10.0, 1.0))  # the line opens out over the first quarter of the second turn, then goes round
		pts.append(Vector2.from_angle(direction * TAU * i / 40.0) * reach)
	return pts


## The moon over the sun, in one stroke: the outline of a crescent, drawn from its top tip round the outside to the bottom tip and back up the inside.
## flipped begins at the bottom tip; mirrored bows to the right instead of the left.
static func _eclipse(flipped: bool, mirrored: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(21):
		var a := deg_to_rad(-90.0 - 180.0 * i / 20.0)
		pts.append(Vector2(cos(a), sin(a)) * 50.0)
	var center := Vector2(52.5, 0.0)  # the inner edge is a wider circle through the same two tips, so the crescent has points
	var from := (Vector2(0.0, 50.0) - center).angle()
	var to := (Vector2(0.0, -50.0) - center).angle() + TAU
	for i in range(1, 21):
		pts.append(center + Vector2.from_angle(lerpf(from, to, i / 20.0)) * 72.5)
	for k in pts.size():
		pts[k] = Vector2(-pts[k].x if mirrored else pts[k].x, -pts[k].y if flipped else pts[k].y)
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


## A leaf and the vine growing from it: an almond lying on its side, drawn from its left point along the top to its right point and back along the
## bottom, then a straight line up from the left point. ccw draws the bottom first; mirrored begins at the right point instead.
static func _leaf_and_stem(ccw: bool, mirrored := false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var side := -1.0 if ccw else 1.0
	for i in 21:
		var t := float(i) / 20.0
		pts.append(Vector2(-50.0 + 100.0 * t, -side * 20.0 * sin(PI * t)))
	for i in range(1, 21):
		var t := 1.0 - float(i) / 20.0
		pts.append(Vector2(-50.0 + 100.0 * t, side * 20.0 * sin(PI * t)))
	for i in range(1, 17):
		pts.append(Vector2(-50.0, -150.0 * i / 16.0))
	if mirrored:
		for k in pts.size():
			pts[k] = Vector2(-pts[k].x, pts[k].y)
	return pts


## A big wave: a long, gentle rise that steepens toward a crest, then the crest curling over forward and down.
static func _swell() -> PackedVector2Array:
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
static func sawtooth(teeth: int, tooth_width: float, height: float) -> PackedVector2Array:
	return _sawtooth(teeth, tooth_width, height)


static func _sawtooth(teeth: int, tooth_width: float, height: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var total := teeth * tooth_width
	for i in teeth * 2 + 1:
		pts.append(Vector2(-total * 0.5 + i * tooth_width * 0.5, 0.0 if i % 2 == 0 else -height))
	return pts


## A pad drawn as a ring, then a level line out of its top across where the pads are to grow.
static func _circle_and_level_line() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(33):
		pts.append(Vector2.from_angle(-PI / 2.0 + TAU * i / 32.0) * 36.0)
	for i in range(1, 11):
		pts.append(Vector2(14.0 * i, -36.0))
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

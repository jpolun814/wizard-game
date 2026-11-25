class_name StrokeReader
extends RefCounted

## Reads a stroke that has been drawn: the recognizer guesses first, then the shapes it cannot tell apart reliably are read from the stroke itself, and what is left
## is settled (a straight stroke is a flick, a wall or a pull by the button; a cross or a flame that is not one is no spell). Nothing here casts: the caster does
## that from the reading. The caster's settings are copied in before each read.

var recognizer: UnistrokeRecognizer
var tolerance := 0.70  # minimum $1 score to count as a cast
const UPRIGHT_DEG := 20.0
var wall_tolerance_deg := UPRIGHT_DEG  # straight strokes this close to vertical are walls
const SPRING_RISE := 0.3  # how far (as a share of its height) the end of a spring must be from where it began, for its sharp turns not to be taken for icicles: a single V is a fair match for it too, and ends where it began


func _init(with_recognizer: UnistrokeRecognizer) -> void:
	recognizer = with_recognizer


## The recognizer templates that mean something on a button. A straight line is wanted wherever any spell is drawn as one (a flick, a wall, a stone wall).
func templates_for(options: Dictionary) -> Array:
	var names := []
	for template_name in recognizer.templates:
		var gesture: String = GestureTemplates.ALIASES.get(template_name, template_name)
		if options.has(gesture) or (gesture == "flick" and (options.has("wall") or options.has("stone_wall") or options.has("flick_toward"))):
			names.append(template_name)
	return names


## The whole read of a stroke (points relative to where it began) drawn with the buttons whose spells are `options`.
func read(relative: PackedVector2Array, origin: Vector2, options: Dictionary) -> StrokeReading:
	var result := recognizer.recognize(relative, templates_for(options))
	var guess: String = GestureTemplates.ALIASES.get(result.name, result.name)
	var reading := _read_shapes(relative, origin, options, StrokeReading.new(guess, result.score))
	return reading


## The shapes that are read from the stroke itself, since the recognizer cannot tell them apart reliably. Each detector that finds its shape claims the reading
## (certain, with what the arena needs). The detectors are all asked first, and the claims are made in the order below, which is the order in which they rule each
## other out.
func _read_shapes(relative: PackedVector2Array, origin: Vector2, options: Dictionary, reading: StrokeReading) -> StrokeReading:
	var seen := _detect(relative, options, reading)
	var to_world := func(points: PackedVector2Array) -> PackedVector2Array: return StrokeMeasure.to_world(points, origin)
	if seen["portrait"]:
		return reading.claim("portrait")  # a tall box with four sharp corners: a picture frame, a doorway
	if seen["thunder"]:
		return reading.claim("thunderclap")  # a cloud, and a bolt of lightning down out of it
	if not seen["flame_wall"].is_empty():
		return reading.claim("flame_wall", {"line": to_world.call(seen["flame_wall"])})  # a line across and a line up from its end: a wall of flame as wide as the first line
	if reading.latin:
		return reading.claim("latin_cross")  # an upright stem with a bar across it, nearer the top: read before the recognizer's guess
	if not seen["hail"].is_empty():  # a ring, a line out of it and a line down: a Hailstorm, the cloud running from the ring to the bend
		return reading.claim("hailstorm", {"line": to_world.call(PackedVector2Array([seen["hail"]["from"], seen["hail"]["to"]]))})
	if not seen["feather"].is_empty():
		return reading.claim("feather")
	if not seen["spiral"].is_empty():  # a spiral wound inward is a Black Hole, centerd where it ends up
		return reading.claim("spiral", {"radius": seen["spiral"]["reach"], "center": origin + seen["spiral"]["center"]})
	if seen["slashed"]:
		return reading.claim("silence")
	if reading.ring_split >= 0:  # a closed ring with a straight line out of it is a Push (or a ball of fire): the line can point any way
		var ring := relative.slice(0, reading.ring_split)
		reading.ring_center = StrokeMeasure.centroid(ring)
		return reading.claim("sphere" if options.has("sphere") else "circle_push", {"radius": StrokeMeasure.mean_distance(ring, reading.ring_center)})
	for lined: Array in [["pads", "pads"], ["oil", "oil"], ["snowfall", "snow_line"], ["smoke", "smoke"], ["wave", "wave"]]:
		if seen[lined[1]].size() >= (2 if lined[0] == "snowfall" else 1):
			return reading.claim(lined[0], {"line": to_world.call(seen[lined[1]])})
	var stem_gesture: String = StrokeShapes.stem_gesture(seen["stem"], options) if not seen["stem"].is_empty() else ""
	if stem_gesture != "":
		return reading.claim(stem_gesture)
	if not seen["swell"].is_empty():
		return reading.claim("swell", {"aim": seen["swell"]["aim"]})
	for lined: Array in [["tornado", "coil"], ["bramble", "bramble"]]:
		if seen[lined[1]].size() > 0:
			return reading.claim(lined[0], {"line": to_world.call(seen[lined[1]])})
	if seen["jaws"].size() > 0:
		return reading.claim("jaws")
	for lined: Array in [["cloud", "cloud"], ["pit", "pit"]]:
		if seen[lined[1]].size() > 0:
			return reading.claim(lined[0], {"line": to_world.call(seen[lined[1]])})
	if not seen["cone"].is_empty() and not (options.has("icicles") and absf(sin(seen["cone"]["aim"])) > 0.8):  # a cone opening steeply up or down is an icicle's V, where there are icicles
		return reading.claim("cone", seen["cone"])
	for rows: Array in [["stalagmite", "spikes"], ["icicles", "icicles"]]:
		if not seen[rows[1]].is_empty():
			reading.claim(rows[0], {"pieces": seen[rows[1]].size()})
			for tri in seen[rows[1]]:
				reading.info["shapes"].append(to_world.call(tri))
			return reading
	return reading


## Every detector the buttons allow, asked of the stroke. Some rule others out (a star drawn in one stroke winds inward like a spiral; a closed loop is never an icicle;
## an arrow up is a Rocket Jump even when drawn a little wavy), and those are written into the questions below. Sets `reading.latin` and the ring (`ring_split`) too.
func _detect(relative: PackedVector2Array, options: Dictionary, reading: StrokeReading) -> Dictionary:
	var gesture := reading.gesture
	var score := reading.score
	var firm := score >= tolerance
	var star := gesture == "pentagram" and firm
	var slashed := options.has("silence") and StrokeShapes.is_slashed_ring(relative)
	var spiral := StrokeShapes.inward_spiral(relative) if options.has("spiral") and not star and not slashed else {}
	var feather := StrokeShapes.feather(relative) if options.has("feather") else {}
	reading.latin = options.has("latin_cross") and StrokeShapes.is_cross(relative)
	var peace := gesture == "peace" and firm  # a peace sign is a ring with lines through it, and no ring with a line out of it
	var ring_split := StrokeShapes.ring_then_line_split(relative) if (options.has("circle_push") or options.has("sphere")) and spiral.is_empty() and feather.is_empty() and not peace else -1
	if ring_split >= 0 and options.has("sphere") and not options.has("circle_push") and not StrokeMeasure.runs_level(relative.slice(ring_split)):
		ring_split = -1  # a ball of fire is pushed along the ground: the line out of the ring must run level
	if ring_split >= 0 and slashed:
		ring_split = -1  # a ring with a bar struck through it is a ring with a bar, not a ring with a line out of it
	reading.ring_split = ring_split
	var extent := StrokeMeasure.extent(relative)
	var closed := relative[0].distance_to(relative[relative.size() - 1]) < 0.3 * maxf(extent.x, extent.y)  # icicles are open V strokes: a loop is never one
	var peak := gesture == "geyser" and firm  # an arrow pointing up drawn with the water button is a Geyser, not a row of icicles
	var round_peaks := score >= tolerance - 0.12 and gesture in ["stonefall", "earthquake"] or (gesture == "stick" and firm) or (gesture == "spring" and firm and absf(relative[relative.size() - 1].y - relative[0].y) > SPRING_RISE * extent.y)  # a circle and a drop, a double arrow, a stick figure and a basin with water rising from it also have peaks in them
	var vine := gesture == "vine" and firm  # a leaf with a vine up from it starts like a tree's trunk would end, so it is not a tree
	return {
		"portrait": options.has("portrait") and StrokeShapes.is_portrait_box(relative),
		"thunder": options.has("thunderclap") and StrokeShapes.is_thunderclap(relative),
		"flame_wall": StrokeShapes.across_and_up(relative) if options.has("flame_wall") else PackedVector2Array(),
		"hail": StrokeShapes.hailstorm(relative) if options.has("hailstorm") else {},
		"feather": feather,
		"spiral": spiral,
		"slashed": slashed,
		"pads": StrokeShapes.pad_line(relative) if options.has("pads") and spiral.is_empty() else PackedVector2Array(),
		"oil": StrokeShapes.pad_line(relative) if options.has("oil") and spiral.is_empty() else PackedVector2Array(),
		"snow_line": StrokeShapes.snowfall_line(relative) if options.has("snowfall") else PackedVector2Array(),
		"smoke": StrokeShapes.rising_wave(relative) if options.has("smoke") and not (gesture == "rocket" and firm) else PackedVector2Array(),
		"wave": StrokeShapes.cloud_line(relative) if options.has("wave") else PackedVector2Array(),
		"stem": StrokeShapes.stem_and_arc(relative) if options.has("tree") and not vine else {},
		"swell": StrokeShapes.swell(relative) if options.has("swell") else {},
		"coil": StrokeShapes.coil(relative) if options.has("tornado") else PackedVector2Array(),
		"bramble": StrokeShapes.sawtooth(relative) if options.has("bramble") else PackedVector2Array(),
		"jaws": StrokeShapes.w_shape(relative) if options.has("jaws") else PackedVector2Array(),
		"cloud": StrokeShapes.cloud_line(relative) if options.has("cloud") else PackedVector2Array(),
		"pit": StrokeShapes.pit_stroke(relative) if options.has("pit") else PackedVector2Array(),
		"cone": StrokeShapes.cone(relative) if options.has("cone") else {},
		"spikes": StrokeShapes.icicle_triangles(relative, false) if options.has("stalagmite") and not closed and not round_peaks else [],
		"icicles": StrokeShapes.icicle_triangles(relative) if options.has("icicles") and not closed and not peak and not round_peaks and spiral.is_empty() else [],
	}


## What the read leaves to be settled: a straight stroke is a flick, a wall or a pull by the button, a cross or a flame that is not one is no spell, and a loop taken
## for a flame is read again without the flames. `stroke` is the stroke in the world, `anchor` where the caster's character is and `on_ground` says whether a world
## point is solid ground.
func settle(reading: StrokeReading, relative: PackedVector2Array, options: Dictionary, stroke: PackedVector2Array, anchor: Vector2, on_ground: Callable) -> void:
	# A straight stroke can mean a wall (vertical), a pull (toward you) or a plain flick, depending on the button.
	if reading.gesture == "flick":
		reading.gesture = straight_means(options, relative[relative.size() - 1] - relative[0], stroke[0], anchor, wall_tolerance_deg)
	# Spark's zigzag and Jolt's are one shape turned a quarter, which the recognizer (it ignores rotation) cannot tell apart: the way the stroke runs does. Down is a Spark, across is a Jolt.
	if (reading.gesture == "zigzag" or reading.gesture == "bolt") and options.has("zigzag") and options.has("bolt"):
		var run := relative[relative.size() - 1] - relative[0]
		reading.gesture = "bolt" if absf(run.x) > absf(run.y) else "zigzag"
	# A straight stroke that begins on the ground raises a stone wall instead of a spike.
	if reading.gesture == "flick" and options.has("stone_wall") and on_ground.is_valid() and on_ground.call(stroke[0]):
		reading.gesture = "stone_wall"
	if reading.gesture == "shield" and options.has("flare") and StrokeShapes.flame_points_up(relative):
		reading.gesture = "flare"  # a drop with its point up, warped by a hand, is as near a shield as a flame: a shield's point is at the bottom
	if reading.gesture == "latin_cross" and not reading.latin:
		reading.score = 0.0  # a stem alone, or any stroke the recognizer likes, is not a cross
	if reading.gesture == "flare" and not StrokeShapes.flame_points_up(relative):
		reading.score = 0.0  # a plain loop, or a drop, is not a flame
		if options.has("circle"):  # where a circle is also drawn, a loop the recognizer took for a flame is read again without the flames
			var rest := templates_for(options).filter(func(n: String) -> bool: return not n.begins_with("flame"))
			var again := recognizer.recognize(relative, rest)
			reading.gesture = GestureTemplates.ALIASES.get(again.name, again.name)
			reading.score = again.score


## The gesture a straight stroke is on these buttons: close to upright it is a wall, where they have one, and toward the character (it starts far and finishes near) a pull,
## where they have that. So how steeply a flick may be drawn is a thing of its buttons, not of its spell.
static func straight_means(options: Dictionary, along: Vector2, from: Vector2, anchor: Vector2, upright_deg := UPRIGHT_DEG) -> String:
	if options.has("wall") and absf(cos(along.angle())) <= sin(deg_to_rad(upright_deg)):
		return "wall"
	if options.has("flick_toward") and along.dot(anchor - from) > 0.0:
		return "flick_toward"
	return "flick"

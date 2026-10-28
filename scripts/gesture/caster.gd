class_name Caster
extends Node2D

## Casting input: hold a school mouse button, draw, release to resolve.
## Gesture origin is the cursor position when the button goes down.
## Emits cast_resolved for world effects and feedback for the HUD.

signal cast_resolved(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary)
signal feedback(text: String, color: Color)
signal misfired

@export var tolerance := 0.80          # minimum $1 score to count as a cast
@export var min_stroke_length := 20.0  # shorter strokes are ignored as clicks
@export var wall_tolerance_deg := 20.0  # straight strokes this close to vertical are walls
const MIN_POINT_SPACING := 2.0
const ICICLE_TURN := 30.0  # a stroke must zig or zag this far vertically to count as a V tip

## Where the caster's character is, so a flick drawn toward it can be told from one drawn away.
var anchor := Vector2.ZERO
var hide_trail := false  # set while the player is blinded
var ground_check := Callable()  # set by the arena: true when a point is on solid ground
var blocked_rects: Array[Rect2] = []  # screen areas (HUD modules) where a press doesn't start a cast

var recognizer := UnistrokeRecognizer.new()
var _bindings: Dictionary
var _stroke := PackedVector2Array()  # world-space points for drawing
var _origin := Vector2.ZERO
var _active_mask := 0  # every button held at any point during this stroke, as SpellData bits
var _stroke_color := Color.WHITE
var _emitter: CPUParticles2D
var _ended_ms := 0  # when the last stroke was released, so it can fade


func _ready() -> void:
	_bindings = SpellData.bindings()
	var templates := GestureTemplates.recognizer_templates()
	for template_name in templates:
		recognizer.add_template(template_name, templates[template_name])
	# Sparks that trail the cursor while a stroke is being drawn.
	_emitter = Fx.trail(Color.WHITE, 36, 0.5, 180.0)
	_emitter.scale_amount_min = 0.4
	_emitter.scale_amount_max = 1.0
	_emitter.emitting = false
	add_child(_emitter)


func _process(_delta: float) -> void:
	var held := _held_mask()
	if _active_mask == 0:
		if held != 0 and not _pointer_over_blocked():
			_begin()
			_active_mask = held
	elif held != 0:
		# Buttons pressed later in the stroke add to the school, so Left then Middle is Left + Middle.
		_active_mask |= held
		_extend()
	else:
		_end()
	_update_emitter()
	queue_redraw()


## While a stroke is being drawn, sparks follow the cursor in the school's colour.
func _update_emitter() -> void:
	var drawing := _active_mask != 0
	_emitter.emitting = drawing and not hide_trail
	if drawing:
		_emitter.global_position = get_global_mouse_position()
		_stroke_color = _school_color(_active_mask)
		_emitter.color_ramp = Fx.fade_ramp(_stroke_color)


## The colour of the school that a button combination casts; white if it casts nothing.
## True while a stroke is being drawn.
func is_drawing() -> bool:
	return _active_mask != 0


## The colour of the school whose buttons are held for the stroke being drawn.
func drawing_color() -> Color:
	return _school_color(_active_mask)


func _school_color(mask: int) -> Color:
	for school in SpellData.SCHOOL_BUTTONS:
		if SpellData.SCHOOL_BUTTONS[school] == mask:
			return SpellData.SCHOOL_COLORS[school]
	return Color.WHITE


## True when the pointer is over a HUD module, so clicking it doesn't start a cast.
func _pointer_over_blocked() -> bool:
	var pointer := get_viewport().get_mouse_position()
	for rect in blocked_rects:
		if rect.has_point(pointer):
			return true
	return false


## The mouse buttons currently held, as SpellData bits.
func _held_mask() -> int:
	var mask := 0
	if Input.is_action_pressed("school_left"):
		mask |= SpellData.LEFT
	if Input.is_action_pressed("school_right"):
		mask |= SpellData.RIGHT
	if Input.is_action_pressed("school_middle"):
		mask |= SpellData.MIDDLE
	return mask


## Pause casting while another input (the ritual box or spellbook) has focus.
func set_casting_enabled(on: bool) -> void:
	if not on:
		_active_mask = 0
	set_process(on)


func _begin() -> void:
	_origin = get_global_mouse_position()
	_stroke = PackedVector2Array([_origin])
	_stroke_color = Color.WHITE


func _extend() -> void:
	var p := get_global_mouse_position()
	if p.distance_to(_stroke[_stroke.size() - 1]) >= MIN_POINT_SPACING:
		_stroke.append(p)


func _end() -> void:
	var mask := _active_mask
	_ended_ms = Time.get_ticks_msec()
	_active_mask = 0

	var relative := PackedVector2Array()
	for p in _stroke:
		relative.append(p - _origin)

	if UnistrokeRecognizer.path_length(relative) < min_stroke_length:
		var over_flare := false
		for flare: Node2D in get_tree().get_nodes_in_group("flares"):
			over_flare = over_flare or flare.global_position.distance_to(get_global_mouse_position()) < 60.0
		if not over_flare:  # a click on a flare is only meant to snuff it
			_report("Stroke too short", Color.GRAY)
		return

	var options: Dictionary = _bindings.get(mask, {})
	var result := recognizer.recognize(relative, _templates_for(options))
	var score: float = result.score
	var gesture: String = GestureTemplates.ALIASES.get(result.name, result.name)
	# Some shapes are read from the stroke itself, since the recognizer can't tell them apart reliably. The
	# info dictionary carries what the arena needs to place each effect.
	var info := {"radius": 0.0, "pieces": 1, "shapes": [], "line": PackedVector2Array(), "rect": Rect2()}
	# A star drawn in one stroke winds inward like a spiral, so it must be ruled out first.
	var star := gesture == "pentagram" and score >= tolerance
	var spiral := _inward_spiral(relative) if options.has("spiral") and not star else {}
	var ring_split := _ring_then_line_split(relative) if options.has("circle_push") and spiral.is_empty() else -1
	var ring_centre := Vector2.ZERO
	# Icicles are open V strokes. A closed loop (a circle, a crystal) is never an icicle.
	var extent := _extent(relative)
	var closed := relative[0].distance_to(relative[relative.size() - 1]) < 0.3 * maxf(extent.x, extent.y)
	# A volcano-shaped peak drawn with the water button is a Geyser, not a row of icicles.
	var peak := gesture == "geyser" and score >= tolerance
	var icicles: Array = _icicle_triangles(relative) if options.has("icicles") and not closed and not peak else []
	var snow_line := _snowfall_line(relative) if options.has("snowfall") else PackedVector2Array()
	var cloud := _cloud_line(relative) if options.has("cloud") else PackedVector2Array()
	var pit := _pit_stroke(relative) if options.has("pit") else PackedVector2Array()
	var cone := _cone(relative) if options.has("cone") else {}
	var smoke := _rising_wave(relative) if options.has("smoke") else PackedVector2Array()
	var wave := _cloud_line(relative) if options.has("wave") else PackedVector2Array()
	# A leaf with a vine up from it starts like a tree's trunk would end, so a stroke the recognizer reads as one is not a tree.
	var vine := gesture == "vine" and score >= tolerance
	var stem := _stem_and_arc(relative) if options.has("tree") and not vine else {}
	var tsunami := _big_wave(relative) if options.has("tsunami") else {}
	var coil := _coil(relative) if options.has("tornado") else PackedVector2Array()
	var bramble := _sawtooth(relative) if options.has("bramble") else PackedVector2Array()
	var jaws := _w_shape(relative) if options.has("jaws") else PackedVector2Array()
	var pads := _loop_row(relative) if options.has("pads") else PackedVector2Array()
	if not spiral.is_empty():
		# A spiral wound inward is an Abyss, centred where it ends up.
		gesture = "spiral"
		score = 1.0
		info["radius"] = spiral["reach"]
		info["center"] = _origin + spiral["center"]
	elif ring_split >= 0:
		# A closed ring with a straight line out of it is a Push. The line can point any way.
		gesture = "circle_push"
		score = 1.0
		var ring := relative.slice(0, ring_split)
		ring_centre = _relative_centroid(ring)
		info["radius"] = _mean_distance(ring, ring_centre)
	elif snow_line.size() >= 2:
		gesture = "snowfall"
		score = 1.0
		info["line"] = _to_world(snow_line)
	elif smoke.size() > 0:
		gesture = "smoke"
		score = 1.0
		info["line"] = _to_world(smoke)
	elif wave.size() > 0:
		gesture = "wave"
		score = 1.0
		info["line"] = _to_world(wave)
	elif not stem.is_empty() and _stem_gesture(stem, options) != "":
		gesture = _stem_gesture(stem, options)
		score = 1.0
	elif not tsunami.is_empty():
		gesture = "tsunami"
		score = 1.0
		info["aim"] = tsunami["aim"]
	elif coil.size() > 0:
		gesture = "tornado"
		score = 1.0
		info["line"] = _to_world(coil)
	elif pads.size() > 0:
		gesture = "pads"
		score = 1.0
		info["line"] = _to_world(pads)
	elif bramble.size() > 0:
		gesture = "bramble"
		score = 1.0
		info["line"] = _to_world(bramble)
	elif jaws.size() > 0:
		gesture = "jaws"
		score = 1.0
	elif cloud.size() > 0:
		gesture = "cloud"
		score = 1.0
		info["line"] = _to_world(cloud)
	elif pit.size() > 0:
		gesture = "pit"
		score = 1.0
		info["line"] = _to_world(pit)
	elif not cone.is_empty():
		gesture = "cone"
		score = 1.0
		info.merge(cone)
	elif not icicles.is_empty():
		gesture = "icicles"
		score = 1.0
		info["pieces"] = icicles.size()
		for tri in icicles:
			info["shapes"].append(_to_world(tri))
	# A straight stroke can mean a wall (vertical), a pull (toward you) or a plain flick, depending on the button.
	if gesture == "flick":
		if options.has("wall") and _is_vertical(relative):
			gesture = "wall"
		elif options.has("flick_toward") and _points_toward_anchor():
			gesture = "flick_toward"

	# A straight stroke that begins on the ground raises a stone wall instead of a spike.
	if gesture == "flick" and options.has("stone_wall") and _starts_on_ground():
		gesture = "stone_wall"
	if gesture == "flare" and not _flame_points_up(relative):
		score = 0.0  # a plain loop, or a drop, is not a flame
	var entry = options.get(gesture)
	# A cast that works shows its name where it was drawn (the arena does that), so only failures are reported here.
	# Earth Fall's circle and drop are hard to draw cleanly, so it is read with a looser eye than the other shapes.
	var needed := tolerance - 0.12 if gesture == "stonefall" or gesture == "flare" else tolerance
	if score < needed:
		_report("Misfire (%d%% match). Draw steadier, or use a wand." % roundi(score * 100.0), Color("#ff7a7a"))
		misfired.emit()
	elif entry == null:
		_report("Misfire: no %s spell looks like that. Press Tab to open the spellbook." % SpellData.button_name(mask), Color("#ff7a7a"))
		misfired.emit()
	else:
		var aim := 0.0
		if entry.targeting == "directional":
			aim = (relative[relative.size() - 1] - relative[0]).angle()
		if entry.targeting == "directional":
			info["length"] = (relative[relative.size() - 1] - relative[0]).length()
		# A drawn circle sets how big the spell is, which sets its cost (Cinderburst, Push).
		if gesture.begins_with("circle") and ring_split < 0:
			info["radius"] = _mean_distance(relative, _relative_centroid(relative))
		# Directional spells leave from the stroke's start; positional ones center on the drawn shape.
		var spawn := _origin if entry.targeting == "directional" else _stroke_center()
		if ring_split >= 0:
			# A Push comes from the circle's centre and points along the line drawn out of it.
			spawn = _origin + ring_centre
			aim = (relative[relative.size() - 1] - ring_centre).angle()
		elif entry.targeting == "angled":
			# Angled spells sit on the drawn shape and point along the stroke.
			spawn = _stroke_centroid()
			aim = (relative[relative.size() - 1] - relative[0]).angle()
		elif entry.targeting == "shape":
			# Shapes are placed where they were drawn, so the arena works from info rather than one point.
			spawn = _origin
		if info.has("center"):
			spawn = info["center"]
		if info.has("aim"):
			aim = info["aim"]
		if entry.spell == "Ice Prison":
			# The circle drawn round the target is the box the ice fills: its bounds, wherever it was drawn.
			var box := GestureTemplates.bounds(relative)
			info["rect"] = Rect2(_origin + box.position, box.size)
		if entry.targeting == "shape" and info["line"].is_empty():
			info["line"] = _to_world(relative)
		info["extent"] = _extent(relative)  # how big it was drawn, for spells that grow with it
		info["accuracy"] = _accuracy(relative, gesture, score)
		cast_resolved.emit(entry.spell, entry.targeting, spawn, aim, info)



## The recognizer templates that mean something on a button. A straight line is wanted wherever any spell is drawn
## as one (a flick, a wall, a stone wall).
func _templates_for(options: Dictionary) -> Array:
	var names := []
	for template_name in recognizer.templates:
		var gesture: String = GestureTemplates.ALIASES.get(template_name, template_name)
		if options.has(gesture) or (gesture == "flick" and (options.has("wall") or options.has("stone_wall") or options.has("flick_toward"))):
			names.append(template_name)
	return names


func _is_vertical(points: PackedVector2Array) -> bool:
	var dir := points[points.size() - 1] - points[0]
	return absf(cos(dir.angle())) <= sin(deg_to_rad(wall_tolerance_deg))


## True when the stroke moves toward the character: start far, finish near.
func _points_toward_anchor() -> bool:
	var dir := _stroke[_stroke.size() - 1] - _stroke[0]
	return dir.dot(anchor - _stroke[0]) > 0.0


## Center of the drawn shape's bounding box. For a circle this is the circle's center,
## even though the stroke started on its edge.
func _stroke_center() -> Vector2:
	var min_p := _stroke[0]
	var max_p := _stroke[0]
	for p in _stroke:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	return (min_p + max_p) * 0.5


## 1 while drawing; after release it fades to nothing over about half a second.
func _stroke_alpha() -> float:
	if _active_mask != 0:
		return 1.0
	return clampf(1.0 - (Time.get_ticks_msec() - _ended_ms) / 450.0, 0.0, 1.0)


## The message is coloured red or green, but the stroke itself keeps its school colour.
func _report(text: String, color: Color) -> void:
	feedback.emit(text, color)


func _draw() -> void:
	# Blindness hides the trail, but the gesture still counts. You have to draw from memory.
	if hide_trail:
		return
	if _stroke.size() >= 2:
		# A glow in the school's colour, with a bright core, so the stroke reads as magic.
		var c := _stroke_color
		var a := _stroke_alpha()
		draw_polyline(_stroke, Color(c.r, c.g, c.b, 0.12 * a), 6.0)
		draw_polyline(_stroke, Color(c.r, c.g, c.b, 0.4 * a), 3.0)
		draw_polyline(_stroke, Color(c.r, c.g, c.b, a).lerp(Color.WHITE, 0.5), 2.0)
	if _active_mask != 0:
		Fx.draw_orb(self, 4.0, _stroke_color, Color.WHITE)


## True when the stroke began on solid ground (the arena says what is solid).
func _starts_on_ground() -> bool:
	if not ground_check.is_valid():
		return false
	return ground_check.call(_stroke[0])


## The average point of the stroke, in world space.
func _stroke_centroid() -> Vector2:
	var sum := Vector2.ZERO
	for p in _stroke:
		sum += p
	return sum / _stroke.size()


## The same average, in the stroke's own coordinates (relative to where it began).
func _relative_centroid(relative: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in relative:
		sum += p
	return sum / relative.size()


## Where a stroke that goes around a closed loop, then runs straight on, leaves the loop.
## Returns the index of the first point of that straight line, or -1 when the stroke is not a ring with a line.
func _ring_then_line_split(points: PackedVector2Array) -> int:
	var walked := 0.0
	var closed_at := -1
	for i in range(1, points.size()):
		walked += points[i].distance_to(points[i - 1])
		if walked > 150.0 and points[i].distance_to(points[0]) < 20.0:
			closed_at = i
			break
	if closed_at < 0:
		return -1
	# The line leaves from the last point still near the start, which skips the little arc past the closing.
	var split := closed_at
	for k in range(closed_at, points.size()):
		if points[k].distance_to(points[0]) < 20.0:
			split = k
	var tail := points.slice(split)
	var chord := tail[tail.size() - 1].distance_to(tail[0])
	if chord >= 30.0 and _max_deviation(tail) <= chord * 0.15 + 4.0:
		return split
	return -1


## A cone drawn as <: two straight arms of similar length meeting at a point. Returns {"aim": the way from the
## point out through the open end, "spread": the angle between the arms, "reach": how far the fire goes}, or {} when
## the stroke isn't one. A closed triangle (a volcano) or a hooked line is not a cone.
func _cone(points: PackedVector2Array) -> Dictionary:
	if points.size() < 6:
		return {}
	var a := points[0]
	var b := points[points.size() - 1]
	var tip_index := -1
	var farthest := 0.0
	for i in range(1, points.size() - 1):
		var away := Geometry2D.get_closest_point_to_segment(points[i], a, b).distance_to(points[i])
		if away > farthest:
			farthest = away
			tip_index = i
	if tip_index < 0:
		return {}
	var tip := points[tip_index]
	var first := a.distance_to(tip)
	var second := b.distance_to(tip)
	var shorter := minf(first, second)
	if shorter < 25.0 or maxf(first, second) > shorter * 2.5 or a.distance_to(b) < shorter * 0.25:
		return {}
	if _max_deviation(points.slice(0, tip_index + 1)) > maxf(6.0, first * 0.16):
		return {}
	if _max_deviation(points.slice(tip_index)) > maxf(6.0, second * 0.16):
		return {}
	var spread := absf(angle_difference((a - tip).angle(), (b - tip).angle()))
	if spread < deg_to_rad(18.0) or spread > deg_to_rad(120.0):
		return {}
	return {"aim": ((a + b) * 0.5 - tip).angle(), "spread": spread, "reach": first + second}


## How close a stroke is to the spell's own picture, from 0 to 1. Shapes the recognizer matched report its score; shapes
## read by a detector are judged against the spellbook's drawing of them, the same way. 0.95 and above is a perfect cast.
func _accuracy(points: PackedVector2Array, gesture: String, score: float) -> float:
	var picture := GestureTemplates.preview_points(gesture)
	if picture.size() < 2:
		return score if score < 1.0 else 0.0
	var judge := UnistrokeRecognizer.new()
	judge.add_template("shape", picture)
	return judge.recognize(points).score


## How far a stroke strays from the straight line between its two ends.
func _max_deviation(points: PackedVector2Array) -> float:
	var a := points[0]
	var b := points[points.size() - 1]
	var worst := 0.0
	for p in points:
		worst = maxf(worst, Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p))
	return worst


## The average distance of points from their centre: the radius of a drawn circle.
func _mean_distance(points: PackedVector2Array, centre: Vector2) -> float:
	var sum := 0.0
	for p in points:
		sum += p.distance_to(centre)
	return sum / points.size()


## One or more Vs (point down) in a stroke; upside-down Vs do not count. Each tip is one icicle, and its triangle is
## the space between the tip and the two arm ends. Returns the triangles in stroke space.
func _icicle_triangles(points: PackedVector2Array) -> Array:
	var turns := _turning_points(points)
	var triangles: Array = []
	if turns.is_empty():
		return triangles
	var want_bottoms := true  # only Vs: icicles hang down, and an upside-down V is left for other shapes
	for k in turns.size():
		var turn: Array = turns[k]
		if turn[1] != want_bottoms:
			continue
		# An arm ends at the nearest opposite turn on its side, or at the end of the stroke.
		var left := points[0]
		for j in range(k - 1, -1, -1):
			if turns[j][1] != want_bottoms:
				left = points[turns[j][0]]
				break
		var right := points[points.size() - 1]
		for j in range(k + 1, turns.size()):
			if turns[j][1] != want_bottoms:
				right = points[turns[j][0]]
				break
		var apex: Vector2 = points[turn[0]]
		if (left - apex).normalized().dot((right - apex).normalized()) < cos(deg_to_rad(50.0)):
			continue  # an apex wider than 50 degrees is a triangle, not an icicle
		triangles.append(PackedVector2Array([left, apex, right]))
	return triangles


## Where a stroke turns vertically by a real amount. Each entry is [point index, true for a bottom
## (lowest on screen) or false for a top].
func _turning_points(points: PackedVector2Array, axis := 1, threshold := ICICLE_TURN) -> Array:
	var turns: Array = []
	var ext := 0
	var state := 0  # 1 going down the screen, -1 going up, 0 not decided yet
	for i in range(1, points.size()):
		var y: float = points[i][axis]
		var ext_y: float = points[ext][axis]
		if state == 0:
			if y > ext_y + threshold:
				state = 1
				ext = i
			elif y < ext_y - threshold:
				state = -1
				ext = i
		elif state == 1:
			if y > ext_y:
				ext = i
			elif ext_y - y > threshold:
				turns.append([ext, true])
				state = -1
				ext = i
		else:
			if y < ext_y:
				ext = i
			elif y - ext_y > threshold:
				turns.append([ext, false])
				state = 1
				ext = i
	return turns


## Snowfall: a stroke that crosses itself at least four times (a five-pointed star drawn in one go), then
## runs on level. Returns the level part, in stroke space, or nothing.
func _snowfall_line(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3 or _count_crossings(points) < 4:
		return PackedVector2Array()
	# The level line is the run at the end of the stroke that stays close to the height it finishes at.
	var end_y := points[points.size() - 1].y
	var start := points.size() - 1
	while start > 0 and absf(points[start - 1].y - end_y) <= 18.0:
		start -= 1
	var line := points.slice(start)
	if line.size() < 2 or absf(line[line.size() - 1].x - line[0].x) < 40.0:
		return PackedVector2Array()
	return line


## How many times a stroke crosses itself.
func _count_crossings(points: PackedVector2Array) -> int:
	var count := 0
	for i in range(points.size() - 1):
		for j in range(i + 2, points.size() - 1):
			if _segments_cross(points[i], points[i + 1], points[j], points[j + 1]):
				count += 1
	return count


func _segments_cross(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab := b - a
	var cd := d - c
	var side_1 := ab.cross(c - a)
	var side_2 := ab.cross(d - a)
	var side_3 := cd.cross(a - c)
	var side_4 := cd.cross(b - c)
	return side_1 * side_2 < 0.0 and side_3 * side_4 < 0.0


## Converts stroke-space points to world space, so the arena can place effects where they were drawn.
func _to_world(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(_origin + p)
	return out


## Gravity Well: a spiral wound inward, turning at least one and a half times while it closes in on its middle.
## Returns {"center", "reach"} in stroke space, or nothing.
func _inward_spiral(points: PackedVector2Array) -> Dictionary:
	if points.size() < 16 or absf(_total_turning(points)) < deg_to_rad(500.0):
		return {}
	# The middle is where the stroke ends up: the average of its last few points.
	var tail := points.slice(int(points.size() * 0.85))
	var centre := _relative_centroid(tail)
	var reach := points[0].distance_to(centre)
	var halfway := points[points.size() / 2].distance_to(centre)
	if reach < 25.0 or halfway > reach * 0.8:
		return {}
	return {"center": centre, "reach": reach}


## The total angle a stroke turns through, signed: a full clockwise circle is about TAU.
func _total_turning(points: PackedVector2Array, span := 6.0) -> float:
	# Directions are measured over spans of a few pixels, so the tiny jitter of a hand-drawn line cancels out. A longer
	# span smooths more, for shapes that are judged by how far they turn overall.
	var total := 0.0
	var last_dir := Vector2.ZERO
	var anchor := points[0]
	for p in points:
		var step := p - anchor
		if step.length() < span:
			continue
		if last_dir != Vector2.ZERO:
			total += last_dir.angle_to(step)
		last_dir = step
		anchor = p
	return total


## Ice Prison: a closed box. Its four corners must be sharp (a circle never reaches the corners of its bounding
## box) and its sides must hug the box. Returns the box in stroke space, or an empty Rect2.

## Storm Cloud: the bumpy top of a cloud, drawn across. Wide and low, always moving the same way across, with at
## least two bumps. Returns the stroke, or nothing.
func _cloud_line(points: PackedVector2Array) -> PackedVector2Array:
	var size := _extent(points)
	if size.x < 70.0 or size.x < size.y * 2.0 or size.y < 10.0:
		return PackedVector2Array()
	if not _turning_points(points, 0, 14.0).is_empty():
		return PackedVector2Array()  # it doubles back across: a zigzag, not a cloud
	if _turning_points(points, 1, 8.0).size() < 3:
		return PackedVector2Array()
	return points


## Mudslide: a U, down one side and up the other, with both ends well above its bottom. Returns the stroke, or
## nothing.
func _pit_stroke(points: PackedVector2Array) -> PackedVector2Array:
	var turns := _turning_points(points)
	if turns.size() != 1 or not turns[0][1]:
		return PackedVector2Array()
	var bottom: Vector2 = points[turns[0][0]]
	var first := points[0]
	var last := points[points.size() - 1]
	if bottom.y - first.y < 25.0 or bottom.y - last.y < 25.0 or absf(last.x - first.x) < 40.0:
		return PackedVector2Array()
	if bottom.x < minf(first.x, last.x) or bottom.x > maxf(first.x, last.x):
		return PackedVector2Array()  # the bottom must lie between the two ends
	return points


## The width and height of a stroke's bounding box.
func _extent(points: PackedVector2Array) -> Vector2:
	return GestureTemplates.bounds(points).size


## Smoke Screen: a wavy line going up. It climbs at least 70 px and sways side to side at least three times.
func _rising_wave(points: PackedVector2Array) -> PackedVector2Array:
	var rise := points[0].y - points[points.size() - 1].y
	if rise < 70.0 or _turning_points(points, 0, 8.0).size() < 3:
		return PackedVector2Array()
	var climbing := 0
	for i in range(1, points.size()):
		if points[i].y <= points[i - 1].y + 0.5:
			climbing += 1
	if climbing < 0.6 * (points.size() - 1) or _extent(points).x > rise:
		return PackedVector2Array()
	return points


## What a stroke that starts by going up and then curls over looks like, whatever its size: which way it set off, how
## tall and wide it is, how far it turns (in degrees), and whether it ends by touching its own path again (a loop).
## A tree (a trunk that ends in a crown) is this kind of stroke.
func _stem_and_arc(points: PackedVector2Array) -> Dictionary:
	if points.size() < 12:
		return {}
	var first := 1
	while first < points.size() - 1 and points[0].distance_to(points[first]) < 16.0:
		first += 1
	var extent := _extent(points)
	var top := points[0].y
	for p in points:
		top = minf(top, p.y)
	return {
		"dir": (points[first] - points[0]).normalized(), "extent": extent, "rise": points[0].y - top,
		"ratio": extent.x / maxf(extent.y, 1.0), "turn": rad_to_deg(absf(_total_turning(points, 16.0))),
		"looped": _touches_earlier(points),
	}


## True when a stroke ends on a point it passed earlier, so it has drawn a loop that closes.
func _touches_earlier(points: PackedVector2Array) -> bool:
	var end := points[points.size() - 1]
	var walked := 0.0
	var cut := points.size() - 1
	while cut > 0 and walked < 40.0:
		walked += points[cut].distance_to(points[cut - 1])
		cut -= 1
	for i in cut:
		if points[i].distance_to(end) < 14.0:
			return true
	return false


## Which spell a stroke that sets off upward is, among the ones this button can cast: a trunk that ends in a closed loop
## is a tree. "" when it is none.
func _stem_gesture(stem: Dictionary, options: Dictionary) -> String:
	if stem["dir"].dot(Vector2.UP) < cos(deg_to_rad(35.0)) or stem["rise"] < 40.0:
		return ""
	var turn: float = stem["turn"]
	var extent: Vector2 = stem["extent"]
	if options.has("tree") and stem["looped"] and turn >= 180.0 and extent.x >= 36.0:
		return "tree"
	return ""


## Tsunami: a big wave. A long rise to a crest that curls over. Returns {"aim": the way the wave runs, which is the
## way the crest curls}, or {} when the stroke is not a wave. A sharp corner (a V) is not a curl.
func _big_wave(points: PackedVector2Array) -> Dictionary:
	if points.size() < 20:
		return {}
	var extent := _extent(points)
	if extent.x < 110.0 or extent.y < 40.0 or points[0].distance_to(points[points.size() - 1]) < 0.3 * extent.x:
		return {}
	var crest := points[0]
	for p in points:
		if p.y < crest.y:
			crest = p
	var end := points[points.size() - 1]
	if points[0].y - crest.y < 40.0 or end.y - crest.y < 25.0:
		return {}
	if rad_to_deg(absf(_total_turning(points))) < 140.0 or _sharpest_turn(points, 12.0) > deg_to_rad(70.0):
		return {}
	return {"aim": 0.0 if crest.x > points[0].x else PI}


## The sharpest turn a stroke makes within a short stretch of path, in radians: a corner scores high, a curve low.
func _sharpest_turn(points: PackedVector2Array, stretch: float) -> float:
	var worst := 0.0
	var i := 0
	while i < points.size() - 2:
		var j := i + 1
		while j < points.size() - 1 and points[i].distance_to(points[j]) < stretch:
			j += 1
		var k := j + 1
		while k < points.size() and points[j].distance_to(points[k]) < stretch:
			k += 1
		if k >= points.size():
			break
		worst = maxf(worst, absf((points[j] - points[i]).angle_to(points[k] - points[j])))
		i += 1
	return worst


## Tornado: a coil going down like a drill bit, at least a turn and a half, tall and narrow.
func _coil(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 20 or rad_to_deg(absf(_total_turning(points))) < 500.0:
		return PackedVector2Array()
	var extent := _extent(points)
	var down := points[points.size() - 1].y - points[0].y
	if down < 40.0 or extent.y < 1.2 * extent.x:
		return PackedVector2Array()
	return points


## Bramble: a low row of sharp thorns, a sawtooth line that keeps going the same way across.
func _sawtooth(points: PackedVector2Array) -> PackedVector2Array:
	var extent := _extent(points)
	if extent.x < 80.0 or extent.y > 0.5 * extent.x or extent.y < 10.0:
		return PackedVector2Array()
	if not _turning_points(points, 0, 14.0).is_empty() or _count_crossings(points) > 0:
		return PackedVector2Array()  # it doubles back across itself: not a row of teeth
	if _turning_points(points, 1, 8.0).size() < 5:
		return PackedVector2Array()
	return points


## Flytrap: open jaws, a W (or an M) about as tall as it is wide, moving the same way across.
func _w_shape(points: PackedVector2Array) -> PackedVector2Array:
	var extent := _extent(points)
	if extent.x < 40.0 or extent.y < 50.0 or extent.y < 0.7 * extent.x or extent.y > 2.5 * extent.x:
		return PackedVector2Array()
	if not _turning_points(points, 0, 14.0).is_empty():
		return PackedVector2Array()
	var turns := _turning_points(points, 1, 20.0).size()
	if turns != 3 and turns != 4:
		return PackedVector2Array()
	return points


## Lily Pads: a row of low loops, drawn as one chain that crosses itself at least twice and runs across.
func _loop_row(points: PackedVector2Array) -> PackedVector2Array:
	var extent := _extent(points)
	if extent.x < 80.0 or extent.y > 0.7 * extent.x or _count_crossings(points) < 2:
		return PackedVector2Array()
	if absf(points[points.size() - 1].x - points[0].x) < 0.5 * extent.x:
		return PackedVector2Array()
	return points


## A flame is a loop that comes to a point, and the point is at the top: the top of the stroke is narrower than the
## bottom, however fat or thin the flame is.
func _flame_points_up(points: PackedVector2Array) -> bool:
	var top := INF
	var bottom := -INF
	for p in points:
		top = minf(top, p.y)
		bottom = maxf(bottom, p.y)
	var band := (bottom - top) * 0.25
	if band <= 0.0:
		return false
	var top_low := INF
	var top_high := -INF
	var bottom_low := INF
	var bottom_high := -INF
	for p in points:
		if p.y <= top + band:
			top_low = minf(top_low, p.x)
			top_high = maxf(top_high, p.x)
		if p.y >= bottom - band:
			bottom_low = minf(bottom_low, p.x)
			bottom_high = maxf(bottom_high, p.x)
	return (top_high - top_low) < 0.75 * (bottom_high - bottom_low)


## Casts a stroke that was not drawn with the mouse, such as a dark wizard's. It resolves exactly like a drawn one.
func cast_stroke(mask: int, points: PackedVector2Array) -> void:
	_stroke = points
	_origin = points[0]
	_active_mask = mask
	_end()

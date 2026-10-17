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
func _school_color(mask: int) -> Color:
	for spell_name in SpellData.SPELLS:
		var s: Dictionary = SpellData.SPELLS[spell_name]
		if s["buttons"] == mask:
			return SpellData.SCHOOL_COLORS[s["school"]]
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
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		mask |= SpellData.LEFT
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		mask |= SpellData.RIGHT
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
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
		_report("Stroke too short", Color.GRAY)
		return

	var options: Dictionary = _bindings.get(mask, {})
	var result := recognizer.recognize(relative, _templates_for(options))
	var score: float = result.score
	var gesture: String = GestureTemplates.ALIASES.get(result.name, result.name)
	# Some shapes are read from the stroke itself, since the recognizer can't tell them apart reliably. The
	# info dictionary carries what the arena needs to place each effect.
	var info := {"radius": 0.0, "pieces": 1, "shapes": [], "line": PackedVector2Array(), "rect": Rect2()}
	var spiral := _inward_spiral(relative) if options.has("spiral") else {}
	var ring_split := _ring_then_line_split(relative) if options.has("circle_push") and spiral.is_empty() else -1
	var ring_centre := Vector2.ZERO
	var box := _box(relative) if options.has("square") else Rect2()
	var icicles: Array = _icicle_triangles(relative) if options.has("icicles") else []
	var snow_line := _snowfall_line(relative) if options.has("snowfall") else PackedVector2Array()
	var funnel := _funnel_stroke(relative) if options.has("tornado") else PackedVector2Array()
	var cloud := _cloud_line(relative) if options.has("cloud") else PackedVector2Array()
	var crack := _crack_line(relative) if options.has("fissure") else PackedVector2Array()
	var pit := _pit_stroke(relative) if options.has("pit") else PackedVector2Array()
	var cone := _cone(relative) if options.has("cone") else {}
	if not spiral.is_empty():
		# A spiral wound inward is a Gravity Well, centred where it ends up.
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
	elif box.size != Vector2.ZERO:
		gesture = "square"
		score = 1.0
		info["rect"] = Rect2(_origin + box.position, box.size)
	elif snow_line.size() >= 2:
		gesture = "snowfall"
		score = 1.0
		info["line"] = _to_world(snow_line)
	elif funnel.size() > 0:
		gesture = "tornado"
		score = 1.0
		info["line"] = _to_world(funnel)
	elif cloud.size() > 0:
		gesture = "cloud"
		score = 1.0
		info["line"] = _to_world(cloud)
	elif crack.size() > 0:
		gesture = "fissure"
		score = 1.0
		info["line"] = _to_world(crack)
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
	var entry = options.get(gesture)
	# A cast that works shows its name where it was drawn (the arena does that), so only failures are reported here.
	if score < tolerance:
		_report("Misfire: that shape was too rough to read (%d%% match). A steadier stroke, or a wand, helps." % roundi(score * 100.0), Color("#ff7a7a"))
		misfired.emit()
	elif entry == null:
		_report("Misfire: %s has no spell drawn like that. Tab opens the spellbook." % SpellData.button_name(mask), Color("#ff7a7a"))
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
		if entry.targeting == "shape" and info["line"].is_empty():
			info["line"] = _to_world(relative)
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


## A V (point down) or an upside-down V (point up) in a stroke. Each tip is one icicle, and its triangle is
## the space between the tip and the two arm ends. Returns the triangles in stroke space. The kind of tip
## that occurs most decides the kind, so a row of Vs is a row of icicles hanging down.
func _icicle_triangles(points: PackedVector2Array) -> Array:
	var turns := _turning_points(points)
	var triangles: Array = []
	if turns.is_empty():
		return triangles
	var bottoms := 0
	for turn in turns:
		if turn[1]:
			bottoms += 1
	var want_bottoms := bottoms * 2 >= turns.size()
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
		triangles.append(PackedVector2Array([left, points[turn[0]], right]))
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
	while start > 0 and absf(points[start - 1].y - end_y) <= 12.0:
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


## A tornado: a zigzag going back and forth that is wide at the top and narrow at the bottom. Spark is a zigzag
## of the same width, so it is not a tornado. Returns the stroke, or nothing.
func _funnel_stroke(points: PackedVector2Array) -> PackedVector2Array:
	if _turning_points(points, 0).size() < 4:
		return PackedVector2Array()
	var low := points[0]
	var high := points[0]
	for p in points:
		low = low.min(p)
		high = high.max(p)
	var height := high.y - low.y
	if height < 60.0:
		return PackedVector2Array()
	var top_min := INF
	var top_max := -INF
	var bottom_min := INF
	var bottom_max := -INF
	for p in points:
		if p.y < low.y + height * 0.3:
			top_min = minf(top_min, p.x)
			top_max = maxf(top_max, p.x)
		elif p.y > high.y - height * 0.3:
			bottom_min = minf(bottom_min, p.x)
			bottom_max = maxf(bottom_max, p.x)
	var top_width := top_max - top_min
	var bottom_width := bottom_max - bottom_min
	if top_width < 50.0 or top_width < bottom_width * 1.5:
		return PackedVector2Array()
	return points


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
func _total_turning(points: PackedVector2Array) -> float:
	# Directions are measured over spans of a few pixels, so the tiny jitter of a hand-drawn line cancels out.
	var total := 0.0
	var last_dir := Vector2.ZERO
	var anchor := points[0]
	for p in points:
		var step := p - anchor
		if step.length() < 6.0:
			continue
		if last_dir != Vector2.ZERO:
			total += last_dir.angle_to(step)
		last_dir = step
		anchor = p
	return total


## Ice Prison: a closed box. Its four corners must be sharp (a circle never reaches the corners of its bounding
## box) and its sides must hug the box. Returns the box in stroke space, or an empty Rect2.
func _box(points: PackedVector2Array) -> Rect2:
	var low := points[0]
	var high := points[0]
	for p in points:
		low = low.min(p)
		high = high.max(p)
	var size := high - low
	var side := minf(size.x, size.y)
	if side < 24.0 or size.x > size.y * 3.5 or size.y > size.x * 3.5:
		return Rect2()
	if points[0].distance_to(points[points.size() - 1]) > maxf(20.0, side * 0.3):
		return Rect2()  # not closed
	for corner in [low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)]:
		var nearest := INF
		for p in points:
			nearest = minf(nearest, p.distance_to(corner))
		if nearest > side * 0.17 + 4.0:
			return Rect2()
	var on_edges := 0
	for p in points:
		var edge := minf(minf(p.x - low.x, high.x - p.x), minf(p.y - low.y, high.y - p.y))
		if edge <= side * 0.12 + 3.0:
			on_edges += 1
	if on_edges < points.size() * 0.75:
		return Rect2()
	return Rect2(low, size)


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


## Fissure: a jagged crack drawn sideways along the ground, starting on it. Returns the stroke, or nothing.
func _crack_line(points: PackedVector2Array) -> PackedVector2Array:
	var size := _extent(points)
	if size.x < 60.0 or size.x < size.y * 2.5 or not _starts_on_ground():
		return PackedVector2Array()
	if not _turning_points(points, 0, 14.0).is_empty():
		return PackedVector2Array()
	if _turning_points(points, 1, 5.0).size() < 3:
		return PackedVector2Array()
	return points


## Quicksand: a U, down one side and up the other, with both ends well above its bottom. Returns the stroke, or
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
	var low := points[0]
	var high := points[0]
	for p in points:
		low = low.min(p)
		high = high.max(p)
	return high - low


## Casts a stroke that was not drawn with the mouse, such as a dark wizard's. It resolves exactly like a drawn one.
func cast_stroke(mask: int, points: PackedVector2Array) -> void:
	_stroke = points
	_origin = points[0]
	_active_mask = mask
	_end()

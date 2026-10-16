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

	var result := recognizer.recognize(relative)
	var score: float = result.score
	var gesture: String = GestureTemplates.ALIASES.get(result.name, result.name)
	var options: Dictionary = _bindings.get(mask, {})
	# Some shapes are read from the stroke itself, since the recognizer can't tell them apart reliably. The
	# info dictionary carries what the arena needs to place each effect.
	var info := {"radius": 0.0, "pieces": 1, "shapes": [], "line": PackedVector2Array()}
	var ring_split := _ring_then_line_split(relative) if options.has("circle_push") else -1
	var ring_centre := Vector2.ZERO
	var icicles: Array = _icicle_triangles(relative) if options.has("icicles") else []
	var snow_line := _snowfall_line(relative) if options.has("snowfall") else PackedVector2Array()
	var peaks := _chain_peaks(relative) if options.has("chain") else PackedVector2Array()
	if ring_split >= 0:
		# A closed ring with a straight line out of it is a Push. The line can point any way.
		gesture = "circle_push"
		score = 1.0
		var ring := relative.slice(0, ring_split)
		ring_centre = _relative_centroid(ring)
		info["radius"] = _mean_distance(ring, ring_centre)
	elif peaks.size() > 0:
		gesture = "chain"
		score = 1.0
		info["pieces"] = peaks.size()
		info["peaks"] = _to_world(peaks)
	elif snow_line.size() >= 2:
		gesture = "snowfall"
		score = 1.0
		info["line"] = _to_world(snow_line)
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
	if score < tolerance:
		_report("MISFIRE: not recognised (score %.2f)" % score, Color.RED)
		misfired.emit()
	elif entry == null:
		_report("MISFIRE: no spell on this button for that shape (Tab for the spellbook)", Color.RED)
		misfired.emit()
	else:
		var aim := 0.0
		var msg := "CAST %s [%s] score %.2f" % [entry.spell, entry.targeting, score]
		if entry.targeting == "directional":
			aim = (relative[relative.size() - 1] - relative[0]).angle()
			msg += "  aim %.0f deg" % rad_to_deg(aim)
		_report(msg, Color.GREEN)
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
		cast_resolved.emit(entry.spell, entry.targeting, spawn, aim, info)



## The hump tops of a wave (like a lowercase m): each is one bounce of Chain Lightning. Returns them in
## stroke space, or nothing when the stroke is not a wide wave.
func _chain_peaks(points: PackedVector2Array) -> PackedVector2Array:
	var peaks := PackedVector2Array()
	var low := points[0]
	var high := points[0]
	for p in points:
		low = low.min(p)
		high = high.max(p)
	if high.x - low.x <= high.y - low.y:
		return peaks  # a tall zigzag is Spark, not a wave
	for turn in _turning_points(points):
		if not turn[1]:
			peaks.append(points[turn[0]])
	return peaks


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
	var tail_length := UnistrokeRecognizer.path_length(tail)
	if tail_length >= 40.0 and tail[tail.size() - 1].distance_to(tail[0]) >= 0.9 * tail_length:
		return split
	return -1


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
func _turning_points(points: PackedVector2Array) -> Array:
	var turns: Array = []
	var ext := 0
	var state := 0  # 1 going down the screen, -1 going up, 0 not decided yet
	for i in range(1, points.size()):
		var y: float = points[i].y
		var ext_y: float = points[ext].y
		if state == 0:
			if y > ext_y + ICICLE_TURN:
				state = 1
				ext = i
			elif y < ext_y - ICICLE_TURN:
				state = -1
				ext = i
		elif state == 1:
			if y > ext_y:
				ext = i
			elif ext_y - y > ICICLE_TURN:
				turns.append([ext, true])
				state = -1
				ext = i
		else:
			if y < ext_y:
				ext = i
			elif y - ext_y > ICICLE_TURN:
				turns.append([ext, false])
				state = 1
				ext = i
	return turns


## Snowfall: a stroke that crosses itself at least four times (a five-pointed star drawn in one go), then
## runs on level. Returns the level part, in stroke space, or nothing.
func _snowfall_line(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3 or _count_crossings(points) < 4:
		return PackedVector2Array()
	var start := points.size() - 1
	while start > 0:
		var step := points[start] - points[start - 1]
		if step.length() > 1.0 and absf(step.y) > 0.3 * absf(step.x):
			break
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

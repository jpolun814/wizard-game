class_name Caster
extends Node2D

## Casting input: hold a school mouse button, draw, release to resolve.
## Gesture origin is the cursor position when the button goes down.
## Emits cast_resolved for world effects, and misfired when a stroke does not match a spell.

signal cast_resolved(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary)
signal misfired

@export var tolerance := 0.70          # minimum $1 score to count as a cast
@export var min_stroke_length := 20.0  # shorter strokes are ignored as clicks
@export var wall_tolerance_deg := 20.0  # straight strokes this close to vertical are walls
const MIN_POINT_SPACING := 2.0

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


## The stroke being drawn, in the world; empty while none is.
func stroke() -> PackedVector2Array:
	return _stroke if is_drawing() else PackedVector2Array()


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
		return  # too short to be a spell: silent, since the stroke itself shows it was not one (a click on a flare snuffs it)

	var options: Dictionary = _bindings.get(mask, {})
	var result := recognizer.recognize(relative, _templates_for(options))
	var score: float = result.score
	var gesture: String = GestureTemplates.ALIASES.get(result.name, result.name)
	var read := _read_special(relative, options, gesture, score)
	gesture = read["gesture"]
	score = read["score"]
	var info: Dictionary = read["info"]
	var ring_split: int = read["ring_split"]
	var latin: bool = read["latin"]
	var settled := _settle(relative, options, gesture, score, latin)
	_resolve(relative, options, settled["gesture"], settled["score"], info, ring_split, read["ring_centre"])


## The shapes that are read from the stroke itself, since the recognizer cannot tell them apart reliably: each detector that finds its shape says so in
## `gesture` and `score` (a certain read is 1.0) and fills in what the arena needs to place the effect. Returns {gesture, score, info, ring_split, ring_centre, latin}.
func _read_special(relative: PackedVector2Array, options: Dictionary, gesture: String, score: float) -> Dictionary:
	# Some shapes are read from the stroke itself, since the recognizer can't tell them apart reliably. The
	# info dictionary carries what the arena needs to place each effect.
	var info := {"radius": 0.0, "pieces": 1, "shapes": [], "line": PackedVector2Array(), "rect": Rect2()}
	# A star drawn in one stroke winds inward like a spiral, so it must be ruled out first.
	var star := gesture == "pentagram" and score >= tolerance
	var slashed := options.has("silence") and StrokeShapes.is_slashed_ring(relative)
	var spiral := StrokeShapes.inward_spiral(relative) if options.has("spiral") and not star and not slashed else {}
	var hail := StrokeShapes.hailstorm(relative) if options.has("hailstorm") else {}
	var feather := StrokeShapes.feather(relative) if options.has("feather") else {}
	var latin := options.has("latin_cross") and StrokeShapes.is_cross(relative)
	var flame_wall := StrokeShapes.up_and_out(relative) if options.has("flame_wall") else PackedVector2Array()
	var thunder := options.has("thunderclap") and StrokeShapes.is_thunderclap(relative)
	var portrait := options.has("portrait") and StrokeShapes.is_portrait_box(relative)
	var ring_split := StrokeShapes.ring_then_line_split(relative) if (options.has("circle_push") or options.has("sphere")) and spiral.is_empty() and feather.is_empty() else -1
	if ring_split >= 0 and options.has("sphere") and not options.has("circle_push") and not StrokeMeasure.runs_level(relative.slice(ring_split)):
		ring_split = -1  # a ball of fire is pushed along the ground: the line out of the ring must run level
	if ring_split >= 0 and options.has("saturn") and gesture == "saturn" and score >= tolerance:
		ring_split = -1  # a ring and a flat oval round it is a sun, not a ring with a line out of it
	var ring_centre := Vector2.ZERO
	# Icicles are open V strokes. A closed loop (a circle, a crystal) is never an icicle.
	var extent := StrokeMeasure.extent(relative)
	var closed := relative[0].distance_to(relative[relative.size() - 1]) < 0.3 * maxf(extent.x, extent.y)
	# An arrow pointing up drawn with the water button is a Geyser, not a row of icicles.
	var peak := gesture == "geyser" and score >= tolerance
	var icicles: Array = StrokeShapes.icicle_triangles(relative) if options.has("icicles") and not closed and not peak and spiral.is_empty() else []
	var spikes: Array = StrokeShapes.icicle_triangles(relative, false) if options.has("stalagmite") and not closed and not (score >= tolerance - 0.12 and gesture in ["stonefall", "earthquake"]) else []  # a circle and a drop, and a double arrow, also have peaks in them
	var snow_line := StrokeShapes.snowfall_line(relative) if options.has("snowfall") else PackedVector2Array()
	var cloud := StrokeShapes.cloud_line(relative) if options.has("cloud") else PackedVector2Array()
	var pit := StrokeShapes.pit_stroke(relative) if options.has("pit") else PackedVector2Array()
	var cone := StrokeShapes.cone(relative) if options.has("cone") else {}
	var smoke := StrokeShapes.rising_wave(relative) if options.has("smoke") and not (gesture == "rocket" and score >= tolerance) else PackedVector2Array()  # (an arrow up is a Rocket Jump, even when drawn a little wavy)
	var wave := StrokeShapes.cloud_line(relative) if options.has("wave") else PackedVector2Array()
	# A leaf with a vine up from it starts like a tree's trunk would end, so a stroke the recognizer reads as one is not a tree.
	var vine := gesture == "vine" and score >= tolerance
	var stem := StrokeShapes.stem_and_arc(relative) if options.has("tree") and not vine else {}
	var tsunami := StrokeShapes.big_wave(relative) if options.has("tsunami") else {}
	var coil := StrokeShapes.coil(relative) if options.has("tornado") else PackedVector2Array()
	var bramble := StrokeShapes.sawtooth(relative) if options.has("bramble") else PackedVector2Array()
	var jaws := StrokeShapes.w_shape(relative) if options.has("jaws") else PackedVector2Array()
	var pads := StrokeShapes.pad_line(relative) if options.has("pads") and spiral.is_empty() else PackedVector2Array()
	if portrait:
		gesture = "portrait"  # a tall box with four sharp corners: a picture frame, a doorway
		score = 1.0
	elif thunder:
		gesture = "thunderclap"  # a cloud, and a bolt of lightning down out of it
		score = 1.0
	elif not flame_wall.is_empty():
		gesture = "flame_wall"  # a line up and a line out: a wall of flame as wide as the second line
		score = 1.0
		info["line"] = _to_world(flame_wall)
	elif latin:
		gesture = "latin_cross"  # an upright stem with a bar across it, nearer the top: read before the recognizer's guess
		score = 1.0
	elif not hail.is_empty():
		# A ring, a line out of it and a line down: a Hailstorm, the cloud running from the ring to the bend.
		gesture = "hailstorm"
		score = 1.0
		info["line"] = _to_world(PackedVector2Array([hail["from"], hail["to"]]))
	elif not feather.is_empty():
		gesture = "feather"
		score = 1.0
	elif not spiral.is_empty():
		# A spiral wound inward is a Black Hole, centred where it ends up.
		gesture = "spiral"
		score = 1.0
		info["radius"] = spiral["reach"]
		info["center"] = _origin + spiral["center"]
	elif slashed:
		gesture = "silence"
		score = 1.0
	elif ring_split >= 0:
		# A closed ring with a straight line out of it is a Push. The line can point any way.
		gesture = "sphere" if options.has("sphere") else "circle_push"
		score = 1.0
		var ring := relative.slice(0, ring_split)
		ring_centre = StrokeMeasure.centroid(ring)
		info["radius"] = StrokeMeasure.mean_distance(ring, ring_centre)
	elif pads.size() > 0:
		gesture = "pads"
		score = 1.0
		info["line"] = _to_world(pads)
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
	elif not stem.is_empty() and StrokeShapes.stem_gesture(stem, options) != "":
		gesture = StrokeShapes.stem_gesture(stem, options)
		score = 1.0
	elif not tsunami.is_empty():
		gesture = "tsunami"
		score = 1.0
		info["aim"] = tsunami["aim"]
	elif coil.size() > 0:
		gesture = "tornado"
		score = 1.0
		info["line"] = _to_world(coil)
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
	elif not spikes.is_empty():
		gesture = "stalagmite"
		score = 1.0
		info["pieces"] = spikes.size()
		for tri in spikes:
			info["shapes"].append(_to_world(tri))
	elif not icicles.is_empty():
		gesture = "icicles"
		score = 1.0
		info["pieces"] = icicles.size()
		for tri in icicles:
			info["shapes"].append(_to_world(tri))
	return {"gesture": gesture, "score": score, "info": info, "ring_split": ring_split, "ring_centre": ring_centre, "latin": latin}


## What the read leaves to be settled: a straight stroke is a flick, a wall or a pull by the button, a cross or a flame that is not one is no spell, and a loop taken for a flame
## is read again without the flames. Returns {gesture, score}.
func _settle(relative: PackedVector2Array, options: Dictionary, gesture: String, score: float, latin: bool) -> Dictionary:
	# A straight stroke can mean a wall (vertical), a pull (toward you) or a plain flick, depending on the button.
	if gesture == "flick":
		if options.has("wall") and _is_vertical(relative):
			gesture = "wall"
		elif options.has("flick_toward") and _points_toward_anchor():
			gesture = "flick_toward"

	# A straight stroke that begins on the ground raises a stone wall instead of a spike.
	if gesture == "flick" and options.has("stone_wall") and _starts_on_ground():
		gesture = "stone_wall"
	if gesture == "latin_cross" and not latin:
		score = 0.0  # a stem alone, or any stroke the recognizer likes, is not a cross
	if gesture == "flare" and not StrokeShapes.flame_points_up(relative):
		score = 0.0  # a plain loop, or a drop, is not a flame
		if options.has("circle"):  # where a circle is also drawn, a loop the recognizer took for a flame is read again without the flames
			var rest := _templates_for(options).filter(func(n: String) -> bool: return not n.begins_with("flame"))
			var again := recognizer.recognize(relative, rest)
			gesture = GestureTemplates.ALIASES.get(again.name, again.name)
			score = again.score
	return {"gesture": gesture, "score": score}


## A stroke read: a spell is cast from it, when the shape is good enough and the buttons have a spell for it, and a misfire is reported when not.
func _resolve(relative: PackedVector2Array, options: Dictionary, gesture: String, score: float, info: Dictionary, ring_split: int, ring_centre: Vector2) -> void:
	var entry = options.get(gesture)
	# A cast that works shows its name where it was drawn (the arena does that), so only failures are reported here.
	# Stonefall's circle and drop and the flame are hard to draw cleanly, so they are read with a looser eye than the other shapes.
	var needed := tolerance - 0.12 if gesture == "stonefall" or gesture == "flare" else tolerance
	if score < needed:
		misfired.emit()
	elif entry == null:
		misfired.emit()
	else:
		var aim := 0.0
		if entry.targeting == "directional":
			aim = (relative[relative.size() - 1] - relative[0]).angle()
		if entry.targeting == "directional":
			info["length"] = (relative[relative.size() - 1] - relative[0]).length()
		# A drawn circle sets how big the spell is, which sets its cost (Push and the other circles).
		if gesture.begins_with("circle") and ring_split < 0:
			info["radius"] = StrokeMeasure.mean_distance(relative, StrokeMeasure.centroid(relative))
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
		if entry.spell == "Thorn Whip" or entry.spell == "Eldritch Blast":  # a bolt goes the way the arrow points
			var farthest := relative[0]  # a whip goes the way the wave was drawn, at whatever angle, not only left or right
			for p in relative:
				if p.distance_squared_to(relative[0]) > farthest.distance_squared_to(relative[0]):
					farthest = p
			aim = (farthest - relative[0]).angle()
		if entry.spell == "Ice Prison":
			# The circle drawn round the target is the box the ice fills: its bounds, wherever it was drawn.
			var box := GestureTemplates.bounds(relative)
			info["rect"] = Rect2(_origin + box.position, box.size)
		if entry.targeting == "shape" and info["line"].is_empty():
			info["line"] = _to_world(relative)
		info["extent"] = StrokeMeasure.extent(relative)  # how big it was drawn, for spells that grow with it
		info["accuracy"] = StrokeShapes.accuracy(relative, gesture, score)
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


## Converts stroke-space points to world space, so the arena can place effects where they were drawn.
func _to_world(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(_origin + p)
	return out


## Ice Prison: a closed box. Its four corners must be sharp (a circle never reaches the corners of its bounding
## box) and its sides must hug the box. Returns the box in stroke space, or an empty Rect2.


## Casts a stroke that was not drawn with the mouse, such as an AI wizard's. It resolves exactly like a drawn one.
func cast_stroke(mask: int, points: PackedVector2Array) -> void:
	_stroke = points
	_origin = points[0]
	_active_mask = mask
	_end()

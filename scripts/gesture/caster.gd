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
var reader := StrokeReader.new(recognizer)  # what a stroke was, once it is drawn
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
	reader.tolerance = tolerance
	reader.wall_tolerance_deg = wall_tolerance_deg
	var reading := reader.read(relative, _origin, options)
	reader.settle(reading, relative, options, _stroke, anchor, ground_check)
	_resolve(relative, options, reading)


## A stroke read: a spell is cast from it, when the shape is good enough and the buttons have a spell for it, and a misfire is reported when not.
func _resolve(relative: PackedVector2Array, options: Dictionary, reading: StrokeReading) -> void:
	var gesture := reading.gesture
	var score := reading.score
	var info := reading.info
	var ring_split := reading.ring_split
	var ring_centre := reading.ring_centre
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
			info["line"] = StrokeMeasure.to_world(relative, _origin)
		info["extent"] = StrokeMeasure.extent(relative)  # how big it was drawn, for spells that grow with it
		info["accuracy"] = StrokeShapes.accuracy(relative, gesture, score)
		cast_resolved.emit(entry.spell, entry.targeting, spawn, aim, info)


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


## The average point of the stroke, in world space.
func _stroke_centroid() -> Vector2:
	var sum := Vector2.ZERO
	for p in _stroke:
		sum += p
	return sum / _stroke.size()


## Casts a stroke that was not drawn with the mouse, such as an AI wizard's. It resolves exactly like a drawn one.
func cast_stroke(mask: int, points: PackedVector2Array) -> void:
	_stroke = points
	_origin = points[0]
	_active_mask = mask
	_end()

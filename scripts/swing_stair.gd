class_name SwingStair
extends AnimatableBody2D

## A stair that swings, like the moving stairs of a great castle: a plank of brick hinged at a landing beside a stairwell, whose free end swings
## among landings on other floors. It stays at one for a while, swings to another, and stays there. Whoever stands on it is carried as it turns,
## and may be thrown off. It is a one-way platform, as the other stairs are: it can be walked up onto, and S drops through it.
## Where it is at any time follows the world's seed and how long the world has lasted alone, so every machine of a match sees it in the same place.

const HOLD_LEAST := 6.0  # seconds it stays at a landing, at the least and at the most: no two stays are alike
const HOLD_MOST := 12.0
const SWING_LEAST := 3.0  # seconds a swing takes: slow, as stone is
const SWING_MOST := 4.6
const THICKNESS := 45.25  # the fixed castle brick's band: two tiles tall, which across a slope of 45 degrees is this
const STATIONS := 10      # the points along its underside that are made uneven
const HEARD_WITHIN := 1400.0  # how far from the camera a sound can still be heard (Sfx.MAX_DISTANCE; Sfx is not there when the generator is tested on its own)
const GRIND_GAP := 0.7   # seconds between the grinds of stone on stone while it swings

var hinge := Vector2.ZERO          # where it is fastened, in the world
var ends: Array[Vector2] = []      # where its free end can be, in the world
var ways: Array = []               # for each of those, the {from, to} tiles of the landings it joins
var seed_value := 0
var stone: Texture2D               # what it is made of: the castle's stone, which the world gives it
var seconds := 0.0                 # how long it has been in the world, which is the world's age: it counts it itself, so that it moves even while no one is watching

var _poses := PackedInt32Array()   # which end it is at in each stretch of time, made as far on as is needed
var _begins := PackedFloat32Array()  # when each stretch begins, in seconds; a stretch is a swing, then a stay
var _lengths := PackedFloat32Array()  # how long each stay is
var _swings := PackedFloat32Array()  # how long the swing at the start of each stretch takes
var _rng := RandomNumberGenerator.new()
var _shape := SegmentShape2D.new()
var _length := 0.0
var _placed_at := Vector2(INF, INF)
var _grind := 0.0
var _was_swinging := false
var _drawn_length := -1.0
var _drawn_way := 0.0
var _way := 1.0                    # 1 when the free end is to the right of the hinge, -1 when it is to the left
var _underside := PackedFloat32Array()  # how thick it is at each station along it, as a share of THICKNESS: it is cut and worn, not a clean slab
var _tip_cut := Vector2.ZERO       # how much of its two ends is chipped off the underside: x at the hinge, y at the tip


func _ready() -> void:
	add_to_group("swing_stairs")
	collision_layer = 16
	collision_mask = 0
	sync_to_physics = false
	z_index = 1
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_rng.seed = hash(seed_value)  # neighbouring seeds would give neighbouring first numbers, and the stairs would begin together
	_tip_cut = Vector2(_rng.randf_range(0.25, 0.6), _rng.randf_range(0.25, 0.6))
	for k in STATIONS + 1:
		_underside.append(_rng.randf_range(0.65, 1.2))
	var body_shape := CollisionShape2D.new()
	body_shape.shape = _shape
	body_shape.one_way_collision = true
	body_shape.one_way_collision_margin = 6.0
	add_child(body_shape)
	position = hinge
	_place(_end_at(seconds))


func _physics_process(delta: float) -> void:
	seconds += delta
	_place(_end_at(seconds))
	_sound(delta)


## While it swings, stone grinds on stone, louder the nearer the camera is and not at all from beyond where a sound can be heard; and when it comes to rest
## it settles with a low thud.
func _sound(delta: float) -> void:
	var slot := _slot_at(seconds)
	var swinging := slot > 0 and seconds - _begins[slot] < _swings[slot]
	var sfx := get_node_or_null("/root/Sfx")
	var camera := get_viewport().get_camera_2d()
	if sfx == null or camera == null:
		return
	var heard := camera.get_screen_center_position().distance_to(global_position + Vector2(_way * _length * 0.5, 0.0).rotated(rotation)) < HEARD_WITHIN
	if swinging and heard:
		_grind -= delta
		if _grind <= 0.0:
			_grind = GRIND_GAP * _rng_gap()
			sfx.call("play", "stones", global_position + Vector2(_way * _length * 0.5, 0.0).rotated(rotation), -3.0, 0.2, 0.32)
	elif _was_swinging and not swinging and heard:
		sfx.call("play", "stones", global_position + Vector2(_way * _length, 0.0).rotated(rotation), 0.0, 0.1, 0.25)
	_was_swinging = swinging


func _rng_gap() -> float:
	return 0.75 + fposmod(seconds * 7.31, 0.5)


## The stretch of time a moment falls in, making the stretches as far on as needed. A stay is a different length every time, and so is a swing.
func _slot_at(time: float) -> int:
	if _begins.is_empty():
		_begins.append(0.0)
		_swings.append(0.0)
		_poses.append(_rng.randi() % ends.size())
	while _begins[_begins.size() - 1] + _stay_end(_begins.size() - 1) <= time:
		_begins.append(_begins[_begins.size() - 1] + _stay_end(_begins.size() - 1))
		_swings.append(_rng.randf_range(SWING_LEAST, SWING_MOST))
		_poses.append((_poses[_poses.size() - 1] + 1 + _rng.randi() % (ends.size() - 1)) % ends.size())
	var slot := _begins.size() - 1
	while slot > 0 and _begins[slot] > time:
		slot -= 1
	return slot


## How long a stretch lasts in all, from its start to the start of the next: its swing, and a stay that is not the same length twice.
func _stay_end(slot: int) -> float:
	while _lengths.size() <= slot:
		# the first stay is far more varied, so that the stairs of a world do not set off together when it begins
		_lengths.append(_rng.randf_range(1.0, HOLD_MOST + 6.0) if _lengths.is_empty() else _rng.randf_range(HOLD_LEAST, HOLD_MOST))
	return _swings[slot] + _lengths[slot]


## Where the free end is at a moment: at rest at one of the ends, or on its way from the last to the next, getting under way slowly and slowing to a
## stop, as a great weight does. It does not rock or bounce.
func _end_at(time: float) -> Vector2:
	var slot := _slot_at(time)
	var phase := time - _begins[slot]
	var rest := ends[_poses[slot]]
	if slot > 0 and phase < _swings[slot]:
		var along := smoothstep(0.0, 1.0, smoothstep(0.0, 1.0, phase / _swings[slot]))
		return ends[_poses[slot - 1]].lerp(rest, along)
	return rest


func _place(end: Vector2) -> void:
	if end == _placed_at:
		return  # at rest: nothing to move, nothing to draw again
	_placed_at = end
	var across := end - hinge
	_way = 1.0 if across.x >= 0.0 else -1.0
	_length = across.length()
	position = hinge
	rotation = _way * atan2(across.y, absf(across.x))
	_shape.a = Vector2(minf(_way * _length, 0.0), 0.0)  # from its left end to its right, so that the top is the side that holds
	_shape.b = Vector2(maxf(_way * _length, 0.0), 0.0)
	if absf(_length - _drawn_length) > 0.5 or _way != _drawn_way:
		_drawn_length = _length  # its shape only changes with its length: turning it is the engine's work, not a new picture
		_drawn_way = _way
		queue_redraw()


func _draw() -> void:
	# Drawn as the castle's fixed brick is: stone, the brick over it at twice its size, and a dark rim. The top is straight to walk on; the underside
	# is uneven, and its two ends are chipped.
	var tip := _way * _length
	var outline := PackedVector2Array([Vector2(0.0, 0.0), Vector2(tip, 0.0), Vector2(tip, THICKNESS * (_underside[STATIONS] - _tip_cut.y))])
	for k in range(STATIONS - 1, 0, -1):
		outline.append(Vector2(tip * float(k) / float(STATIONS), THICKNESS * _underside[k]))
	outline.append(Vector2(0.0, THICKNESS * (_underside[0] - _tip_cut.x)))
	var uvs := PackedVector2Array()
	for point in outline:
		uvs.append(point / stone.get_size())
	draw_colored_polygon(outline, Terrain.STONE_FILL)
	draw_polygon(outline, PackedColorArray([Color.WHITE]), uvs, stone)
	var closed := PackedVector2Array(outline)
	closed.append(outline[0])
	draw_polyline(closed, Terrain.RIM, 3.0)


## True while it is on its way from one landing to another.
func is_swinging() -> bool:
	var slot := _slot_at(seconds)
	return slot > 0 and seconds - _begins[slot] < _swings[slot]


## True when this stair joins the two landing tiles right now, and will go on joining them for long enough to cross: `needed` seconds of its stay
## are still to come. A stair that is swinging, or about to, joins nothing.
func joins(from: Vector2i, to: Vector2i, needed: float) -> bool:
	var slot := _slot_at(seconds)
	if is_swinging() or _begins[slot] + _stay_end(slot) - seconds < needed:
		return false
	var way: Dictionary = ways[_poses[slot]]
	return (way["from"] == from and way["to"] == to) or (way["from"] == to and way["to"] == from)


## True when a pair of landing tiles is joined by a swinging stair at all (whether or not it is there now).
static func is_a_way(tree: SceneTree, from: Vector2i, to: Vector2i) -> bool:
	for stair: SwingStair in tree.get_nodes_in_group("swing_stairs"):
		for way: Dictionary in stair.ways:
			if (way["from"] == from and way["to"] == to) or (way["from"] == to and way["to"] == from):
				return true
	return false


## True when any swinging stair joins the two landings right now, and for long enough to cross.
static func is_joined(tree: SceneTree, from: Vector2i, to: Vector2i, needed: float) -> bool:
	for stair: SwingStair in tree.get_nodes_in_group("swing_stairs"):
		if stair.joins(from, to, needed):
			return true
	return false

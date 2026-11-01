class_name SwingStair
extends AnimatableBody2D

## A stair that swings, like the moving stairs of a great castle: a plank of brick hinged at a landing beside a stairwell, whose free end swings
## among landings on other floors. It stays at one for a while, swings to another, and stays there. Whoever stands on it is carried as it turns,
## and may be thrown off. It is a one-way platform, as the other stairs are: it can be walked up onto, and S drops through it.
## Where it is at any time follows the world's seed and how long the world has lasted alone, so every machine of a match sees it in the same place.

const HOLD_LEAST := 3.8  # seconds it stays at a landing, at the least and at the most: no two stays are alike
const HOLD_MOST := 7.0
const SWING_LEAST := 0.7  # seconds a swing takes
const SWING_MOST := 1.3
const OVERSHOOT := 1.1    # how hard a swing runs past its mark before it settles back (it goes a little over a twentieth beyond)
const SWAY := 4.0         # how far the free end rocks, up and down, while it rests
const THICKNESS := 45.25  # the fixed castle brick's band: two tiles tall, which across a slope of 45 degrees is this
const STATIONS := 10      # the points along its underside that are made uneven
const BRICK := preload("res://art/tiles/castle_brick.png")

var hinge := Vector2.ZERO          # where it is fastened, in the world
var ends: Array[Vector2] = []      # where its free end can be, in the world
var ways: Array = []               # for each of those, the {from, to} tiles of the landings it joins
var seed_value := 0
var seconds := 0.0                 # how long it has been in the world, which is the world's age: it counts it itself, so that it moves even while no one is watching

var _poses := PackedInt32Array()   # which end it is at in each stretch of time, made as far on as is needed
var _begins := PackedFloat32Array()  # when each stretch begins, in seconds; a stretch is a swing, then a stay
var _lengths := PackedFloat32Array()  # how long each stay is
var _swings := PackedFloat32Array()  # how long the swing at the start of each stretch takes
var _rng := RandomNumberGenerator.new()
var _shape := SegmentShape2D.new()
var _length := 0.0
var _way := 1.0                    # 1 when the free end is to the right of the hinge, -1 when it is to the left
var _underside := PackedFloat32Array()  # how thick it is at each station along it, as a share of THICKNESS: it is cut and worn, not a clean slab
var _tip_cut := Vector2.ZERO       # how much of its two ends is chipped off the underside: x at the hinge, y at the tip
var _sway_phase := 0.0


func _ready() -> void:
	add_to_group("swing_stairs")
	collision_layer = 16
	collision_mask = 0
	sync_to_physics = false
	z_index = 1
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_rng.seed = seed_value
	_sway_phase = _rng.randf() * TAU
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
		_lengths.append(_rng.randf_range(HOLD_LEAST, HOLD_MOST))
	return _swings[slot] + _lengths[slot]



## The index of the end it is held at in the stretch of time a moment falls in.
func pose_at(time: float) -> int:
	return _poses[_slot_at(time)]


## Where the free end is at a moment: at rest at one of the ends, rocking a little, or on its way from the last to the next, running a little past
## and settling back, as a heavy thing on a hinge does.
func _end_at(time: float) -> Vector2:
	var slot := _slot_at(time)
	var phase := time - _begins[slot]
	var rest := ends[_poses[slot]]
	if slot > 0 and phase < _swings[slot]:
		var along := phase / _swings[slot] - 1.0
		var eased := 1.0 + (OVERSHOOT + 1.0) * along * along * along + OVERSHOOT * along * along  # 0 at the start, 1 at the end, past 1 on the way
		return ends[_poses[slot - 1]].lerp(rest, eased) + Vector2(0.0, sin(time * 2.1 + _sway_phase) * SWAY)
	return rest + Vector2(0.0, sin(time * 2.1 + _sway_phase) * SWAY)


func _place(end: Vector2) -> void:
	var across := end - hinge
	_way = 1.0 if across.x >= 0.0 else -1.0
	_length = across.length()
	position = hinge
	rotation = _way * atan2(across.y, absf(across.x))
	_shape.a = Vector2(minf(_way * _length, 0.0), 0.0)  # from its left end to its right, so that the top is the side that holds
	_shape.b = Vector2(maxf(_way * _length, 0.0), 0.0)
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
		uvs.append(point / (BRICK.get_size() * 2.0))
	draw_colored_polygon(outline, Terrain.STONE_FILL)
	if not Geometry2D.triangulate_polygon(outline).is_empty():
		draw_polygon(outline, PackedColorArray([Color.WHITE]), uvs, BRICK)
	var closed := PackedVector2Array(outline)
	closed.append(outline[0])
	draw_polyline(closed, Terrain.RIM, 3.0)


## True when this stair joins the two landing tiles right now, and will go on joining them for long enough to cross: `needed` seconds of its stay
## are still to come. A stair that is swinging, or about to, joins nothing.
func joins(from: Vector2i, to: Vector2i, needed: float) -> bool:
	var slot := _slot_at(seconds)
	var swinging := slot > 0 and seconds - _begins[slot] < _swings[slot]
	if swinging or _begins[slot] + _stay_end(slot) - seconds < needed:
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

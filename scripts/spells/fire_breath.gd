class_name FireBreath
extends Node2D

## Fire Breath: a cone drawn with its point where the fire leaves you and its mouth the way it should spread. Fire
## pours out of the caster's mouth for about a second, like a flamethrower. The breath comes from wherever the mouth
## is: jump and it rises with you, turn round and it turns with you. Each puff of flame flies on its own once it has
## left the mouth, so the stream trails and bends as you move. It is ordinary fire, so the ground, stone walls and
## stop it (ice does not: it melts), and a Barrier keeps it off you.

const LIFE := 1.1          # how long the fire pours out
const TICK := 0.2          # how often it burns what it touches
const DAMAGE := 3
const MIN_SPREAD := 0.45   # radians: the narrowest and widest a cone can be
const MAX_SPREAD := 1.3
const MIN_REACH := 110.0
const MAX_REACH := 230.0
const PUFF_SPEED := 430.0
const PUFF_RATE := 28.0    # flame puffs per second
const FLAME_TAIL := 33.5   # the row of its frame the tail of the flame is on: this is the row that sits in the mouth
const FLAME_LENGTH := 40.0 # how long pimen's flame is in its 48 px frame, tail to head
const HIT_SCALE := 2.0     # the splash where the flame lands is drawn at twice its size
const HIT_GAP := 0.25      # the least time between one splash on a wall and the next
const DRAG := 1.2          # puffs slow as they spread out

var caster_node: Wizard
var aim := 0.0             # the drawn direction, for the way the caster faced when casting
var spread := 0.8
var reach := 160.0
var _age := 0.0
var _tick := 0.0
var _emit := 0.0
var _cast_facing := 1.0
var _mouth := Vector2.ZERO
var _puffs: Array = []     # each is {pos, vel, age, life, size, stopped}
var _ended := -1.0         # when the pouring stopped, and the flame began to die out
var _splashed := 0.0       # when a puff last splashed on a wall
var _glow: Node2D          # a warm light under the puffs, as every other fire has
var _light: PointLight2D   # and it lights the dark round the mouth


func _ready() -> void:
	add_to_group("fires")
	spread = clampf(spread, MIN_SPREAD, MAX_SPREAD)
	# A breath cast the other way turns the wizard round to face it.
	if is_instance_valid(caster_node) and absf(cos(aim)) > 0.2:
		caster_node.facing = signf(cos(aim))
	reach = clampf(reach, MIN_REACH, MAX_REACH)
	# Drawn as solid colour, not light, so the flames stay orange against any backdrop. The puffs live in world
	# space, so this node stays at the world's origin.
	position = Vector2.ZERO
	add_to_group("danger")
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # the flame is pixel art, turned and enlarged: no smoothing between its pixels
	_cast_facing = _facing()
	_mouth = _mouth_position()
	Sfx.play("fire_breath", _mouth)
	_glow = Node2D.new()
	_glow.material = Fx.additive()
	_glow.z_index = 3
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	_light = PointLight2D.new()
	_light.texture = Fx.tex("light_01")
	_light.texture_scale = 260.0 * 2.0 / Fx.TEX_SIZE
	_light.color = Color(1.0, 0.6, 0.25)
	_light.energy = 1.1
	_light.shadow_enabled = false
	add_child(_light)


func _physics_process(delta: float) -> void:
	_age += delta
	var pouring := _age < LIFE and _caster_alive()
	if not pouring and _ended < 0.0:
		_ended = _age
	if pouring:
		_mouth = _mouth_position()
		_emit += delta * PUFF_RATE
		while _emit >= 1.0:
			_emit -= 1.0
			_spawn_puff()
	_move_puffs(delta)
	_glow.queue_redraw()
	_light.position = _mouth + _puff_middle()
	_light.energy = 1.1 * clampf(float(_puffs.size()) / 6.0, 0.0, 1.0)
	_tick -= delta
	if _tick <= 0.0 and not _puffs.is_empty():
		_tick = TICK
		_burn()
	if not pouring and _puffs.is_empty():
		queue_free()
	queue_redraw()


func _caster_alive() -> bool:
	return is_instance_valid(caster_node) and not caster_node.dead


func _facing() -> float:
	if not is_instance_valid(caster_node) or caster_node.facing == 0.0:
		return 1.0
	return caster_node.facing


func _mouth_position() -> Vector2:
	return caster_node.mouth()


## The way the fire leaves the mouth now: the drawn direction, read from the way the wizard faced when casting and
## mirrored to face wherever the wizard faces now. Flames sent after a turn go the new way.
func _direction() -> Vector2:
	var drawn := Vector2.from_angle(aim)
	return Vector2(drawn.x * _cast_facing * _facing(), drawn.y)


func _spawn_puff() -> void:
	var velocity := _direction().rotated(randf_range(-0.5, 0.5) * spread) * PUFF_SPEED * randf_range(0.85, 1.1)
	var life := reach / PUFF_SPEED * 1.25
	_puffs.append({"pos": _mouth, "vel": velocity, "age": 0.0, "life": life, "size": randf_range(0.8, 1.25), "stopped": false})


## Each puff flies on until its time is up, or until it hits something solid, where it stops and flares.
func _move_puffs(delta: float) -> void:
	var space := get_world_2d().direct_space_state
	for puff in _puffs:
		puff["age"] += delta
		if puff["stopped"]:
			continue
		var step: Vector2 = puff["vel"] * delta
		var query := PhysicsRayQueryParameters2D.create(puff["pos"], puff["pos"] + step)
		query.collision_mask = 1  # the ground and stone walls
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and hit["collider"].is_in_group("ice"):
			hit = {}  # flame passes through ice and melts it
		if hit.is_empty():
			puff["pos"] += step
			puff["vel"] *= 1.0 - DRAG * delta
		else:
			puff["pos"] = hit["position"]
			puff["stopped"] = true
			if _age - _splashed >= HIT_GAP:
				_splashed = _age
				PixelFx.play_square(self, puff["pos"], "pimen_breath_hit", 16.0, HIT_SCALE, hit["normal"].angle())  # it splashes on the wall
			puff["age"] = maxf(puff["age"], puff["life"] * 0.6)  # flame splashed on a wall dies quickly
	_puffs = _puffs.filter(func(puff: Dictionary) -> bool: return puff["age"] < puff["life"])


## The radius a puff burns within: it grows as it spreads.
func _radius(puff: Dictionary) -> float:
	return lerpf(8.0, 30.0, clampf(puff["age"] / puff["life"], 0.0, 1.0)) * puff["size"]


## Burns everything a puff of flame is touching. The caster is never burnt by their own breath.
func _burn() -> void:
	for body in SpellTargets.all(get_tree()):
		if body == caster_node:
			continue
		var middle := SpellTargets.center_of(body)
		for puff in _puffs:
			if middle.distance_to(puff["pos"]) <= _radius(puff) + 16.0:
				SpellTargets.hurt(body, DAMAGE, "Fire")
				PixelFx.play_square(self, middle, "pimen_breath_hit", 16.0, HIT_SCALE, _direction().angle())  # and the flame lashes the one it burns
				break


## Near any flame, or just in front of the mouth while it pours, is dangerous.
func danger_at(point: Vector2) -> bool:
	if _age < LIFE and point.distance_to(_mouth + _direction() * reach * 0.5) < reach * 0.55:
		return true
	for puff in _puffs:
		if point.distance_to(puff["pos"]) < _radius(puff) + 12.0:
			return true
	return false


## Each puff is a pixel-art flame, growing as it spreads and dying out at the end of its flight.
func _draw() -> void:
	# One flame, from the mouth the way the breath goes: it takes light, burns steadily while the breath pours, and dies out when it stops.
	if not _puffs.is_empty():
		var flames := PixelFx.square_frames("pimen_breath")
		var frame := flames.get_frame_texture("default", _flame_frame(flames.get_frame_count("default")))
		var heading := _direction()
		var size := _flame_scale()
		draw_set_transform(_mouth, heading.angle(), Vector2(size, size if heading.x >= 0.0 else -size))
		draw_texture(frame, Vector2(-1.0, -FLAME_TAIL))  # its tail is 1 px in from the left of the frame
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _age < LIFE and _caster_alive():
		Fx.draw_glow(self, _mouth, 12.0, Color(1.0, 0.8, 0.35, 0.8))


## How big the flame is drawn: a whole number of times its size, the one that comes nearest to the reach of the breath.
func _flame_scale() -> float:
	return clampf(roundf(reach / FLAME_LENGTH), 3.0, 6.0)


## Which frame of the flame to show: the first two as it takes light, four that go round while it pours, and the rest as it dies out.
func _flame_frame(count: int) -> int:
	if _ended >= 0.0:
		return mini(6 + int((_age - _ended) * 14.0), count - 1)
	if _age < 0.15:
		return int(_age / 0.075)
	return 2 + int(_age * 12.0) % 4


## The glow of each flame, hot at the mouth and fainter as it spreads.
func _draw_glow() -> void:
	for puff in _puffs:
		var t: float = clampf(puff["age"] / puff["life"], 0.0, 1.0)
		Fx.draw_glow(_glow, puff["pos"], 18.0 + 14.0 * t, Color(1.0, 0.5, 0.15, 0.4 * (1.0 - t)))


## Where the light sits: partway along the flames from the mouth.
func _puff_middle() -> Vector2:
	if _puffs.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for puff in _puffs:
		sum += puff["pos"] - _mouth
	return sum / _puffs.size()


## Put out by water: the flames go out in steam where they were.
func quench() -> void:
	_age = LIFE
	for puff in _puffs:
		Fx.smoke(get_parent(), puff["pos"], Color(0.88, 0.92, 0.96, 0.5), 1, 16.0, 30.0)
	_puffs.clear()


## Where each puff of flame is now, in the world.
func flame_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for puff in _puffs:
		points.append(puff["pos"])
	return points

class_name FireBreath
extends Node2D

## Fire Breath: a cone drawn with its point where the fire leaves you and its mouth the way it should spread. Fire
## pours out of the caster's mouth for about a second, like a flamethrower. The breath comes from wherever the mouth
## is: jump and it rises with you, turn round and it turns with you. Each puff of flame flies on its own once it has
## left the mouth, so the stream trails and bends as you move. It is ordinary fire, so the ground, stone walls and
## ice stop it, and a Barrier keeps it off you.

const LIFE := 1.1          # how long the fire pours out
const TICK := 0.2          # how often it burns what it touches
const DAMAGE := 3
const MIN_SPREAD := 0.45   # radians: the narrowest and widest a cone can be
const MAX_SPREAD := 1.3
const MIN_REACH := 110.0
const MAX_REACH := 230.0
const PUFF_SPEED := 430.0
const PUFF_RATE := 40.0    # flame puffs per second
const DRAG := 1.2          # puffs slow as they spread out

var team := "player"
var caster_node: Node2D
var aim := 0.0             # the drawn direction, for the way the caster faced when casting
var spread := 0.8
var reach := 160.0
var _age := 0.0
var _tick := 0.0
var _emit := 0.0
var _cast_facing := 1.0
var _mouth := Vector2.ZERO
var _puffs: Array = []     # each is {pos, vel, age, life, size, stopped}


func _ready() -> void:
	spread = clampf(spread, MIN_SPREAD, MAX_SPREAD)
	# A breath cast the other way turns the wizard round to face it.
	if is_instance_valid(caster_node) and caster_node.is_in_group("player") and absf(cos(aim)) > 0.2:
		caster_node.set("_facing", signf(cos(aim)))
	reach = clampf(reach, MIN_REACH, MAX_REACH)
	# Drawn as solid colour, not light, so the flames stay orange against any backdrop. The puffs live in world
	# space, so this node stays at the world's origin.
	position = Vector2.ZERO
	add_to_group("danger")
	z_index = 4
	_cast_facing = _facing()
	_mouth = _mouth_position()
	Sfx.play("fire_breath", _mouth)


func _physics_process(delta: float) -> void:
	_age += delta
	var pouring := _age < LIFE and _caster_alive()
	if pouring:
		_mouth = _mouth_position()
		_emit += delta * PUFF_RATE
		while _emit >= 1.0:
			_emit -= 1.0
			_spawn_puff()
	_move_puffs(delta)
	_tick -= delta
	if _tick <= 0.0 and not _puffs.is_empty():
		_tick = TICK
		_burn()
	if not pouring and _puffs.is_empty():
		queue_free()
	queue_redraw()


func _caster_alive() -> bool:
	if not is_instance_valid(caster_node):
		return false
	if caster_node.has_method("is_dead"):
		return not caster_node.is_dead()
	return not caster_node.get("dead")


func _facing() -> float:
	var facing = caster_node.get("_facing") if is_instance_valid(caster_node) else null
	return facing if facing is float and facing != 0.0 else 1.0


func _mouth_position() -> Vector2:
	if caster_node.has_method("mouth"):
		return caster_node.mouth()
	return SpellTargets.center_of(caster_node)


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
		query.collision_mask = 1  # the ground, stone walls and ice
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			puff["pos"] += step
			puff["vel"] *= 1.0 - DRAG * delta
		else:
			puff["pos"] = hit["position"]
			puff["stopped"] = true
			puff["age"] = maxf(puff["age"], puff["life"] * 0.6)  # flame splashed on a wall dies quickly
	_puffs = _puffs.filter(func(puff: Dictionary) -> bool: return puff["age"] < puff["life"])


## The radius a puff burns within: it grows as it spreads.
func _radius(puff: Dictionary) -> float:
	return lerpf(8.0, 30.0, clampf(puff["age"] / puff["life"], 0.0, 1.0)) * puff["size"]


## Burns everything a puff of flame is touching. The caster is never burnt by their own breath.
func _burn() -> void:
	for body in SpellTargets.all(get_tree(), team):
		if body == caster_node:
			continue
		var middle := SpellTargets.center_of(body)
		for puff in _puffs:
			if middle.distance_to(puff["pos"]) <= _radius(puff) + 16.0:
				SpellTargets.hurt(body, DAMAGE, "Fire", team)
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
	var flames := PixelFx.frames("fire_puff", 14.0, true)
	var count := flames.get_frame_count("default")
	for puff in _puffs:
		var t: float = clampf(puff["age"] / puff["life"], 0.0, 1.0)
		var frame := flames.get_frame_texture("default", (int(puff["age"] * 30.0) + int(puff["size"] * 37.0)) % count)
		# Hot and yellow at the mouth, cooling to orange and red as it spreads.
		var colour := Color(1.0, 0.9, 0.6).lerp(Color(1.0, 0.45, 0.25), t)
		colour.a = 1.0 - t * t
		# The flame is turned to the way the breath is travelling, so it streams out of the mouth rather than standing up.
		var heading: Vector2 = puff["vel"]
		var turn := heading.angle() + PI * 0.5 if heading.length() > 1.0 else 0.0
		draw_set_transform(puff["pos"], turn, Vector2(2.0 if int(puff["size"] * 10.0) % 2 == 0 else -2.0, 2.0))
		draw_texture(frame, -frame.get_size() * Vector2(0.5, 0.75), colour)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _age < LIFE and _caster_alive():
		Fx.draw_glow(self, _mouth, 12.0, Color(1.0, 0.8, 0.35, 0.8))

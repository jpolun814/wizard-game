class_name SporePuff
extends Node2D

## Spore Puff: a cone drawn like Fire Breath's, with its point where the spores leave you and its mouth the way they
## should drift. Poison spores pour out of the caster's mouth for about a second, then hang and drift. Whoever breathes
## them takes damage a little at a time, whoever released them. Ground and walls stop them. Wind (Tornado, Gust) and water
## clear them.

const POUR := 0.9
const TICK := 0.5
const DAMAGE := 2
const MIN_SPREAD := 0.45
const MAX_SPREAD := 1.3
const MIN_REACH := 110.0
const MAX_REACH := 230.0
const SPEED := 260.0
const RATE := 26.0          # spore puffs per second
const DRAG := 1.4           # they slow quickly, then hang in the air
const LIFE := 4.5           # how long one puff lives
const FADE := 0.7           # how long it takes to thin away when the wind takes it
const TEXTURE_SIZE := 64.0

var caster_node: Node2D
var aim := 0.0
var spread := 0.8
var reach := 160.0
var _age := 0.0
var _tick := 0.0
var _emit := 0.0
var _cast_facing := 1.0
var _mouth := Vector2.ZERO
var _thinning := -1.0  # counts down once the wind has taken it
var _puffs: Array = []  # each is {pos, vel, born, age, size, stopped}
var _texture: Texture2D


func _ready() -> void:
	add_to_group("clouds")
	add_to_group("lasting")
	add_to_group("danger")
	position = Vector2.ZERO  # the puffs live in world space
	z_index = 3
	spread = clampf(spread, MIN_SPREAD, MAX_SPREAD)
	reach = clampf(reach, MIN_REACH, MAX_REACH)
	_texture = Fx.tex("smoke_01")
	if is_instance_valid(caster_node) and caster_node.is_in_group("player") and absf(cos(aim)) > 0.2:
		caster_node.facing = signf(cos(aim))
	_cast_facing = _facing()
	_mouth = _mouth_position()
	Sfx.play("snow", _mouth, -4.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _thinning >= 0.0:
		_thinning -= delta
		modulate.a = clampf(_thinning / FADE, 0.0, 1.0)
		if _thinning < 0.0:
			queue_free()
		return
	var pouring := _age < POUR and _caster_alive()
	if pouring:
		_mouth = _mouth_position()
		_emit += delta * RATE
		while _emit >= 1.0:
			_emit -= 1.0
			_spawn_puff()
	_move_puffs(delta)
	_tick -= delta
	if _tick <= 0.0 and not _puffs.is_empty():
		_tick = TICK
		_poison()
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
	if not is_instance_valid(caster_node) or caster_node.facing == 0.0:
		return 1.0
	return caster_node.facing


func _mouth_position() -> Vector2:
	if is_instance_valid(caster_node) and caster_node.has_method("mouth"):
		return caster_node.mouth()
	return SpellTargets.center_of(caster_node) if is_instance_valid(caster_node) else _mouth


## The way the spores leave the mouth now, mirrored to face wherever the wizard faces, as Fire Breath does.
func _direction() -> Vector2:
	var drawn := Vector2.from_angle(aim)
	return Vector2(drawn.x * _cast_facing * _facing(), drawn.y)


func _spawn_puff() -> void:
	var velocity := _direction().rotated(randf_range(-0.5, 0.5) * spread) * SPEED * (reach / 160.0) * randf_range(0.7, 1.1)
	_puffs.append({"pos": _mouth, "vel": velocity, "born": _mouth, "age": 0.0, "size": randf_range(0.8, 1.25), "stopped": false})


## Each puff drifts on, slowing, until it hangs in the air; a wall or the ground stops it where it hits.
func _move_puffs(delta: float) -> void:
	var space := get_world_2d().direct_space_state
	for puff in _puffs:
		puff["age"] += delta
		var step: Vector2 = puff["vel"] * delta
		var query := PhysicsRayQueryParameters2D.create(puff["pos"], puff["pos"] + step)
		query.collision_mask = 1
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			puff["pos"] += step
			puff["vel"] = (puff["vel"] * (1.0 - DRAG * delta)) + Vector2(0.0, -6.0 * delta)
		else:
			puff["pos"] = hit["position"]
			puff["vel"] = Vector2.ZERO
	_puffs = _puffs.filter(func(puff: Dictionary) -> bool: return puff["age"] < LIFE)


func _radius(puff: Dictionary) -> float:
	return lerpf(10.0, 30.0, clampf(puff["age"] / 1.2, 0.0, 1.0)) * puff["size"]


## Poisons everyone a puff is touching. A puff still close to where it left the mouth cannot hurt the caster, as with any shot.
func _poison() -> void:
	for body in SpellTargets.all(get_tree()):
		var middle := SpellTargets.center_of(body)
		for puff in _puffs:
			if body == caster_node and puff["pos"].distance_to(puff["born"]) < 60.0:
				continue
			if middle.distance_to(puff["pos"]) <= _radius(puff) + 8.0:
				SpellTargets.hurt(body, DAMAGE, "Flora")
				break


## The wind takes it: it thins away.
func dissipate() -> void:
	if _thinning < 0.0:
		_thinning = FADE


## The left and right edges of the spores, for a wind that has to be at it.
func span() -> Vector2:
	if _puffs.is_empty():
		return Vector2(_mouth.x, _mouth.x)
	var left: float = _puffs[0]["pos"].x
	var right := left
	for puff in _puffs:
		left = minf(left, puff["pos"].x)
		right = maxf(right, puff["pos"].x)
	return Vector2(left - 30.0, right + 30.0)


func danger_at(point: Vector2) -> bool:
	if _thinning >= 0.0:
		return false
	for puff in _puffs:
		if point.distance_to(puff["pos"]) < _radius(puff) + 8.0:
			return true
	return false


## Each puff is a soft green cloud that grows as it drifts and thins out towards the end of its life.
func _draw() -> void:
	for puff in _puffs:
		var t: float = clampf(puff["age"] / LIFE, 0.0, 1.0)
		var colour := Color(0.45, 0.8, 0.3, 0.55 * sin(PI * clampf(t * 1.15, 0.0, 1.0)))
		var half := _radius(puff) * 1.6
		draw_set_transform(puff["pos"], puff["age"] * 0.4 * (1.0 if puff["size"] > 1.0 else -1.0), Vector2.ONE)
		draw_texture_rect(_texture, Rect2(-half, -half, half * 2.0, half * 2.0), false, colour)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

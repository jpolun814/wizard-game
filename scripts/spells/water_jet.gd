class_name WaterJet
extends Node2D

## Water Jet: a cone drawn like Fire Breath's, with its point where the water leaves you and its mouth the way it should spray. A hard stream pours from the
## end of the caster's staff for a moment, like a hose. It does no harm. It pushes back whatever it hits (wizards, creatures, loose rocks, shots), leaves a wizard wet, puts
## out flames, and washes an oil slick away. The ground and stone walls stop it.

const LIFE := 1.4          # how long the water pours
const TICK := 0.1          # how often it works on what it touches
const MIN_SPREAD := 0.12   # a hose: far narrower than a breath
const MAX_SPREAD := 0.5
const MIN_REACH := 220.0
const MAX_REACH := 420.0
const DROP_SPEED := 980.0
const DROP_RATE := 220.0   # drops a second: a solid stream, not a spray of drops
const DRAG := 0.5
const PUSH := 760.0        # the speed it shoves a wizard along: a wizard on the ground can only just walk against it, one in the air is carried
const PUSH_UP := 140.0      # and a little up, so a wizard is lifted off the ground
const MOB_PUSH := 620.0

var _dice := Dice.branch()  # from the cast
var caster: Wizard
var aim := 0.0
var spread := 0.5
var reach := 190.0
var _age := 0.0
var _tick := 0.0
var _emit := 0.0
var _cast_facing := 1.0
var _mouth := Vector2.ZERO
var _drops: Array = []  # each is {pos, vel, age, life, size, stopped}
var _turned := {}       # the shots already turned, so each is turned once
var _ended := -1.0


func _ready() -> void:
	if is_nan(aim) or is_nan(spread) or is_nan(reach):
		aim = 0.0 if is_nan(aim) else aim
		spread = MIN_SPREAD if is_nan(spread) else spread
		reach = MIN_REACH if is_nan(reach) else reach
	spread = clampf(spread, MIN_SPREAD, MAX_SPREAD)
	reach = clampf(reach, MIN_REACH, MAX_REACH)
	if is_instance_valid(caster) and absf(cos(aim)) > 0.2:
		caster.facing = signf(cos(aim))
	position = Vector2.ZERO  # the drops live in world space
	add_to_group("lasting")
	add_to_group("waters")
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cast_facing = _facing()
	_mouth = caster.launch_tip() if is_instance_valid(caster) else global_position
	Sfx.cue("Water Jet", "jet", _mouth)


func _physics_process(delta: float) -> void:
	_age += delta
	var pouring := _age < LIFE and is_instance_valid(caster) and not caster.dead
	if not pouring and _ended < 0.0:
		_ended = _age
	if pouring:
		caster.thrust(0.15)  # the staff stays pointed out while the water pours
		_mouth = caster.tip()
		_emit += delta * DROP_RATE
		var born := int(_emit)
		for k in born:
			_spawn_drop(delta * (1.0 - float(k) / born))  # spread along the way it has flown since the last frame: a stream, not clumps
		_emit -= born
	_move_drops(delta)
	_tick -= delta
	if _tick <= 0.0 and not _drops.is_empty():
		_tick = TICK
		_work()
	if not pouring and _drops.is_empty():
		queue_free()
	queue_redraw()


func _facing() -> float:
	if not is_instance_valid(caster) or caster.facing == 0.0:
		return 1.0
	return caster.facing


## The way the water leaves the mouth now: the drawn direction, mirrored to face wherever the wizard faces now.
func _direction() -> Vector2:
	var drawn := Vector2.from_angle(aim)
	return Vector2(drawn.x * _cast_facing * _facing(), drawn.y)


func _spawn_drop(head_start: float) -> void:
	var velocity := _direction().rotated(_dice.randf_range(-0.5, 0.5) * spread) * DROP_SPEED * _dice.randf_range(0.85, 1.1)
	_drops.append({"pos": _mouth + velocity * head_start, "vel": velocity, "age": 0.0, "life": reach / DROP_SPEED * 1.3, "size": _dice.randf_range(0.8, 1.3), "stopped": false})


func _move_drops(delta: float) -> void:
	var space := get_world_2d().direct_space_state
	for drop in _drops:
		drop["age"] += delta
		if drop["stopped"]:
			continue
		var step: Vector2 = drop["vel"] * delta
		var query := PhysicsRayQueryParameters2D.create(drop["pos"], drop["pos"] + step)
		query.collision_mask = 1  # the ground and stone walls
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			drop["pos"] += step
			drop["vel"] *= 1.0 - DRAG * delta
			drop["vel"].y += 200.0 * delta  # water falls
		else:
			drop["pos"] = hit["position"]
			drop["stopped"] = true
			drop["age"] = maxf(drop["age"], drop["life"] * 0.7)
			if Dice.looks.randf() < 0.25:
				Fx.burst(get_parent(), drop["pos"], Color(0.75, 0.9, 1.0, 0.9), 3, 70.0, 0.3, false)
	_drops = _drops.filter(func(drop: Dictionary) -> bool: return drop["age"] < drop["life"])


func _radius(drop: Dictionary) -> float:
	return lerpf(14.0, 34.0, clampf(drop["age"] / drop["life"], 0.0, 1.0)) * drop["size"]


## Whether a drop of the stream is at a point (Elements puts out whatever burns there, a flare included).
func wets(point: Vector2) -> bool:
	for drop in _drops:
		if not drop["stopped"] and drop["age"] > 0.1 and point.distance_to(drop["pos"]) < _radius(drop) + 14.0:
			return true
	return false


## What the stream does to whatever the drops touch.
func _work() -> void:
	var heading := _direction().normalized()
	for body in SpellTargets.all(get_tree()):
		if body == caster:
			continue
		var middle := SpellTargets.center_of(body)
		for drop in _drops:
			if drop["stopped"] or middle.distance_to(drop["pos"]) > _radius(drop) + 16.0:
				continue
			if body.is_in_group("mobs"):
				body.knock_back(heading * MOB_PUSH)
			else:
				body.push(Vector2(heading.x * PUSH, minf(heading.y * PUSH, 0.0) - PUSH_UP))
			break
	var tree := get_tree()
	for drop in _drops:
		var at: Vector2 = drop["pos"]
		for rock in tree.get_nodes_in_group("rocks"):
			if rock.global_position.distance_to(at) < _radius(drop) + 20.0:
				rock.push(heading * PUSH)
		for shot in tree.get_nodes_in_group("shots"):
			if not is_instance_valid(shot) or shot.global_position.distance_to(at) > _radius(drop) + 14.0:
				continue
			if shot.is_in_group("fires"):
				continue  # (water puts a fire shot out: see Elements)
			elif not _turned.has(shot) and shot.has_method("reflect"):
				_turned[shot] = true
				shot.reflect(heading)


## The water is drawn as the ponds and the Geyser draw theirs (Pond.WATER_*): a solid body shaded from light on its upper side to dark on its lower, with a bright
## edge, running out of the staff along the way the water flies and widening as it goes, and the droplets of water flung off it and the mist about it.
func _draw() -> void:
	if _drops.is_empty():
		return
	var front := 0.0
	for drop in _drops:
		if not drop["stopped"]:
			front = maxf(front, (drop["pos"] - _mouth).length())
	front = minf(front, reach)
	var heading := _direction().normalized()
	if front > 6.0:
		_draw_body(heading, front)
	var droplet := Fx.pixel_drop()
	var mist := Fx.tex("smoke_01")
	for drop in _drops:
		var t: float = clampf(drop["age"] / drop["life"], 0.0, 1.0)
		var scale_up := 1.0 if drop["size"] < 1.1 else 2.0  # whole times the picture, so the pixels stay pixels
		var spot: Vector2 = (drop["pos"]).round()
		draw_texture_rect(droplet, Rect2(spot - Vector2(2.0, 2.5) * scale_up, Vector2(4.0, 5.0) * scale_up), false, Color(1.0, 1.0, 1.0, 0.95 * (1.0 - t * 0.7)))
		if int(drop["pos"].x + drop["pos"].y) % 4 == 0:
			var puff := 12.0 + 18.0 * t
			draw_texture_rect(mist, Rect2(drop["pos"] - Vector2(puff, puff), Vector2(puff, puff) * 2.0), false, Color(0.85, 0.95, 1.0, 0.18 * (1.0 - t)))


## The stream itself: a ribbon along the path the water takes (it sags a little), `front` long. It begins as a point at the gem, swells, thins away at its free
## end, and stops at the ground or a wall, where it splashes.
func _draw_body(heading: Vector2, front: float) -> void:
	var fade := 1.0 if _ended < 0.0 else clampf(1.0 - (_age - _ended) / 0.35, 0.0, 1.0)
	var steps := 18
	var normal := Vector2(-heading.y, heading.x)
	if normal.y > 0.0:
		normal = -normal  # the side that faces up is the lit side
	var space := get_world_2d().direct_space_state
	var centers := PackedVector2Array()
	var spot := _mouth
	var step := front / steps
	var blocked := false
	centers.append(spot)
	for k in steps:
		var u := float(k + 1) / steps
		var next := _mouth + heading * step * (k + 1) + Vector2(0.0, u * u * front * 0.045)
		var query := PhysicsRayQueryParameters2D.create(spot, next)
		query.collision_mask = 1  # the ground and stone walls
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			centers.append(hit["position"])
			blocked = true
			break
		centers.append(next)
		spot = next
	var count := centers.size()
	var widths := PackedFloat32Array()
	var alphas := PackedFloat32Array()
	for k in count:
		var u := float(k) / maxf(count - 1, 1)
		var span := float(k) / steps
		var width := (4.0 + 26.0 * pow(span, 0.5)) + sin(_age * 30.0 + span * 8.0) * 2.0 * minf(span * 4.0, 1.0)
		var alpha := clampf(0.45 + span * 6.0, 0.0, 1.0) * fade
		if not blocked:
			width *= 1.0 - 0.75 * smoothstep(0.7, 1.0, u)  # the free end thins away
			alpha *= 1.0 - 0.85 * smoothstep(0.75, 1.0, u)
		widths.append(maxf(width, 4.0))
		alphas.append(alpha)
	WaterPixels.stream(self, centers, widths, alphas, _age)
	var glow := Fx.tex("light_01")  # a small bright burst where it leaves the gem, so it comes out of it
	draw_texture_rect(glow, Rect2(_mouth - Vector2(14, 14), Vector2(28, 28)), false, Color(0.75, 0.92, 1.0, 0.8 * fade))
	if blocked:  # and where it strikes
		var end := centers[count - 1]
		draw_texture_rect(glow, Rect2(end - Vector2(20, 20), Vector2(40, 40)), false, Color(0.8, 0.93, 1.0, 0.6 * fade))

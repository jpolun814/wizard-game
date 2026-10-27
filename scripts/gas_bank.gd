class_name GasBank
extends Area2D

## A bank of poison gas lying in a passage from the floor to the roof. Whoever is in it is poisoned every moment, and a
## Barrier keeps it off, as does holding your breath (the Chant of the Deep Breath). Wind thins it away (a Gust, a Tornado), and fire burns it off.

const TICK := 0.25
const DAMAGE := 15
const FADE := 0.8

var column := 0                    # the first column it fills
var floors := PackedInt32Array()  # the floor of each column, in rows
var tops := PackedInt32Array()    # and the roof over it
var box := Rect2()                # the space it fills, in the world: all of it, which on a slope is more than it fills
var _points := PackedVector2Array()
var _tick := 0.0
var _thinning := -1.0
var _emitter: CPUParticles2D


func _ready() -> void:
	add_to_group("clouds")
	add_to_group("danger")
	collision_mask = 6  # the player and enemies
	var t := float(ArenaGen.TILE)
	var low := tops[0]
	var high := floors[0]
	for k in floors.size():
		low = mini(low, tops[k])
		high = maxi(high, floors[k])
	box = Rect2(column * t, low * t, floors.size() * t, (high - low) * t)
	global_position = box.get_center()  # where the wind looks for it
	for k in floors.size():
		var shape := CollisionShape2D.new()  # a shape for each column, so the gas lies as the passage does on a slope
		var rect := RectangleShape2D.new()
		rect.size = Vector2(t, (floors[k] - tops[k]) * t)
		shape.shape = rect
		shape.position = Vector2((column + k + 0.5) * t, (floors[k] + tops[k]) * 0.5 * t) - global_position
		add_child(shape)
		for j in 3:
			_points.append(Vector2((column + k + 0.5) * t + (j - 1) * 10.0, lerpf(tops[k], floors[k], (j + 0.5) / 3.0) * t))
	_emitter = CPUParticles2D.new()
	_emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	var local := PackedVector2Array()
	for point in _points:
		local.append(point - global_position)
	_emitter.emission_points = local
	_emitter.amount = clampi(floors.size() * 6, 20, 90)
	_emitter.lifetime = 3.0
	_emitter.preprocess = 3.0
	_emitter.direction = Vector2.UP
	_emitter.spread = 180.0
	_emitter.initial_velocity_min = 4.0
	_emitter.initial_velocity_max = 14.0
	_emitter.gravity = Vector2.ZERO
	_emitter.angle_min = -180.0
	_emitter.angle_max = 180.0
	_emitter.angular_velocity_min = -20.0
	_emitter.angular_velocity_max = 20.0
	_emitter.texture = Fx.tex("smoke_04")
	_emitter.scale_amount_min = 64.0 / Fx.TEX_SIZE
	_emitter.scale_amount_max = 110.0 / Fx.TEX_SIZE
	var ramp := Gradient.new()
	var green := Color(0.42, 0.62, 0.18)
	ramp.colors = PackedColorArray([Color(green, 0.0), Color(green, 0.62), Color(green, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	_emitter.color_ramp = ramp
	_emitter.z_index = 3
	add_child(_emitter)
	_emitter.emitting = true


func _physics_process(delta: float) -> void:
	if _thinning >= 0.0:
		_thinning -= delta
		modulate.a = clampf(_thinning / FADE, 0.0, 1.0)
		if _thinning < 0.0:
			queue_free()
		return
	if _burning():
		# The gas catches and burns off in a flash.
		Fx.burst(get_parent(), box.get_center(), Color("#ffb040"), 24, 160.0, 0.5, true)
		Sfx.play("fire_hit", box.get_center(), -4.0)
		dissipate()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	for body in get_overlapping_bodies():
		if not SpellTargets.affects(body):
			continue
		if body.is_in_group("mobs"):
			if body.KINDS[body.kind]["role"] != "flyer":
				body.take_damage(DAMAGE, "Flora")
		elif not body.holding_breath():  # whoever holds their breath is not poisoned
			body.take_damage(DAMAGE, false, true)  # no grace between breaths, but a Barrier keeps it off


## True when a fire touches the gas.
func _burning() -> bool:
	for fire in SpellTargets.fire_points(get_tree()):
		var at: Vector2 = fire["at"]
		for point in _points:
			if at.distance_to(point) < maxf(fire["size"], 0.0) + 36.0:
				return true
	return false


## The left and right edges of the gas, for a wind that has to be at it.
func span() -> Vector2:
	return Vector2(box.position.x, box.end.x)


## The wind takes it: it thins away.
func dissipate() -> void:
	if _thinning < 0.0:
		_thinning = FADE
		_emitter.emitting = false

class_name Blizzard
extends SpellEffect

## Snow falling from clouds along the drawn line down to the ground under it, under a faint white wash. Anything in it
## is slowed, and stays slowed for a moment after leaving. A lasting blizzard (the spell) snows until it is put out:
## what lands builds up into a pile that settles like real snow, can be walked on, and is melted by fire. A passing
## fall (an ice enemy's trail) lasts a few seconds and leaves no pile.

const CHILL_TO_FREEZE := 5.0  # seconds in the snow before the cold takes hold
const CHILL_FADE := 1.5       # chill leaves this many times as fast as it comes, once out of the snow
const IMMUNE_FOR := 1.5       # seconds after the ice thaws that the cold cannot take hold again
const FROST_FROM := 0.2       # the share of the chill at which frost starts to show on a body
const TRAIL_LIFE := 6.0
const SLOW_SECONDS := 2.0
const STEP := 6.0  # the ground under the snow is measured, and the pile kept, in columns this wide
const PILE_GROW := 2.0  # landed snow builds up this many pixels a second, at most up to the clouds
const REPOSE := 4.0  # the steepest a heap may be, in pixels of height from one column to the next, before it slides
const MELT_RADIUS := 40.0  # fire melts snow this far from itself
const PILE_MELT := 35.0  # pixels a second a flame melts at its hottest
const SNOW_TOP := -50.0  # where the flakes start, just under the clouds
const CLOUDS := [preload("res://art/props/cloud_snow_big.png"), preload("res://art/props/cloud_snow_small_1.png"),
		preload("res://art/props/cloud_snow_small_2.png")]

var polygon := PackedVector2Array()  # the band along the drawn line, from its left end; set before setup
var lasting := true
var _floors := PackedFloat32Array()  # the ground under each column, relative to the line
var _pile := PackedFloat32Array()  # how deep the landed snow is in each column
var _pile_shapes: Array[CollisionShape2D] = []
var _shape_heights := PackedFloat32Array()  # the height each column's solid shape was last given
var _pile_timer := 0.0
var _dissipating := false
var _chill := {}  # body -> seconds of cold it has taken, for the lasting storm only
var _frozen_here := {}  # body -> true, for the bodies this storm has frozen, so the end of their ice is noticed


func _begin(origin: Vector2, _aim_angle: float) -> void:
	add_to_group("clouds")
	if lasting:
		_life = INF
		add_to_group("lasting")
		add_to_group("danger")
	else:
		_life = TRAIL_LIFE
	_floors = _measure_ground()
	_pile.resize(_floors.size())
	_pile.fill(0.0)
	var band := ConvexPolygonShape2D.new()
	band.points = polygon
	_add_shape(band)
	if lasting:
		_build_pile_body()
	Sfx.play("snow", origin)


func _act(delta: float) -> void:
	if lasting:
		_grow_pile(delta)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		SpellTargets.douse(get_tree(), global_position + Vector2(_width() * 0.5, 60.0), _width() * 0.5 + 20.0)  # snow puts out flames beneath it
	var inside := {}
	for body in get_overlapping_bodies():
		if not SpellTargets.affects(body):
			continue
		if body.is_in_group("mobs"):
			body.apply_slow(SLOW_SECONDS)
		else:
			body.apply_debuff("slow", SLOW_SECONDS)
		inside[body] = true
	if lasting:
		for body in SpellTargets.all(get_tree()):
			if not inside.has(body) and SpellTargets.affects(body) and _snowed_on(body):
				inside[body] = true  # the snow falls the whole way down to the ground, not only where the clouds are
				if body.is_in_group("mobs"):
					body.apply_slow(SLOW_SECONDS)
				else:
					body.apply_debuff("slow", SLOW_SECONDS)
		_take_the_cold(inside, delta)


## The cold takes hold of whoever stays in the snow, and lets go of whoever leaves it. Enough of it freezes a body in ice, as an Ice Prison does,
## and when that ice thaws there is a moment in which the cold cannot take hold again.
func _take_the_cold(inside: Dictionary, delta: float) -> void:
	for body in _frozen_here.keys():
		if not is_instance_valid(body):
			_frozen_here.erase(body)
		elif not body.is_frozen():
			_frozen_here.erase(body)
			body.set_meta("cold_immune_until", Engine.get_physics_frames() + int(IMMUNE_FOR * Engine.physics_ticks_per_second))  # (counted in frames of the game, which run as fast or slow as it does)
			_chill.erase(body)
	for body in inside:
		if _frozen_here.has(body) or body.is_frozen() or _is_immune(body):
			continue
		_chill[body] = float(_chill.get(body, 0.0)) + delta
		if float(_chill[body]) >= CHILL_TO_FREEZE:
			_freeze(body)
	for body in _chill.keys():
		if not is_instance_valid(body):
			_chill.erase(body)
		elif not inside.has(body):
			_chill[body] = float(_chill[body]) - delta * CHILL_FADE
			if float(_chill[body]) <= 0.0:
				_chill.erase(body)


## True while the cold cannot take hold of this body: its ice has only just thawed, or it is made of ice itself.
func _is_immune(body: Node2D) -> bool:
	if body.is_in_group("mobs") and body.shrugs_off_cold():
		return true
	return Engine.get_physics_frames() < int(body.get_meta("cold_immune_until", 0))


## Freezes a body solid in a block of ice round it, as an Ice Prison drawn tightly round it would.
func _freeze(body: Node2D) -> void:
	var prison := IcePrison.new()
	var middle := SpellTargets.center_of(body)
	prison.rect = Rect2(middle - Vector2(14.0, 20.0), Vector2(28.0, 40.0))  # only this body is inside it
	get_parent().add_child(prison)
	_frozen_here[body] = true
	_chill.erase(body)


## True when this body stands under the clouds, in the column of falling snow, with nothing solid between it and them.
func _snowed_on(body: Node2D) -> bool:
	var at := SpellTargets.center_of(body)
	if not danger_at(at):
		return false
	var top := Vector2(at.x, global_position.y + 60.0)
	if top.y >= at.y:
		return true
	var query := PhysicsRayQueryParameters2D.create(top, at, 1)  # terrain, stone and ice stop snow; bodies do not
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## True where the snow falls on a wizard standing in it, for the wizards that step out of danger.
func danger_at(point: Vector2) -> bool:
	if not lasting or _floors.is_empty():
		return false
	var from := global_position.x
	if point.x < from or point.x > from + _width():
		return false
	var column := clampi(int((point.x - from) / STEP), 0, _floors.size() - 1)
	return point.y > global_position.y - 60.0 and point.y < global_position.y + _floors[column]


func _width() -> float:
	return polygon[2].x


## The right edge of the clouds as they are drawn: the snow falls no further than this.
func _cloud_right() -> float:
	var x := -10.0
	var i := 0
	var edge := 0.0
	while x < _width() + 10.0:
		var cloud: Texture2D = CLOUDS[i % CLOUDS.size()]
		edge = x + cloud.get_width()
		x += cloud.get_width() * 0.7
		i += 1
	return maxf(edge, _width())


func _cloud_bottom() -> float:
	var tallest := 0.0
	for cloud in CLOUDS:
		tallest = maxf(tallest, cloud.get_height())
	return -60.0 + 0.4 * tallest


## The ground height (relative to the line) under each column, from the line's left end to the clouds' right edge.
func _measure_ground() -> PackedFloat32Array:
	var floors := PackedFloat32Array()
	var x := 0.0
	while x <= _cloud_right():
		floors.append(SpellTargets.solid_below(get_world_2d(), global_position + Vector2(x, -40)).y - global_position.y)
		x += STEP
	return floors


## Snow lands on every column, slides downhill until no slope is steeper than REPOSE, and melts near fire.
func _grow_pile(delta: float) -> void:
	var cloud_bottom := _cloud_bottom()
	for c in _pile.size():
		_pile[c] = minf(_pile[c] + PILE_GROW * delta, maxf(_floors[c] - cloud_bottom, 0.0))
	for c in _pile.size() - 1:
		var drop := _pile[c] - _pile[c + 1]
		if absf(drop) > REPOSE:
			var flow := (absf(drop) - REPOSE) * 0.25 * signf(drop)
			_pile[c] -= flow
			_pile[c + 1] += flow
	# Each column melts at the rate of the hottest flame near it, once: many puffs over one column do not add up.
	var melt := PackedFloat32Array()
	melt.resize(_pile.size())
	melt.fill(0.0)
	var reach := Rect2(global_position + Vector2(-50, -100), Vector2(_width() + 100, 230))
	for fire in SpellTargets.fire_points(get_tree()):
		if not reach.has_point(fire["at"]):
			continue
		var x: float = fire["at"].x - global_position.x
		for c in range(maxi(ceili((x - MELT_RADIUS) / STEP), 0), mini(floori((x + MELT_RADIUS) / STEP) + 1, _pile.size())):  # (only the columns it reaches)
			var distance := absf(c * STEP - x)
			if distance < MELT_RADIUS:
				melt[c] = maxf(melt[c], PILE_MELT * fire["heat"] * (1.0 - distance / MELT_RADIUS))
	for c in _pile.size():
		_pile[c] = maxf(_pile[c] - melt[c] * delta, 0.0)
	_pile_timer -= delta
	if _pile_timer <= 0.0:
		_pile_timer = 0.1
		_sync_pile_body()


## The landed snow is solid: one stretch per column, which follows the height of the pile.
func _build_pile_body() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1  # like the ground: walkers and the player stand on it
	body.collision_mask = 0
	add_child(body)
	for c in _floors.size():
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.disabled = true
		body.add_child(shape)
		_pile_shapes.append(shape)


func _sync_pile_body() -> void:
	if _shape_heights.size() != _pile_shapes.size():
		_shape_heights.resize(_pile_shapes.size())
		_shape_heights.fill(-10.0)
	for c in _pile_shapes.size():
		var shape := _pile_shapes[c]
		var off := _pile[c] < 1.0
		if off:
			if not shape.disabled:
				shape.disabled = true
				_shape_heights[c] = -10.0
		elif absf(_pile[c] - _shape_heights[c]) >= 1.0:  # (the physics engine is told only about a column that has changed by a pixel)
			shape.disabled = false
			(shape.shape as RectangleShape2D).size = Vector2(STEP, _pile[c])
			shape.position = Vector2(c * STEP + STEP * 0.5, _floors[c] - _pile[c] * 0.5)
			_shape_heights[c] = _pile[c]


## The clouds along the top, a white wash down to the ground, the flakes, and the pile that has landed.
func _draw() -> void:
	var fade := _fade()
	var grow := clampf(_age / 0.4, 0.0, 1.0)
	var x := -10.0
	var i := 0
	while x < _width() + 10.0:
		var cloud: Texture2D = CLOUDS[i % CLOUDS.size()]
		var bob := roundf(sin(_age * 0.8 + i) * 2.0)
		var at := Vector2(x, -60.0 - cloud.get_height() * 0.6 + bob)
		draw_texture(cloud, at + Vector2(3.0, 7.0), Color(0.34, 0.4, 0.55, 0.8 * fade * grow))  # the dark underside of the cloud, a little below it
		draw_texture(cloud, at, Color(0.7, 0.76, 0.9, fade * grow))  # storm cloud grey, not paper white
		x += cloud.get_width() * 0.7
		i += 1
	# A haze of snow under the clouds that is thickest up under them and thins toward the ground and at both sides, so the storm has no
	# edges to it, as a box would.
	var across := maxf(float(_floors.size() - 1) * STEP, 1.0)
	for c in _floors.size() - 1:
		var x0 := c * STEP
		var x1 := (c + 1) * STEP
		var side0 := smoothstep(0.0, 70.0, x0) * smoothstep(0.0, 70.0, across - x0)
		var side1 := smoothstep(0.0, 70.0, x1) * smoothstep(0.0, 70.0, across - x1)
		var strip := PackedVector2Array([Vector2(x0, SNOW_TOP), Vector2(x1, SNOW_TOP), Vector2(x1, _floors[c + 1]), Vector2(x0, _floors[c])])
		var haze := PackedColorArray([Color(0.78, 0.86, 1.0, 0.2 * side0 * fade * grow), Color(0.78, 0.86, 1.0, 0.2 * side1 * fade * grow), Color(0.85, 0.92, 1.0, 0.03 * side1 * fade * grow), Color(0.85, 0.92, 1.0, 0.03 * side0 * fade * grow)])
		draw_polygon(strip, haze)
	# Flakes fall slanting with the wind, which gusts, each at a speed of its own by how far off it is, and settle on the top of the pile.
	var span := maxf((_floors.size() - 1) * STEP, 1.0)
	var fall := 0.0
	for f in _floors:
		fall += f - SNOW_TOP
	fall /= maxf(float(_floors.size()), 1.0)
	var gust := sin(_age * 0.35) * 16.0 + sin(_age * 1.3) * 5.0
	for k in clampi(int(_width() * fall / 30.0), 30, 1100):
		var depth := 0.35 + 0.65 * float(k % 3) / 2.0
		var rx := fposmod(sin(k * 12.9898) * 43758.5453, 1.0)  # where each flake begins is scattered, so the snow is not laid out in rows and columns
		var ry := fposmod(sin(k * 78.233 + 3.1) * 24634.6345, 1.0)
		var drift := fmod(rx * span + _age * (7.0 + 14.0 * depth), span)
		var fx := floorf(clampf(drift + sin(_age * (0.7 + depth) + k * 1.7) * (6.0 + 10.0 * depth) + gust * depth, 0.0, span))
		var column := clampi(int(fx / STEP), 0, _floors.size() - 1)
		var landing := _floors[column] - _pile[column]
		var fy := floorf(fmod(_age * (38.0 + 80.0 * depth) + ry * (landing - SNOW_TOP), landing - SNOW_TOP) + SNOW_TOP)
		var size := 2.0 if depth < 0.7 else 4.0  # whole pixel blocks
		var edge := smoothstep(0.0, 50.0, fx) * smoothstep(0.0, 50.0, span - fx)
		var a := fade * grow * edge * clampf((fy - SNOW_TOP) / 14.0, 0.0, 1.0) * (0.5 + 0.5 * depth)
		draw_rect(Rect2(fx, fy, size, size), Color(0.92 + 0.08 * depth, 0.96 + 0.04 * depth, 1.0, a))
	for c in _pile.size():
		if _pile[c] > 0.5:
			draw_rect(Rect2(c * STEP, _floors[c] - _pile[c], STEP + 1.0, _pile[c]), Color(0.92, 0.96, 1.0, fade * grow))
	for body in _chill:
		if is_instance_valid(body):
			_draw_frost(body, float(_chill[body]) / CHILL_TO_FREEZE)


## Frost creeping up a body from its feet as the cold takes hold: pixel squares of ice that crowd in and climb as the chill grows, so the
## freezing is seen coming.
func _draw_frost(body: Node2D, share: float) -> void:
	if share < FROST_FROM:
		return
	var reach := clampf((share - FROST_FROM) / (1.0 - FROST_FROM), 0.0, 1.0)
	var feet := body.global_position - global_position
	var height := 8.0 + 44.0 * reach
	var count := int(6.0 + 40.0 * reach)
	var seed_at := int(absf(body.global_position.x)) % 7
	for k in count:
		var row := fmod(float(k * 37 + seed_at * 11), 100.0) / 100.0
		var across := fmod(float(k * 53 + seed_at * 17), 100.0) / 100.0 - 0.5
		var at := feet + Vector2(roundf(across * 30.0), -roundf(row * height))
		var size := 4.0 if k % 3 == 0 else 2.0
		draw_rect(Rect2(at - Vector2.ONE, Vector2(size + 2.0, size + 2.0)), Color(0.16, 0.38, 0.72, 0.85))  # an edge of deep blue, so it stands out from the flakes
		draw_rect(Rect2(at, Vector2(size, size)), Color(0.6, 0.92, 1.0, 1.0))
	draw_rect(Rect2(feet + Vector2(-17.0, -3.0), Vector2(34.0, 3.0)), Color(0.6, 0.92, 1.0, 0.9 * reach))  # a rim of ice round the feet that thickens


## Where the snow reaches, left and right, in the world.
func span() -> Vector2:
	return Vector2(global_position.x, global_position.x + _width())


## The wind of a tornado thins the cloud away until it is gone.
func dissipate() -> void:
	if _dissipating:
		return
	_dissipating = true
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 1.2)
	fade.tween_callback(queue_free)

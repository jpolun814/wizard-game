class_name Blizzard
extends SpellEffect

## Snow falling from clouds along the drawn line down to the ground under it, under a faint white wash. Anything in it
## is slowed, and stays slowed for a moment after leaving. A lasting blizzard (the spell) snows until the wave ends:
## what lands builds up into a pile that settles like real snow, can be walked on, and is melted by fire. A passing
## fall (an ice enemy's trail) lasts a few seconds and leaves no pile.

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
var _pile_timer := 0.0
var _dissipating := false


func _begin(origin: Vector2, _aim_angle: float) -> void:
	add_to_group("clouds")
	if lasting:
		_life = INF
		add_to_group("lasting")
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
	if team == "player":
		Sfx.play("snow", origin)


func _act(delta: float) -> void:
	if lasting:
		_grow_pile(delta)
	for body in get_overlapping_bodies():
		if not SpellTargets.affects(body, team):
			continue
		if body.is_in_group("mobs"):
			body.apply_slow(SLOW_SECONDS)
		else:
			body.apply_debuff("slow", SLOW_SECONDS)


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
		for c in _pile.size():
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
	for c in _pile_shapes.size():
		var shape := _pile_shapes[c]
		shape.disabled = _pile[c] < 1.0
		if not shape.disabled:
			(shape.shape as RectangleShape2D).size = Vector2(STEP, _pile[c])
			shape.position = Vector2(c * STEP + STEP * 0.5, _floors[c] - _pile[c] * 0.5)


## The clouds along the top, a white wash down to the ground, the flakes, and the pile that has landed.
func _draw() -> void:
	var fade := _fade()
	var grow := clampf(_age / 0.4, 0.0, 1.0)
	var x := -10.0
	var i := 0
	while x < _width() + 10.0:
		var cloud: Texture2D = CLOUDS[i % CLOUDS.size()]
		var bob := roundf(sin(_age * 0.8 + i) * 2.0)
		draw_texture(cloud, Vector2(x, -60.0 - cloud.get_height() * 0.6 + bob), Color(1, 1, 1, fade * grow))
		x += cloud.get_width() * 0.7
		i += 1
	var wash := PackedVector2Array()
	for c in _floors.size():
		wash.append(Vector2(c * STEP, _floors[c]))
	for c in range(_floors.size() - 1, -1, -1):
		wash.append(Vector2(c * STEP, SNOW_TOP))
	draw_colored_polygon(wash, Color(1.0, 1.0, 1.0, 0.14 * fade * grow))
	# Flakes fall only across the wash, and land on the top of the pile. Their number follows the area they fall through.
	var span := maxf((_floors.size() - 1) * STEP, 1.0)
	var fall := 0.0
	for f in _floors:
		fall += f - SNOW_TOP
	fall /= maxf(float(_floors.size()), 1.0)
	for k in clampi(int(_width() * fall / 26.0), 30, 1400):
		var fx := floorf(fmod(k * 37.0 + _age * 10.0, span) + sin(_age * 2.0 + k) * 2.0)
		var column := clampi(int(fx / STEP), 0, _floors.size() - 1)
		var landing := _floors[column] - _pile[column]
		var fy := floorf(fmod(_age * 55.0 + k * 23.0, landing - SNOW_TOP) + SNOW_TOP)
		var s := 2.0 + float(k % 2)
		var a := fade * grow * clampf((fy - SNOW_TOP) / 12.0, 0.0, 1.0)
		draw_rect(Rect2(fx - 1.0, fy - 1.0, s + 2.0, s + 2.0), Color(0.2, 0.36, 0.6, 0.8 * a))
		draw_rect(Rect2(fx, fy, s, s), Color(1, 1, 1, a))
	for c in _pile.size():
		if _pile[c] > 0.5:
			draw_rect(Rect2(c * STEP, _floors[c] - _pile[c], STEP + 1.0, _pile[c]), Color(0.92, 0.96, 1.0, fade * grow))


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

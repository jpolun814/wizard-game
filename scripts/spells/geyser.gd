class_name Geyser
extends Node2D

## Geyser: a jet of water bursts from the ground under the middle of the peak you drew. The ground bubbles first, so there is
## time to step off; whoever is standing on it when it bursts is thrown high into the air. That is anyone: you
## included. It does no damage itself. Then it sinks, rests, bubbles and bursts again, for as long as the world lasts.
## The water is real (see LiquidGrid): a burst lifts what water there is at its foot, and it falls back as the column sinks. On dry ground the
## first burst brings a little up from below, which then runs over the ground and is lifted again.

const WARNING := 0.7
const LIFE := 1.8  # one burst, from the first bubble to the column gone
const REST := 1.2  # the quiet before the ground starts to bubble again
const WIDTH := 46.0
const WIZARD_LAUNCH := 1000.0
const MOB_LAUNCH := 820.0
const COLUMN_HEIGHT := 190.0
const RISE := 0.2   # how fast the column shoots up
const DROP := WARNING + 1.0  # when the column starts to sink
const LIFT := 1.6     # how much liquid a burst lifts (a cell holds 1)
const SPRING := 1.6   # and how much comes up from below the first time, where there was none
const DROPLET := preload("res://art/fx/water_drop.png")  # DevWizard's water orb, one frame

var ground: Terrain  # the ground the geyser stands in; the water it spills runs over it
var _age := 0.0
var _burst := false
var _lifted := 0.0   # water in the column, on its way back down
var _sprung := false # true once water has come up from below
var _hiss: CPUParticles2D


func _ready() -> void:
	global_position = SpellTargets.surface_over(get_world_2d(), global_position)
	add_to_group("lasting")
	add_to_group("danger")
	z_index = 3
	# Small jets hiss up out of the cracking ground.
	_hiss = CPUParticles2D.new()
	_hiss.amount = 16
	_hiss.lifetime = 0.45
	_hiss.direction = Vector2.UP
	_hiss.spread = 25.0
	_hiss.initial_velocity_min = 70.0
	_hiss.initial_velocity_max = 150.0
	_hiss.gravity = Vector2(0, 520)
	_hiss.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_hiss.emission_rect_extents = Vector2(WIDTH * 0.4, 2)
	_hiss.texture = DROPLET
	_hiss.scale_amount_min = 0.3
	_hiss.scale_amount_max = 0.6
	_hiss.color_ramp = Fx.fade_ramp(Color(0.8, 0.95, 1.0, 0.9))
	add_child(_hiss)
	_begin_cycle()


## The ground starts to bubble again.
func _begin_cycle() -> void:
	_age = 0.0
	_burst = false
	_hiss.emitting = true
	Sfx.play("snow", global_position, 2.0)


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= LIFE + REST:
		_begin_cycle()
	if _lifted > 0.0 and _age >= LIFE:
		_let_fall()  # (a column cut short still lets the water go)
	if _age >= LIFE:
		return  # resting: nothing shows
	if not _burst:
		_hiss.amount = 16 + int(40.0 * _age / WARNING)  # the hissing grows as the burst nears
	if _burst:
		_douse_shots()
		if _lifted > 0.0 and _age >= DROP:
			_let_fall()
	if not _burst and _age >= WARNING:
		_burst = true
		_hiss.emitting = false
		_erupt()
	if _burst:
		GameCamera.shake_scene(get_tree(), 0.05 if _age < DROP else 0.0)


## How high the column stands now: it shoots up, holds, and sinks.
func _height() -> float:
	if not _burst:
		return 0.0
	var rise := clampf((_age - WARNING) / RISE, 0.0, 1.0)
	var sink := clampf((_age - DROP) / (LIFE - DROP), 0.0, 1.0)
	return COLUMN_HEIGHT * (1.0 - pow(1.0 - rise, 3.0)) * (1.0 - sink * sink)


## A fire shot that flies through the rising water goes out in a puff of steam.
func _douse_shots() -> void:
	var column := Rect2(global_position + Vector2(-WIDTH * 0.5, -_height()), Vector2(WIDTH, _height()))
	for shot in get_tree().get_nodes_in_group("shots"):
		if shot.is_in_group("fires") and column.has_point(shot.global_position):
			Fx.smoke(get_parent(), shot.global_position, Color(0.9, 0.95, 1.0, 0.6), 4, 24.0, 40.0)
			Sfx.play("freeze", shot.global_position, -6.0)
			if shot.has_method("_finish"):
				shot._finish()
			else:
				shot.queue_free()


## The burst lifts the water at its foot: from a pool, or, the first time on dry ground, from below.
func _lift() -> void:
	var area := Rect2(global_position + Vector2(-WIDTH * 0.5 - 16.0, -96.0), Vector2(WIDTH + 32.0, 112.0))
	for pond: Pond in get_tree().get_nodes_in_group("ponds"):
		if not pond.lava and pond.grid != null and pond.region().intersects(area):
			_lifted += pond.draw_off(area, LIFT - _lifted)
	if _lifted < LIFT * 0.5 and not _sprung:
		_sprung = true
		_lifted += SPRING


## The column sinks and the water falls back at its foot.
func _let_fall() -> void:
	if ground != null:
		Pond.spill(get_parent(), ground, global_position + Vector2(0.0, -6.0), _lifted)
	_lifted = 0.0


func _erupt() -> void:
	_lift()
	SpellTargets.douse(get_tree(), global_position, 110.0)
	Sfx.play("push", global_position, -2.0)
	GameCamera.shake_scene(get_tree(), 0.25)
	# Water thrown up the middle that falls back on both sides, like a fountain.
	var spray := CPUParticles2D.new()
	spray.amount = 70
	spray.lifetime = 1.3
	spray.direction = Vector2.UP
	spray.spread = 28.0
	spray.initial_velocity_min = 380.0
	spray.initial_velocity_max = 720.0
	spray.gravity = Vector2(0, 900)
	spray.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	spray.emission_rect_extents = Vector2(WIDTH * 0.3, 2)
	spray.texture = DROPLET
	spray.scale_amount_min = 0.3
	spray.scale_amount_max = 0.7
	spray.color_ramp = Fx.fade_ramp(Color(0.85, 0.96, 1.0, 0.95))
	spray.one_shot = true
	spray.explosiveness = 0.25
	add_child(spray)
	spray.emitting = true
	# Mist rolling out along the ground from the foot of it.
	var mist := CPUParticles2D.new()
	mist.amount = 14
	mist.lifetime = 0.9
	mist.direction = Vector2.UP
	mist.spread = 80.0
	mist.initial_velocity_min = 20.0
	mist.initial_velocity_max = 70.0
	mist.gravity = Vector2.ZERO
	mist.texture = Fx.tex("smoke_01")
	mist.scale_amount_min = 36.0 / Fx.TEX_SIZE
	mist.scale_amount_max = 70.0 / Fx.TEX_SIZE
	mist.color_ramp = Fx.fade_ramp(Color(0.85, 0.95, 1.0, 0.45))
	mist.one_shot = true
	mist.explosiveness = 0.5
	add_child(mist)
	mist.emitting = true
	Fx.burst(get_parent(), global_position, Color("#bfe9ff"), 16, 200.0, 0.6)
	# Whoever stands on the spot is thrown up.
	for body in SpellTargets.all(get_tree()):
		if _on_the_spot(body):
			if body.is_in_group("mobs"):
				body.knock_back(Vector2(0.0, -MOB_LAUNCH))
			else:
				body.push(Vector2(0.0, -WIZARD_LAUNCH))


## True for a body whose feet are on the geyser's spot, on the ground (a flyer overhead is not).
func _on_the_spot(body: Node2D) -> bool:
	if body.is_in_group("mobs") and body.KINDS[body.kind].role == "flyer":
		return false
	return absf(body.global_position.x - global_position.x) <= WIDTH * 0.5 + 8.0 \
		and body.global_position.y >= global_position.y - 30.0 and body.global_position.y <= global_position.y + 20.0


func danger_at(point: Vector2) -> bool:
	if _age >= DROP:
		return false  # sinking or resting: the spot is safe until it bubbles again
	return absf(point.x - global_position.x) < WIDTH * 0.5 + 6.0 and point.y > global_position.y - COLUMN_HEIGHT and point.y < global_position.y + 10.0


## The water, drawn the way the ponds draw theirs (see Pond): shaded from light at the top to dark below, with a bright edge. First the
## ground wells up in a swelling mound, then the column stands on it, wide at the foot and narrower above, its edges rippling.
func _draw() -> void:
	if _age >= LIFE:
		return
	var fade := clampf((LIFE - _age) / 0.5, 0.0, 1.0)
	var swell := clampf(_age / WARNING, 0.0, 1.0)
	_draw_mound(WIDTH * (0.6 + 0.5 * swell), 3.0 + 9.0 * swell, fade)
	var height := _height()
	if height < 4.0:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var t := float(i) / steps
		var half := WIDTH * 0.5 * lerpf(1.0, 0.55, t) + sin(_age * 22.0 + t * 9.0) * 2.5
		left.append(Vector2(-half, -height * t))
		right.append(Vector2(half, -height * t))
	var body := PackedVector2Array()
	var colours := PackedColorArray()
	for i in left.size():
		body.append(left[i])
		colours.append(_shade(float(i) / steps, fade))
	for i in range(right.size() - 1, -1, -1):
		body.append(right[i])
		colours.append(_shade(float(i) / steps, fade))
	draw_polygon(body, colours)
	var edge := Pond.WATER_RIM
	edge.a = fade
	draw_polyline(left, edge, 2.0)
	draw_polyline(right, edge, 2.0)
	_draw_crest(Vector2(0.0, -height), left[steps].x * -1.0, fade)
	# Streaks of bright water racing up the column.
	for k in 3:
		var x := (k - 1) * WIDTH * 0.2
		var y := -fmod(_age * 520.0 + k * 31.0, 38.0)
		while y > -height + 6.0:
			draw_line(Vector2(x, y), Vector2(x, maxf(y - 16.0, -height + 4.0)), Color(edge.r, edge.g, edge.b, 0.5 * fade), 3.0)
			y -= 38.0


## The top of the column: the water spreads and curls over like the head of a fountain, so the column does not just stop. It is much wider
## than the column and rounded above and below, lighter, with a bright edge.
func _draw_crest(top: Vector2, column_half: float, fade: float) -> void:
	var half := column_half * 2.8
	var ring := PackedVector2Array()
	var colours := PackedColorArray()
	var steps := 28
	for i in steps:
		var angle := TAU * float(i) / steps  # round the whole outline, from the right edge over the top, down the left, and back under
		var up := sin(angle)
		var reach := cos(angle)
		var wobble := sin(_age * 18.0 + reach * 6.0) * 1.0
		var y := -up * (18.0 if up > 0.0 else 9.0)  # a high dome above, a shallower round belly below
		ring.append(top + Vector2(reach * half, y + wobble + 4.0))
		colours.append(Pond.WATER_TOP.lerp(Pond.WATER_RIM, clampf(0.25 + 0.5 * up, 0.0, 1.0)))
	for c in colours.size():
		colours[c].a = fade
	draw_polygon(ring, colours)
	var edge := Pond.WATER_RIM
	edge.a = fade
	ring.append(ring[0])
	draw_polyline(ring, edge, 2.0)


## Water welling up on the ground: a low mound, shaded like the pond, with a rippling bright edge.
func _draw_mound(width: float, height: float, fade: float) -> void:
	var top := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		var x := lerpf(-width * 0.5, width * 0.5, t)
		top.append(Vector2(x, -height * sin(t * PI) - sin(_age * 14.0 + t * 10.0) * 0.8))
	var colours := PackedColorArray()
	for point in top:
		colours.append(Pond.WATER_TOP.lerp(Pond.WATER_BOTTOM, clampf(1.0 + point.y / maxf(height, 1.0), 0.0, 1.0) * 0.6))
	var rim := Pond.WATER_RIM
	rim.a = fade
	for c in colours.size():
		colours[c].a = fade
	draw_polygon(top, colours)
	draw_polyline(top, rim, 2.0)


## Water in the column: lighter the higher it is.
func _shade(t: float, fade: float) -> Color:
	var colour := Pond.WATER_TOP.lerp(Pond.WATER_RIM, t * 0.7)
	colour.a = fade
	return colour

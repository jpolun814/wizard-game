class_name Geyser
extends Node2D

## Geyser: a jet of water bursts from the ground under the middle of the peak you drew. The ground bubbles first, so there is
## time to step off; whoever is standing on it when it bursts is thrown high into the air. That is anyone: you
## included. The water is scalding, so whoever is in the column is hurt a little each second, and steam pours off it while it stands. Then it sinks, rests, bubbles and bursts again, for as long as the world lasts.
## The water is real (see LiquidGrid): a burst lifts what water there is at its foot, and it falls back as the column sinks. On dry ground the
## first burst brings a little up from below, which then runs over the ground and is lifted again.

const WARNING := 0.7
const LIFE := 1.8  # one burst, from the first bubble to the column gone
const REST := 1.2  # the quiet before the ground starts to bubble again
const SHAKE_REACH := 300.0  # how far off the ground still shakes under a wizard (a faint tremor: it once shook the screen like a quake, owner 2026-11-15)
const WIDTH := 46.0
const WIZARD_LAUNCH := 1000.0
const MOB_LAUNCH := 820.0
const COLUMN_HEIGHT := 190.0
const RISE := 0.2   # how fast the column shoots up
const DROP := WARNING + 1.0  # when the column starts to sink
const LIFT := 1.6     # how much liquid a burst lifts (a cell holds 1)
const SPRING := 1.6   # and how much comes up from below the first time, where there was none
const SCALD := 1      # damage a second to whoever is in the column

var ground: Terrain  # the ground the geyser stands in; the water it spills runs over it
var _age := 0.0
var _burst := false
var _lifted := 0.0   # water in the column, on its way back down
var _sprung := false # true once water has come up from below
var _hiss: CPUParticles2D
var _scalded := {}  # body -> when the water last scalded it
var _steam: CPUParticles2D
var _riders := {}  # body -> when the column last threw it up, so a body that stays in the water is not thrown every frame


func _ready() -> void:
	global_position = SpellTargets.surface_over(get_world_2d(), global_position)
	add_to_group("lasting")
	add_to_group("danger")
	z_index = 3
	material = ShaderMaterial.new()  # shaded in dithered bands, like the pools
	(material as ShaderMaterial).shader = preload("res://scripts/terrain/pixel_liquid.gdshader")
	(material as ShaderMaterial).set_shader_parameter("levels", 14.0)
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
	_hiss.texture = Fx.pixel_drop()
	_hiss.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hiss.scale_amount_min = 1.0
	_hiss.scale_amount_max = 1.6
	_hiss.color_ramp = Fx.fade_ramp(Color(0.8, 0.95, 1.0, 0.9))
	add_child(_hiss)
	# Steam pours off the water while the column stands.
	_steam = CPUParticles2D.new()
	_steam.amount = 34
	_steam.lifetime = 1.1
	_steam.direction = Vector2.UP
	_steam.spread = 35.0
	_steam.initial_velocity_min = 30.0
	_steam.initial_velocity_max = 90.0
	_steam.gravity = Vector2(0, -30)
	_steam.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_steam.emission_rect_extents = Vector2(WIDTH * 0.5, 40)
	_steam.texture = Fx.tex("smoke_01")
	_steam.scale_amount_min = 44.0 / Fx.TEX_SIZE
	_steam.scale_amount_max = 90.0 / Fx.TEX_SIZE
	_steam.color_ramp = Fx.fade_ramp(Color(0.97, 0.98, 1.0, 0.85))
	_steam.emitting = false
	add_child(_steam)
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
	_steam.emitting = _burst and _age < DROP + 0.5
	_steam.position.y = -_height() * 0.5
	if _age >= LIFE:
		return  # resting: nothing shows
	if not _burst:
		_hiss.amount = 16 + int(40.0 * _age / WARNING)  # the hissing grows as the burst nears
	if _burst:
		_douse_shots()
		_douse_fires()
		_carry_riders()
		if _lifted > 0.0 and _age >= DROP:
			_let_fall()
	if not _burst and _age >= WARNING:
		_burst = true
		_hiss.emitting = false
		Sfx.play("geyser", global_position)
		_erupt()
	if _burst:
		GameCamera.shake_near(get_tree(), global_position, 0.015 if _age < DROP else 0.0, SHAKE_REACH)


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
			if shot is SpellEffect:
				shot.end()
			else:
				shot.queue_free()


## All fire that is in the rising water goes out: a flamethrower's breath, a wall of flame or a bonfire alike.
func _douse_fires() -> void:
	var column := Rect2(global_position + Vector2(-WIDTH * 0.5 - 8.0, -_height()), Vector2(WIDTH + 16.0, _height() + 8.0))
	for node: Node2D in get_tree().get_nodes_in_group("fires"):
		if not node.has_method("quench") or not node.has_method("flame_points"):
			continue
		for point: Vector2 in node.flame_points():
			if column.has_point(point):
				Fx.smoke(get_parent(), point, Color(0.88, 0.92, 0.96, 0.7), 6, 24.0, 60.0)
				Sfx.play("freeze", point, -6.0)
				node.quench()
				break


## Anyone who walks into the column while it stands is thrown up, not only whoever was on the spot when it burst.
func _carry_riders() -> void:
	if _age >= DROP:
		return
	var now := Time.get_ticks_msec()
	var column := Rect2(global_position + Vector2(-WIDTH * 0.5 - 8.0, -_height()), Vector2(WIDTH + 16.0, _height() + 30.0))
	for body in SpellTargets.all(get_tree()):
		if column.has_point(SpellTargets.center_of(body)) and now - int(_scalded.get(body, -10000)) >= 1000:
			_scalded[body] = now
			SpellTargets.hurt(body, SCALD, "Water", false, false, self)
		if not column.has_point(SpellTargets.center_of(body)) or now - int(_riders.get(body, -10000)) < 350:
			continue
		_riders[body] = now
		if body is Wizard:
			body.push(Vector2(0.0, -WIZARD_LAUNCH))
			body.coat.soak()  # the jet leaves them wet
		else:
			body.knock_back(Vector2(0.0, -MOB_LAUNCH))  # (a creature, a risen skeleton among them)


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
	GameCamera.shake_near(get_tree(), global_position, 0.07, SHAKE_REACH)
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
	spray.texture = Fx.pixel_drop()
	spray.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spray.scale_amount_min = 1.0
	spray.scale_amount_max = 1.8
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
			if body is Wizard:
				body.push(Vector2(0.0, -WIZARD_LAUNCH))
			else:
				body.knock_back(Vector2(0.0, -MOB_LAUNCH))


## True for a body whose feet are on the geyser's spot, on the ground.
func _on_the_spot(body: Node2D) -> bool:
	return absf(body.global_position.x - global_position.x) <= WIDTH * 0.5 + 8.0 \
		and body.global_position.y >= global_position.y - 30.0 and body.global_position.y <= global_position.y + 20.0


func danger_at(point: Vector2) -> bool:
	if _age >= DROP:
		return false  # sinking or resting: the spot is safe until it bubbles again
	return absf(point.x - global_position.x) < WIDTH * 0.5 + 6.0 and point.y > global_position.y - COLUMN_HEIGHT and point.y < global_position.y + 10.0


## The water, drawn from pixel art in the colors of the ponds (WaterPixels). First the
## ground wells up in a swelling mound, then the column stands on it, wide at the foot and narrower above, its edges rippling.
func _draw() -> void:
	if _age >= LIFE:
		return
	var fade := clampf((LIFE - _age) / 0.5, 0.0, 1.0)
	var swell := clampf(_age / WARNING, 0.0, 1.0)
	WaterPixels.mound(self, Vector2.ZERO, WIDTH * (0.6 + 0.5 * swell) * 1.4, fade)
	var height := _height()
	if height < 4.0:
		return
	var points := PackedVector2Array()
	var widths := PackedFloat32Array()
	var alphas := PackedFloat32Array()
	var steps := 14
	for i in steps + 1:
		var t := float(i) / steps
		points.append(Vector2(0.0, -height * t))
		widths.append(WIDTH * lerpf(1.0, 0.3, t * t) + sin(_age * 22.0 + t * 9.0) * 2.5)
		alphas.append(fade)
	WaterPixels.stream(self, points, widths, alphas, _age, true)
	_draw_crest(height, fade)


## The head of the column: the water does not stop at the top, it bursts open and is flung out and up in drops that arch over and fall, as a fountain's do.
func _draw_crest(height: float, fade: float) -> void:
	if height < 40.0:
		return
	var top := Vector2(0.0, -height + 6.0)
	var spread := clampf((height - 40.0) / 90.0, 0.0, 1.0)  # it opens as it reaches full height
	var mist := Fx.tex("smoke_01")  # a breath of spray hangs over the head of it
	draw_texture_rect(mist, Rect2(top + Vector2(-34.0, -34.0), Vector2(68.0, 60.0)), false, Color(0.85, 0.95, 1.0, 0.22 * fade * spread))
	var drop := Fx.pixel_drop()
	var count := 28
	for k in count:
		var life := fposmod(_age * 1.6 + float(k) / count, 1.0)
		var side := -1.0 if k % 2 == 0 else 1.0
		var strength := fposmod(float(k) * 0.618, 1.0)  # no two drops are thrown the same
		var t := life * 0.75
		var flung := Vector2(side * (14.0 + 62.0 * strength) * t, -(95.0 + 60.0 * fposmod(float(k) * 0.37, 1.0)) * t + 190.0 * t * t)
		var at := top + flung * spread
		draw_texture_rect(drop, Rect2(at.round() - Vector2(2.0, 2.5), Vector2(4.0, 5.0)), false, Color(1.0, 1.0, 1.0, clampf((1.0 - life) * 1.6, 0.0, 1.0) * fade * 0.95))

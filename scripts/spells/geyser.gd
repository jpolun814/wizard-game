class_name Geyser
extends Node2D

## Geyser: a jet of water bursts from the ground under the middle of the peak you drew. The ground bubbles first, so there is
## time to step off; whoever is standing on it when it bursts is thrown high into the air. That is anyone: you
## included. It does no damage itself.

const WARNING := 0.7
const LIFE := 1.8
const WIDTH := 46.0
const PLAYER_LAUNCH := 1000.0
const MOB_LAUNCH := 820.0
const COLUMN_HEIGHT := 190.0
const RISE := 0.2   # how fast the column shoots up
const DROP := WARNING + 1.0  # when the column starts to sink
const DROPLET := preload("res://art/fx/water_drop.png")  # DevWizard's water orb, one frame

var _age := 0.0
var _burst := false
var _bubbles: AnimatedSprite2D
var _crown: AnimatedSprite2D
var _base: AnimatedSprite2D
var _hiss: CPUParticles2D


func _ready() -> void:
	global_position = SpellTargets.surface_over(get_world_2d(), global_position)
	add_to_group("lasting")
	add_to_group("danger")
	z_index = 3
	# The ground bubbles where it is about to burst.
	_bubbles = PixelFx.sprite("bubbles", 24.0)
	_bubbles.offset = Vector2(0, -PixelArt.FX["bubbles"]["size"].y * 0.5)
	_bubbles.modulate = Color(0.8, 0.95, 1.0, 0.9)
	_bubbles.scale = Vector2(0.6, 0.6)
	add_child(_bubbles)
	# Small jets hiss up out of the cracking ground, and a splash pulses at the foot.
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
	_hiss.emitting = true
	_base = PixelFx.sprite("splash", 9.0)
	_base.scale = Vector2(2.0, 2.0)
	_base.offset = Vector2(0, -PixelArt.FX["splash"]["size"].y * 0.5)  # it stands on the ground
	_base.modulate.a = 0.75
	add_child(_base)
	Sfx.play("snow", global_position, 2.0)


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if not _burst:
		_hiss.amount = 16 + int(40.0 * _age / WARNING)  # the hissing grows as the burst nears
		_base.scale = Vector2.ONE * (2.0 + _age / WARNING)
	if _crown != null:
		_crown.position = Vector2(0.0, -_height())
		_crown.modulate.a = clampf((LIFE - _age) / 0.5, 0.0, 1.0)
	if not _burst and _age >= WARNING:
		_burst = true
		_bubbles.queue_free()
		_hiss.emitting = false
		_base.scale = Vector2(3.0, 3.0)
		_base.modulate.a = 1.0
		_crown = PixelFx.sprite("splash", 12.0)
		_crown.scale = Vector2(2.0, 2.0)
		_crown.offset = Vector2(0, -PixelArt.FX["splash"]["size"].y * 0.5)
		add_child(_crown)
		_erupt()
	if _burst:
		_base.modulate.a = clampf((LIFE - _age) / 0.5, 0.0, 1.0)
		GameCamera.shake_scene(get_tree(), 0.05 if _age < DROP else 0.0)
	if _age >= LIFE:
		queue_free()


## How high the column stands now: it shoots up, holds, and sinks.
func _height() -> float:
	if not _burst:
		return 0.0
	var rise := clampf((_age - WARNING) / RISE, 0.0, 1.0)
	var sink := clampf((_age - DROP) / (LIFE - DROP), 0.0, 1.0)
	return COLUMN_HEIGHT * (1.0 - pow(1.0 - rise, 3.0)) * (1.0 - sink * sink)


func _erupt() -> void:
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
				body.push(Vector2(0.0, -PLAYER_LAUNCH))


## True for a body whose feet are on the geyser's spot, on the ground (a flyer overhead is not).
func _on_the_spot(body: Node2D) -> bool:
	if body.is_in_group("mobs") and body.KINDS[body.kind]["role"] == "flyer":
		return false
	return absf(body.global_position.x - global_position.x) <= WIDTH * 0.5 + 8.0 \
		and body.global_position.y >= global_position.y - 30.0 and body.global_position.y <= global_position.y + 20.0


func danger_at(point: Vector2) -> bool:
	return absf(point.x - global_position.x) < WIDTH * 0.5 + 6.0 and point.y > global_position.y - COLUMN_HEIGHT and point.y < global_position.y + 10.0


## The column of water: wide at the foot and narrower above, its edges rippling, lighter towards the top, with bright
## streaks racing up it.
func _draw() -> void:
	var height := _height()
	if height < 4.0:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var t := float(i) / steps
		var y := -height * t
		var half := WIDTH * 0.5 * lerpf(1.0, 0.55, t) + sin(_age * 22.0 + t * 9.0) * 2.5
		left.append(Vector2(-half, y))
		right.append(Vector2(half, y))
	var body := PackedVector2Array()
	var colours := PackedColorArray()
	for i in left.size():
		body.append(left[i])
		colours.append(_shade(float(i) / steps))
	for i in range(right.size() - 1, -1, -1):
		body.append(right[i])
		colours.append(_shade(float(i) / steps))
	draw_polygon(body, colours)
	var edge := Color(0.95, 1.0, 1.0, 0.9)
	draw_polyline(left, edge, 2.0)
	draw_polyline(right, edge, 2.0)
	# Streaks of foam racing up the column.
	for k in 3:
		var x := (k - 1) * WIDTH * 0.2
		var offset := fmod(_age * 520.0 + k * 31.0, 38.0)
		var y := -offset
		while y > -height + 6.0:
			draw_line(Vector2(x, y), Vector2(x, maxf(y - 16.0, -height + 4.0)), Color(1, 1, 1, 0.65), 3.0)
			y -= 38.0


## The colour of the water at a point up the column (0 at the foot, 1 at the top): deep blue below, white foam above.
func _shade(t: float) -> Color:
	return Color(0.3, 0.6, 0.92, 0.82).lerp(Color(0.88, 0.97, 1.0, 0.9), t)

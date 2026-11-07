class_name SteamBurst
extends Node2D

## Steam Burst: a spiral drawn in the open, and a column of scalding steam rises from the ground there for a few seconds. It scalds whoever stands in it. Wind
## (Gust, Tornado) clears it away.

const SECONDS := 3.5
const TICK := 0.4
const HARM := 3
const WIDTH := 70.0
const HEIGHT := 170.0
const FADE := 0.6

var _age := 0.0
var _clock := 0.0
var _thinning := -1.0
var _jet: CPUParticles2D


func _ready() -> void:
	global_position = SpellTargets.surface_over(get_world_2d(), global_position)
	add_to_group("clouds")
	add_to_group("lasting")
	add_to_group("danger")
	z_index = 3
	_jet = CPUParticles2D.new()
	_jet.amount = 26
	_jet.lifetime = 0.9
	_jet.direction = Vector2.UP
	_jet.spread = 14.0
	_jet.initial_velocity_min = HEIGHT * 0.9
	_jet.initial_velocity_max = HEIGHT * 1.4
	_jet.damping_min = 40.0
	_jet.damping_max = 90.0
	_jet.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_jet.emission_rect_extents = Vector2(WIDTH * 0.3, 4.0)
	_jet.scale_amount_min = 28.0 / Fx.TEX_SIZE
	_jet.scale_amount_max = 52.0 / Fx.TEX_SIZE
	_jet.texture = Fx.tex("smoke_04")
	_jet.color_ramp = Fx.fade_ramp(Color(0.85, 0.92, 1.0, 0.5))
	_jet.material = Fx.additive()  # steam is bright: it adds light rather than greying what is behind it
	_jet.emitting = true
	add_child(_jet)
	Sfx.play("snow", global_position, -2.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _thinning >= 0.0:
		_thinning -= delta
		modulate.a = clampf(_thinning / FADE, 0.0, 1.0)
		if _thinning < 0.0:
			queue_free()
		return
	if _age >= SECONDS:
		_jet.emitting = false
		dissipate()
		return
	_clock -= delta
	if _clock <= 0.0:
		_clock = TICK
		for body in SpellTargets.all(get_tree()):
			if _in_column(SpellTargets.center_of(body)):
				SpellTargets.hurt(body, HARM, "Water", false, false, self)


func _in_column(point: Vector2) -> bool:
	return absf(point.x - global_position.x) <= WIDTH * 0.5 and point.y <= global_position.y + 8.0 and point.y >= global_position.y - HEIGHT


## The wind takes it: it thins away.
func dissipate() -> void:
	if _thinning < 0.0:
		_thinning = FADE
		_jet.emitting = false


func danger_at(point: Vector2) -> bool:
	return _thinning < 0.0 and _in_column(point)

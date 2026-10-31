class_name Sinkhole
extends Node2D

## Sinkhole: the ground opens where a U was drawn. A pit is dug into the open ground (Terrain.dig), as wide as the U and deeper
## than a wizard is tall, and whoever stands over it drops in. It does not close again. It does nothing under a roof or on the bare stone
## of a castle floor, where there is no ground to give way.

const HALF_WIDTH := 80.0  # the width of a pit drawn with no U to go by
const LEAST := 50.0       # and the narrowest and widest a drawn U can make it
const MOST := 130.0
const DEPTH := 96.0
const WARNING := 0.9   # seconds the ground trembles before it gives way

var ground: Terrain
var half_width := HALF_WIDTH  # how far the pit reaches to either side: the width of the U that was drawn
var _age := 0.0
var _opened := false
var _dust: CPUParticles2D


func _ready() -> void:
	add_to_group("lasting")
	z_index = 2
	_dust = CPUParticles2D.new()
	_dust.amount = 18
	_dust.lifetime = 0.7
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(half_width, 2.0)
	_dust.direction = Vector2.UP
	_dust.spread = 25.0
	_dust.initial_velocity_min = 20.0
	_dust.initial_velocity_max = 60.0
	_dust.gravity = Vector2(0.0, 90.0)
	_dust.texture = Fx.tex("dirt_01")
	_dust.scale_amount_min = 4.0 / Fx.TEX_SIZE
	_dust.scale_amount_max = 9.0 / Fx.TEX_SIZE
	_dust.color = Color(0.7, 0.58, 0.45, 0.8)
	add_child(_dust)
	Sfx.play("quake", global_position, -6.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _opened:
		if _age > WARNING + 1.2:
			queue_free()
		return
	if _age < WARNING:
		return
	_opened = true
	_dust.emitting = false
	var dug := ground != null and ground.dig(global_position, half_width, DEPTH)
	if dug:
		GameCamera.shake_scene(get_tree(), 0.35)
		Fx.debris(get_parent(), global_position, Color("#8a6a4a"), 14, 200.0)
		Sfx.play("stones", global_position, -2.0)
	else:
		Fx.smoke(get_parent(), global_position, Color(0.5, 0.47, 0.45, 0.6), 4, 24.0, 30.0)  # nothing here gave way


## True over the pit while it is about to open: the ground is not to be stood on.
func danger_at(point: Vector2) -> bool:
	return not _opened and absf(point.x - global_position.x) < half_width and absf(point.y - global_position.y) < 40.0

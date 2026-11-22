class_name Bathe
extends Node2D

## Bathe: a shower falls on the caster and washes them clean (`Substances.wash`: a flame, oil, a chill, a curse, a wound, a daze, a snail on their heels all
## go), and leaves them wet, as water does (`Substances.soak`). The shower is a small rain cloud over them for a moment, and falls where they go.

const SECONDS := 1.8

var caster: Wizard  # set by the arena before it enters the tree
var _age := 0.0
var _rain: CPUParticles2D
var _cloud: Sprite2D


func _ready() -> void:
	z_index = 6
	if is_instance_valid(caster):
		Substances.wash(caster)
		Substances.soak(caster)
		global_position = caster.global_position
	_cloud = Sprite2D.new()
	_cloud.texture = Fx.soft("smoke_01")
	_cloud.modulate = Color(0.62, 0.72, 0.85, 0.0)
	_cloud.scale = Vector2.ONE * 0.5
	_cloud.position = Vector2(0.0, -Wizard.BODY_HEIGHT - 26.0)
	add_child(_cloud)
	create_tween().tween_property(_cloud, "modulate:a", 0.85, 0.25)
	_rain = CPUParticles2D.new()
	_rain.texture = Fx.tex("circle_05")
	_rain.material = Fx.additive()
	_rain.position = _cloud.position + Vector2(0.0, 8.0)
	_rain.amount = 60
	_rain.lifetime = 0.45
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(26.0, 3.0)
	_rain.direction = Vector2.DOWN
	_rain.spread = 5.0
	_rain.initial_velocity_min = 230.0
	_rain.initial_velocity_max = 300.0
	_rain.gravity = Vector2(0.0, 500.0)
	_rain.scale_amount_min = 0.03
	_rain.scale_amount_max = 0.06
	_rain.color = Color(0.7, 0.88, 1.0, 0.9)
	add_child(_rain)
	Sfx.cue("Bathe", "shower", global_position, -2.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if is_instance_valid(caster):
		global_position = caster.global_position
	if _age >= SECONDS - 0.3 and _rain.emitting:
		_rain.emitting = false
		create_tween().tween_property(_cloud, "modulate:a", 0.0, 0.3)
	if _age >= SECONDS:
		queue_free()


func danger_at(_point: Vector2) -> bool:
	return false

class_name MendAura
extends Node2D

## The motes that drift about a wizard while a heal over time is on them (Breathe's wisps of air, the Mud Mask's flecks of mud). It is a child of the wizard and
## goes when that heal ends.

var kind := ""            # the heal over time it shows (see Mending.OVER_TIME)
var color := Color.WHITE
var texture_name := "smoke_01"
var _motes: CPUParticles2D


func _ready() -> void:
	z_index = 7
	_motes = CPUParticles2D.new()
	_motes.texture = Fx.tex(texture_name)
	_motes.position = Vector2(0.0, -Wizard.BODY_HEIGHT * 0.5)
	_motes.amount = 10
	_motes.lifetime = 1.0
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_motes.emission_sphere_radius = 20.0
	_motes.direction = Vector2.UP
	_motes.spread = 40.0
	_motes.initial_velocity_min = 12.0
	_motes.initial_velocity_max = 34.0
	_motes.gravity = Vector2.ZERO
	_motes.scale_amount_min = 6.0 / Fx.TEX_SIZE
	_motes.scale_amount_max = 14.0 / Fx.TEX_SIZE
	_motes.color = color
	_motes.color_ramp = Fx.fade_ramp(color)
	add_child(_motes)


func _physics_process(_delta: float) -> void:
	var wizard := get_parent() as Wizard
	if wizard == null or not wizard.mending.is_on(kind) or wizard.dead:
		queue_free()

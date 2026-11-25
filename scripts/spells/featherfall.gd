class_name Featherfall
extends RefCounted

## Featherfall: the caster falls as slowly as a feather for a while. This holds what the cast does (see Wizard.feather_time for the fall itself).

static var SECONDS := Motion.number("Featherfall", "state", "for")


const FEATHERS := preload("res://art/fx/feathers.png")


## The feathers that float about a wizard while the spell lasts: pale slivers that sway and sink slowly, in a ring round the wizard's middle. The wizard turns it on and off.
static func drift() -> CPUParticles2D:
	var feathers := CPUParticles2D.new()
	feathers.amount = 14
	feathers.lifetime = 2.2
	feathers.emitting = false
	feathers.local_coords = false
	feathers.position = Vector2(0, -34)
	feathers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	feathers.emission_sphere_radius = 26.0
	feathers.direction = Vector2.DOWN
	feathers.spread = 40.0
	feathers.initial_velocity_min = 4.0
	feathers.initial_velocity_max = 14.0
	feathers.gravity = Vector2(0, 8)
	feathers.angular_velocity_min = -80.0
	feathers.angular_velocity_max = 80.0
	feathers.tangential_accel_min = -30.0
	feathers.tangential_accel_max = 30.0
	feathers.texture = FEATHERS  # real pixel art: a feather in three poses (tools/wizard_parts/feathers.py), turned through as it drifts
	feathers.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sheet := CanvasItemMaterial.new()
	sheet.particles_animation = true
	sheet.particles_anim_h_frames = 3
	sheet.particles_anim_v_frames = 1
	sheet.particles_anim_loop = true
	feathers.material = sheet
	feathers.anim_speed_min = 1.0
	feathers.anim_speed_max = 2.0
	feathers.scale_amount_min = 1.0
	feathers.scale_amount_max = 1.0
	feathers.angular_velocity_min = 0.0
	feathers.angular_velocity_max = 0.0
	feathers.z_index = 4
	return feathers


static func cast(caster: Wizard) -> void:
	caster.feather_time = SECONDS
	Fx.burst(caster.get_parent(), caster.center(), Color(0.92, 0.95, 1.0), 10, 60.0, 0.9, false, "star_04")
	Sfx.cue("Featherfall", "whoosh", caster.center(), -8.0)

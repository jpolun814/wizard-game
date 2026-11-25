class_name RocketJump
extends RefCounted

## Rocket Jump: flame pours from the caster's feet and, like a rocket taking off, lifts them slowly at first and then faster and faster, high into the air.
## This holds what the cast does; the climb itself is in Wizard (see rocket_time).

const BURN := 1.5   # seconds the flame pours and the climb quickens
const TOP := 600.0  # the speed up, in pixels a second, when the flame dies: about 480 px of height in all


static func cast(caster: Wizard) -> void:
	var feet: Vector2 = caster.global_position
	Fx.burst(caster.get_parent(), feet, Color("#ff8a2a"), 40, 200.0, 0.7, true, "flame_05")  # a small puff of flame as it lights
	Sfx.cue("Rocket Jump", "breath", feet, -2.0)
	var jet := Fx.trail(Color("#ff8a2a"), 120, 0.65, 22.0, Vector2(0.0, 80.0), "flame_05", 30.0)
	jet.position = Vector2.ZERO  # at the feet (a wizard's origin is the soles)
	jet.direction = Vector2.DOWN
	jet.angle_min = 180.0  # a flame is drawn pointing up: turned over, its tongues stream down from the feet
	jet.angle_max = 180.0
	jet.initial_velocity_min = 120.0
	jet.initial_velocity_max = 220.0
	caster.add_child(jet)
	var smoke := Fx.trail(Color(0.32, 0.3, 0.3, 0.55), 60, 1.6, 30.0, Vector2(0.0, -20.0), "smoke_04", 34.0)  # a gray trail left hanging where the rocket has been
	smoke.material = null  # not glowing, so it darkens what is behind it
	smoke.position = Vector2.ZERO
	smoke.direction = Vector2.DOWN
	smoke.initial_velocity_min = 40.0
	smoke.initial_velocity_max = 110.0
	caster.add_child(smoke)
	# (each is timed by a tween of its own: if the wizard goes with the world before the flame is out, the tween goes with the flame, and nothing is called on what is freed)
	var jet_tween := jet.create_tween()
	jet_tween.tween_interval(BURN)
	jet_tween.tween_callback(func() -> void: jet.emitting = false)
	jet_tween.tween_interval(0.6)
	jet_tween.tween_callback(jet.queue_free)
	var smoke_tween := smoke.create_tween()
	smoke_tween.tween_interval(BURN)
	smoke_tween.tween_callback(func() -> void: smoke.emitting = false)
	smoke_tween.tween_interval(2.0)
	smoke_tween.tween_callback(smoke.queue_free)
	if caster.is_likeness():
		return  # the machine that drives this wizard lifts them
	caster.free_from_ground()
	caster.rocket_time = BURN

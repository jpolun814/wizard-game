class_name RocketJump
extends RefCounted

## Rocket Jump: flame pours from the caster's feet and, like a rocket taking off, lifts them slowly at first and then faster and faster, high into the air.
## This holds what the cast does; the climb itself is in Wizard (see rocket_time).

const BURN := 1.5   # seconds the flame pours and the climb quickens
const TOP := 600.0  # the speed up, in pixels a second, when the flame dies: about 480 px of height in all


static func cast(caster: Wizard) -> void:
	var feet: Vector2 = caster.global_position
	Fx.burst(caster.get_parent(), feet, Color("#ff8a2a"), 40, 200.0, 0.7, true, "flame_05")  # a small puff of flame as it lights
	Sfx.play("fire_breath", feet, -2.0)
	var jet := Fx.trail(Color("#ff8a2a"), 120, 0.65, 22.0, Vector2(0.0, 80.0), "flame_05", 30.0)
	jet.position = Vector2.ZERO  # at the feet (a wizard's origin is the soles)
	jet.direction = Vector2.DOWN
	jet.initial_velocity_min = 120.0
	jet.initial_velocity_max = 220.0
	caster.add_child(jet)
	var smoke := Fx.trail(Color(0.32, 0.3, 0.3, 0.55), 60, 1.6, 30.0, Vector2(0.0, -20.0), "smoke_04", 34.0)  # a grey trail left hanging where the rocket has been
	smoke.material = null  # not glowing, so it darkens what is behind it
	smoke.position = Vector2.ZERO
	smoke.direction = Vector2.DOWN
	smoke.initial_velocity_min = 40.0
	smoke.initial_velocity_max = 110.0
	caster.add_child(smoke)
	jet.get_tree().create_timer(BURN).timeout.connect(func() -> void:
		if is_instance_valid(jet):
			jet.emitting = false
			jet.get_tree().create_timer(0.6).timeout.connect(jet.queue_free)
		if is_instance_valid(smoke):
			smoke.emitting = false
			smoke.get_tree().create_timer(2.0).timeout.connect(smoke.queue_free))
	if caster.is_likeness():
		return  # the machine that drives this wizard lifts them
	caster.free_from_ground()
	caster.rocket_time = BURN

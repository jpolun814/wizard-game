class_name Featherfall
extends RefCounted

## Featherfall: the caster falls as slowly as a feather for a while. This holds what the cast does (see Wizard.feather_time for the fall itself).

const SECONDS := 15.0


static func cast(caster: Wizard) -> void:
	caster.feather_time = SECONDS
	Fx.burst(caster.get_parent(), caster.center(), Color(0.92, 0.95, 1.0), 10, 60.0, 0.9, false, "star_04")
	Sfx.play("push", caster.center(), -8.0)

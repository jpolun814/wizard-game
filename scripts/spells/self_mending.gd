class_name SelfMending
extends RefCounted

## The heals a wizard works on themselves, cast with a drawn shape: Cauterize (a sear, all at once, and a burn after), Breathe (air, a little at a time for a few
## seconds) and Mud Mask (mud, a little at a time for longer). Each pays its price in stamina when drawn, as every spell does, and heals maximum stamina.
## How a heal over time goes on, and what ends it, is `Mending`.

const CAUTERIZE_GIVES := 55.0


## Sears the wounds shut: at once, and then the wizard burns (the law of fire: a wet body cannot be lit, so the sear does nothing for a wizard who is wet).
static func cauterize(wizard: Wizard) -> void:
	if wizard.is_wet():
		FloatText.spawn(wizard.get_parent(), wizard.center() + Vector2(0, -44), "Too wet", Color.GRAY, 0.9)
		Fx.smoke(wizard.get_parent(), wizard.center(), Color(0.88, 0.92, 0.96, 0.5), 3, 18.0, 36.0)
		return
	Fx.burst(wizard.get_parent(), wizard.center(), Color("#ff9a3a"), 20, 170.0, 0.5, true)
	Sfx.cue("Cauterize", "mend", wizard.center(), -4.0)
	wizard.mending.give_at_once(CAUTERIZE_GIVES)
	Substances.ignite(wizard, Substances.BURN_SECONDS, wizard)


## Breathes deeply: a mend of a few seconds that any blow ends.
static func breathe(wizard: Wizard) -> void:
	wizard.mending.begin("breathe")
	Sfx.cue("Breathe", "mend", wizard.center(), -4.0)
	_aura(wizard, "breathe", Color(0.92, 0.97, 1.0, 0.55), "smoke_01")


## Covers the wizard in healing mud: a mend of some seconds that nothing ends.
static func mud_mask(wizard: Wizard) -> void:
	wizard.mending.begin("mud_mask")
	Sfx.cue("Mud Mask", "mend", wizard.center(), -4.0)
	_aura(wizard, "mud_mask", Color(0.42, 0.3, 0.2, 0.9), "dirt_01")


## Motes that go about the wizard for as long as their heal goes on.
static func _aura(wizard: Wizard, kind: String, color: Color, texture: String) -> void:
	for old in wizard.get_children():
		if old is MendAura and old.kind == kind:
			old.queue_free()
	var aura := MendAura.new()
	aura.kind = kind
	aura.color = color
	aura.texture_name = texture
	wizard.add_child(aura)

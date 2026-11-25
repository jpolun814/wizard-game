class_name Motion
extends RefCounted

## The laws of how a spell moves a body, one for each way it can (docs/handoff/24_spell_terms.md). The numbers are in the spell's own data (`Spell.parts`). The game moves the
## body by these, and the AI works out where a spell would take it by these too, so the two cannot disagree: nothing here knows one spell from another.


## The effect of this kind that a spell has (`drive`, `lift`, `throw`...), with where and when its part acts, or nothing.
static func of(spell_name: String, term: String) -> Dictionary:
	return SpellData.SPELLS[spell_name].effect_of(term)


## One number of an effect of a spell.
static func number(spell_name: String, term: String, key: String) -> float:
	return float(of(spell_name, term)[key])


## drive: how fast it takes the body along at this many seconds since it began. It is at `speed` all the while, or, where it `grows`, climbs to that by its end.
static func drive_speed(drive: Dictionary, since: float) -> float:
	var share := clampf(since / float(drive["for"]), 0.0, 1.0)
	return float(drive["speed"]) * pow(share, float(drive.get("grows", 0.0)))


## lift: the speed up and down of a body in it, a moment later (up is below 0).
static func lifted(lift: Dictionary, velocity_y: float, delta: float) -> float:
	return maxf(velocity_y - float(lift["pull"]) * delta, -float(lift["speed"]))


## carry: how far along a stroke this long it takes the body at once.
static func carried(carry: Dictionary, length: float) -> float:
	return minf(length, float(carry["most"]))


## throw: the shove it gives, along a way (a unit vector). `who` picks the speed for a kind of body that is thrown differently ("creatures", "things"), where the spell has one.
static func thrown(throw: Dictionary, along: Vector2, who := "speed") -> Vector2:
	return along * float(throw.get(who, throw["speed"]))

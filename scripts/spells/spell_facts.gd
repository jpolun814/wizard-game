class_name SpellFacts
extends RefCounted

## What a spell is worth to a wizard who has to choose one, worked out from the spell's own numbers (its `Spell` resource: cost, damage, speed, warning, span, pellets) and nothing else,
## so that changing a spell's cost or damage changes the AI's choices with no new measurement. The AI's temperament (how fast a rival gets out of the way, how much it minds spending)
## is the only thing assumed, and it is written here, once, as figures about the rival and the wizard, never about a spell.

## Seconds in which a rival who can move has got out of the way of what is coming at them: the chance that a thing which needs `t` seconds to land still lands is e^(-t / REACTION).
## (Measured on the AI's own play: single shots at 0.3 to 0.5 seconds' flight landed on 55 to 60% of the wizards they were thrown at.)
const REACTION := 0.8  # (the owner's own play, 33 matches: from a shot coming within 400 px to a turn or a jump, median 0.88 s, quartiles 0.52 to 1.37; `tools/measure_people.py`, 2026-11-24)
## A rival standing still is at least this likely to be struck, whatever the delay.
const STANDING_FLOOR := 0.75
## How wide a body is for a spread of pieces to catch it, in pixels.
const BODY := 48.0
## Seconds one attack takes a wizard from the start of its stroke to the next: what a held rival could be made to take in each second of it.
const CYCLE := 1.5
## A blow that comes at a wizard in a fight does about this much, and one comes this many seconds apart at the most pressing (what a rival's shots have done, taken from the spells).
const TYPICAL_BLOW := 14.0
const BLOW_GAP := 1.5
## A cast that is expected to do less than this much harm (in damage, counting what a hold gives) is not worth the stamina, and is not cast: the numbers know what it does.
const MIN_EXPECTED := 1.0
## How often an attack lands on a rival who is free to move (the figure measured on the AI's own shots, 55 to 60%): holding a rival only wins what the attacks would have missed.
const FREE_LANDING := 0.6  # (measured again, 2026-11-24, `tools/measure_people.py`: shots at an AI wizard land 49% moving and 66% standing, 1,745 shots; at the owner only 16% and 23%, 503 shots: a person is about three times harder to hit)

static var _cache := {}


## The parts of a damage line: {"direct": 5.0, "per_sec": 6.0} from "5 dmg + 6 dmg/sec", or zeros for a spell that deals none ("Kills" counts as a great deal, 200).
static func parse_damage(text: String) -> Dictionary:
	var out := {"direct": 0.0, "per_sec": 0.0}
	if text == "":
		return out
	if text == "Kills":
		out["direct"] = 200.0
		return out
	for part in text.split("+"):
		var words := part.strip_edges().split(" ")
		if words.size() >= 2 and words[0].is_valid_float():
			if words[1].begins_with("dmg/sec"):
				out["per_sec"] += words[0].to_float()
			elif words[1].begins_with("dmg"):
				out["direct"] += words[0].to_float()
	return out


## The parts of a heal line ("+55 max stamina", "+3 max stamina/sec"): {"at_once": 55.0, "per_sec": 0.0}.
static func parse_heal(text: String) -> Dictionary:
	var out := {"at_once": 0.0, "per_sec": 0.0}
	var words := text.strip_edges().replace("+", "").split(" ")
	if words.size() >= 3 and words[0].is_valid_float():
		if words[-1].ends_with("/sec"):
			out["per_sec"] = words[0].to_float()
		else:
			out["at_once"] = words[0].to_float()
	return out


## What a heal costs the one who takes it besides the stamina paid, in maximum stamina, from the states it leaves on them: a burn does its bites for its seconds (the law of fire, `Substances`).
static func harm_after(spell_name: String, wet: bool) -> float:
	var spell: Spell = SpellData.SPELLS[spell_name]
	if "burning" in spell.applies and not wet:
		return float(Substances.BURN_DAMAGE) / Substances.BURN_GAP * Substances.BURN_SECONDS
	return 0.0


## What a heal leaves a wizard with, in maximum stamina, all of it given: what it mends at once and over its span, less what it costs afterwards. Zero for a spell that does not heal.
static func net_heal(spell_name: String, wet: bool) -> float:
	var spell: Spell = SpellData.SPELLS[spell_name]
	var parts := parse_heal(spell.heal)
	var given: float = parts["at_once"] + parts["per_sec"] * spell.span
	return maxf(given - harm_after(spell_name, wet), 0.0)


## A heal's worth to a wizard who is `deficit` of maximum stamina short: what it can give that is of use (no more than is missing), for each point of stamina it costs.
static func heal_worth(spell_name: String, deficit: float, wet: bool) -> float:
	var spell: Spell = SpellData.SPELLS[spell_name]
	return minf(net_heal(spell_name, wet), maxf(deficit, 0.0)) / maxf(spell.cost, 1.0)


## Whether a spell has the figures to be judged by: damage, and at least one of how it travels, lands or lingers; or the seconds it holds a rival for.
static func known(spell_name: String) -> bool:
	if controls(spell_name):
		return true
	if not damages(spell_name):
		return false
	var spell: Spell = SpellData.SPELLS[spell_name]
	return spell.speed > 0.0 or spell.warning > 0.0 or spell.span > 0.0 or spell.pellets > 1 or spell.reach > 0.0


## Whether the spell holds or hobbles a rival for a time (it has `hold` seconds): that is what it is worth, besides any harm of its own.
static func controls(spell_name: String) -> bool:
	var spell: Spell = SpellData.SPELLS.get(spell_name)
	return spell != null and spell.hold > 0.0 and spell.share > 0.0


## What one cast takes from a rival in damage-equivalent: for each second they are held, the share of what the wizard could have dealt in that second (`rate`, its best
## damage a second) that it would not have dealt anyway to a rival free to move.
static func control_value(spell_name: String, rate: float) -> float:
	var spell: Spell = SpellData.SPELLS[spell_name]
	return spell.hold * spell.share * rate * (1.0 - FREE_LANDING)


## The damage a second the wizard could deal with the attacks it is thinking of, at this distance: the best of them, spread over the time it takes to draw and cast one.
## `stamina` (when it is given, 0 or more) is what the wizard would have in hand to pay for them over the next `hold` seconds: an attack that costs more than that
## can be cast only as often as the stamina allows (it does not come back while the wizard is casting), so a wizard that is nearly spent can deal little however strong its book.
static func damage_rate(spell_names: Array, gap: float, stamina := -1.0, hold := 4.0) -> float:
	var best := 0.0
	for spell_name: String in spell_names:
		if damages(spell_name) and not controls(spell_name):
			var per_second := 1.0 / CYCLE
			if stamina >= 0.0:
				per_second = minf(per_second, stamina / (maxf(SpellData.SPELLS[spell_name].cost, 1.0) * maxf(hold, 1.0)))
			best = maxf(best, total(spell_name, gap) * per_second)
	return best


## Whether the spell has damage figures to judge it by.
static func damages(spell_name: String) -> bool:
	var spell: Spell = SpellData.SPELLS.get(spell_name)
	if spell == null:
		return false
	var parts := parse_damage(spell.damage)
	return parts["direct"] > 0.0 or parts["per_sec"] > 0.0


## The most one cast can do to one rival who does not get away, in damage: what it deals at once for each piece that finds them, and what keeps coming for its span.
static func total(spell_name: String, gap: float) -> float:
	var spell: Spell = SpellData.SPELLS[spell_name]
	var parts := parse_damage(spell.damage)
	var pieces := 1.0
	if spell.pellets > 1 and spell.spread > 0.0:
		var arc := maxf(gap, 60.0) * spell.spread
		pieces = clampf(BODY / (arc / float(spell.pellets - 1)), 1.0, float(spell.pellets))
	return parts["direct"] * pieces + parts["per_sec"] * spell.span


## The chance that one cast finds a rival: nothing needs to land for one who is held, a standing rival is easy, and for a moving one it falls with the seconds before the harm arrives.
static func chance(spell_name: String, gap: float, held: bool, standing: bool) -> float:
	var spell: Spell = SpellData.SPELLS[spell_name]
	if held:
		return 1.0
	var seconds := spell.warning + (gap / spell.speed if spell.speed > 0.0 else 0.0)
	var p := exp(-seconds / REACTION)
	return maxf(p, STANDING_FLOOR) if standing else p


## What a defense is worth: the harm it takes away before it is spent, for each point of stamina it costs. A time-based one takes `absorbs` of the harm that comes at the wizard
## (`incoming`, damage a second) for the seconds it lasts; one that stands until blows have come takes `blows` of them, `blow` damage each.
static func defense_worth(spell_name: String, incoming: float, blow: float, scarcity: float, minding: float) -> float:
	var spell: Spell = SpellData.SPELLS[spell_name]
	var saved := spell.lasts * incoming * spell.absorbs + float(spell.blows) * blow * maxf(spell.absorbs, 0.0)
	if saved <= 0.0:
		return 0.0
	var k := clampf(scarcity, 0.0, 1.0) * minding
	return pow(saved, 1.0 + k) / pow(maxf(spell.cost, 1.0), k)


## Whether the spell is a defense with figures to be judged by.
static func defends(spell_name: String) -> bool:
	var spell: Spell = SpellData.SPELLS.get(spell_name)
	return spell != null and spell.absorbs > 0.0 and (spell.lasts > 0.0 or spell.blows > 0)


## The spells (and chants, which cost no stamina, and a plain leap) in the order of what they cost, the cheapest first, those that cost alike in the order given. When several do the
## same job (open a gate, get across a pit, screen a shooter) the wizard takes the cheapest that it knows: the order is the spells' own cost, so a change of cost moves it.
static func cheapest_first(names: Array) -> Array:
	var order := []
	for index in names.size():
		var name: String = names[index]
		var spell: Spell = SpellData.SPELLS.get(name)
		order.append([spell.cost if spell != null else 0.0, index, name])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return order.map(func(entry: Array) -> String: return entry[2])


## Its worth now: the damage it can be expected to do, the more weighed against its cost the less the wizard has in hand. `scarcity` is 0 when there is plenty and 1 when it is nearly out:
## `rate` is the damage a second the wizard could deal (see `damage_rate`), which a control spell takes from a rival for the seconds it holds them. `touch` is for a rival that one blow of any size undoes (a werewolf: its strength is a single point). With plenty, what a spell can do decides, and as stamina runs down, what it does for each point spent does (damage squared for the choice, over the cost to the power of the scarcity).
static func worth(spell_name: String, gap: float, held: bool, standing: bool, scarcity: float, minding: float, touch := false, rate := 0.0) -> float:
	var spell: Spell = SpellData.SPELLS[spell_name]
	var expected := expected_harm(spell_name, gap, held, standing, touch, rate)
	if expected <= 0.0:
		return 0.0
	var k := clampf(scarcity, 0.0, 1.0) * minding
	return pow(expected, 1.0 + k) / pow(maxf(spell.cost, 1.0), k)


## What one cast is expected to do to the rival, in damage: the harm it can do (and the time a hold gives, see `control_value`), by the chance that it finds them.
## A rival already held has nothing more to be taken from them, so a control spell is worth nothing against one; `touch`: any blow at all undoes the rival, so how much it deals does not matter, only that it lands.
static func expected_harm(spell_name: String, gap: float, held: bool, standing: bool, touch := false, rate := 0.0) -> float:
	var harm := 1.0 if touch and total(spell_name, gap) > 0.0 else total(spell_name, gap)
	return (harm + (0.0 if touch or held else control_value(spell_name, rate))) * chance(spell_name, gap, held, standing)

class_name Substances
extends RefCounted

## What clings to a body, and the laws about it, for EVERY body: a wizard's and a creature's alike. A body keeps three timed conditions, `wet_time`, `burning_time`
## and `oiled_time` (and `is_wet()`, `is_burning()`, `is_oiled()`), and says how it is bitten by a burn (`burn_bite(damage, by)`). Everything below works on those
## and nothing else, so it does not matter who or what the body is, or which spell put the water, the flame or the oil there:
##   water puts a flame on the body out; a wet body cannot be set alight and takes lightning harder; ice holds it longer
##   a flame sets it alight (twice as long when it is oiled, and the oil burns away)
##   being in water, or under rain, makes a body wet (and so does any water that touches it: Elements)
## The laws are worked here and only here. (A wizard's `Coating` only shows them and keeps the wizard's own extras: breath, swimming.)

const WET_SECONDS := 8.0
const BURN_SECONDS := 5.0
const OIL_SECONDS := 10.0
const BURN_DAMAGE := 3          # each time a burn bites
const BURN_GAP := 0.5           # seconds between bites
const OILED_BURN := 2.0         # an oiled body burns this many times as long
const SHOCK := 1.6              # how much harder lightning strikes a wet body
const FREEZE_WET := 1.5         # how much longer ice holds a wet body
const CHILL_WET := 2.0          # how much faster a snowstorm freezes a wet body


static func alive(body: Node) -> bool:
	return is_instance_valid(body) and not (body.has_method("is_dead") and body.is_dead()) and not ("dead" in body and body.dead) and not (body.has_method("is_likeness") and body.is_likeness())


## Water on the body. It puts out any flame on it.
static func soak(body: Node, seconds := WET_SECONDS) -> void:
	if not alive(body):
		return
	if body.burning_time > 0.0:
		put_out(body)
	body.wet_time = maxf(body.wet_time, seconds)


## Fire on the body for as long as the fire's flames last. A wet body cannot be lit. Oil on the body burns longer, and burns away.
static func ignite(body: Node, seconds := BURN_SECONDS, by: Node = null) -> void:
	if not alive(body) or body.wet_time > 0.0 or (body.has_method("immune_to") and body.immune_to(Damage.HEAT)):
		return
	if body.oiled_time > 0.0:
		seconds *= OILED_BURN
		body.oiled_time = 0.0
	if body.burning_time <= 0.0:
		Sfx.cue("coating", "fire", body.center(), -6.0)
	body.burning_time = maxf(body.burning_time, seconds)
	body.set_meta("burnt_by", by)


## Oil on the body.
static func oil(body: Node, seconds := OIL_SECONDS) -> void:
	if alive(body):
		body.oiled_time = maxf(body.oiled_time, seconds)


## Lightning on a wet body strikes harder.
static func shocked(body: Node, amount: int) -> int:
	return roundi(amount * SHOCK) if body.is_wet() else amount


## How long ice holds the body: longer when it is wet.
static func frozen_for(body: Node, seconds: float) -> float:
	return seconds * FREEZE_WET if body.is_wet() else seconds


## Water that washes the body clean: what clings to it or ails it is rinsed away. A flame, oil, a chill, a tangle, a curse, a wound, a daze, a fright and a
## hunter on its heels (a snail) all go. Leaves it dry: soak it after, if the water stays on it.
static func wash(body: Node) -> void:
	if not alive(body):
		return
	if body.burning_time > 0.0:
		put_out(body)
	body.oiled_time = 0.0
	for state in ["slow_time", "daze_time", "sink_time", "tangle_time", "rage_time", "fear_time", "drained_time"]:
		if state in body:
			body.set(state, 0.0)
	var tree := body.get_tree()
	var curse := Hex.on(tree, body)
	if curse != null:
		curse.queue_free()
	var wound := Hemorrhage.on(tree, body)
	if wound != null:
		wound.queue_free()
	for snail: InvincibleSnail in tree.get_nodes_in_group("snails"):
		if snail.target == body:
			snail.lose_scent()


## What a deep rest or a second chance takes off a body: every ill on it but the two that follow it anywhere, a curse (a Hex) and a snail on its heels. A flame, oil,
## ice, a chill, a tangle, a daze, a held tongue, a fright, a wound and the breath all go. (A Hex and a snail are left to run their course, owner 2026-11-22.)
static func relieve(body: Node) -> void:
	if not alive(body):
		return
	if body.burning_time > 0.0:
		put_out(body)
	body.oiled_time = 0.0
	for state in ["slow_time", "daze_time", "sink_time", "tangle_time", "rage_time", "fear_time", "drained_time", "mute_time", "root_time", "blind_time"]:
		if state in body:
			body.set(state, 0.0)
	if body.has_method("thaw"):
		body.thaw()
	if "lungs" in body:
		body.lungs.smother(false)
	var wound := Hemorrhage.on(body.get_tree(), body)
	if wound != null:
		wound.queue_free()


static func put_out(body: Node) -> void:
	body.burning_time = 0.0
	Fx.smoke(body.get_parent(), body.center(), Color(0.88, 0.92, 0.96, 0.5), 3, 18.0, 36.0)
	Sfx.cue("quench", "steam", body.center(), -6.0)


## Every physics frame, for a creature (a wizard's own frame is `Coating.tick`, which asks the same of this): water on or around it, the bites of a burn,
## and the show of each.
static func live(body: Node, delta: float) -> void:
	if not alive(body) or not body.is_inside_tree():
		return
	var at: Vector2 = body.center()
	var tree := body.get_tree()
	var left: float = body.get_meta("substance_look", 0.0) - delta
	if body.is_burning():
		var bite: float = body.get_meta("burn_in", BURN_GAP) - delta
		if bite <= 0.0:
			bite = BURN_GAP
			var by: Variant = body.get_meta("burnt_by") if body.has_meta("burnt_by") else null  # (a default of null is read by the engine as "no default": an error)
			body.burn_bite(BURN_DAMAGE, by if is_instance_valid(by) else null)
		body.set_meta("burn_in", bite)
	if left <= 0.0:
		left = 0.1
		if Elements.soaked_at(tree, at):
			soak(body, 1.0)
		show(body)
	body.set_meta("substance_look", left)


## What the water, the oil and the flames on a body look like.
static func show(body: Node) -> void:
	var at: Vector2 = body.center()
	var parent := body.get_parent()
	if body.is_wet():
		Fx.burst(parent, at + Vector2(Dice.looks.randf_range(-10.0, 10.0), -8.0), Color(0.6, 0.8, 1.0, 0.9), 2, 30.0, 0.5, false)
	if body.is_oiled():
		Fx.burst(parent, at + Vector2(Dice.looks.randf_range(-10.0, 10.0), -4.0), Color(0.08, 0.06, 0.1, 0.95), 2, 22.0, 0.6, false)
	if body.is_burning():
		Fx.burst(parent, at + Vector2(Dice.looks.randf_range(-12.0, 12.0), -6.0), Color(1.0, 0.55, 0.15, 0.95), 4, 70.0, 0.5, true)

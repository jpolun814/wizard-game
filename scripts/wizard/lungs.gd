class_name Lungs
extends RefCounted

## A wizard's air, and the water around it: whether the head is under the surface, how long the breath lasts, and what happens when it is gone. Reached as
## `wizard.lungs`.

const BREATH := 8.0  # seconds under water before the wizard starts to drown
const DEEP_BREATH := 45.0  # seconds the Blessing of the Deep Breath holds the wizard's breath: it counts down from the chant
const DROWN_RATE := 3.0  # most stamina lost per second while out of breath, and it does not come back by itself
const HEAD_BELOW := 10.0  # the head is under when the surface is this far above the top of the hood

var wizard: Wizard
var air := BREATH  # seconds of air left while the breath is held without the Blessing of the Deep Breath
var smothered := false  # the air is drawn out of the wizard's lungs (Vacuum sets and clears this)
var _time := 0.0
var _surface := INF  # the height of the surface of that liquid
var _lava := false


func _init(owner_wizard: Wizard) -> void:
	wizard = owner_wizard


## Standing in water or lava: counts for a moment after each call, so leaving it is noticed at once.
func soak(surface_y: float, lava: bool) -> void:
	_surface = surface_y
	_lava = lava
	_time = 0.15


## The moment of being wet runs out, unless the liquid says again.
func dry(delta: float) -> void:
	_time = maxf(_time - delta, 0.0)


## The height of the surface of the water the wizard is in, or INF when it is in none.
func surface() -> float:
	return _surface if _time > 0.0 and not _lava else INF


## True when the wizard's head is under the surface of water.
func submerged() -> bool:
	return _time > 0.0 and not _lava and wizard.global_position.y - Wizard.BODY_HEIGHT + HEAD_BELOW > _surface


## True while the wizard holds their breath, for any reason: under water, in the Blessing of the Deep Breath, in a block of ice, or with the air drawn out of
## them. Gas does no harm to anyone holding their breath, and nobody can chant.
func holding() -> bool:
	return submerged() or smothered or wizard.deep_breath_time > 0.0 or wizard.is_frozen() or wizard.golem.on  # (stone does not breathe)


## The air is drawn out of the wizard's lungs, or let back in. They hold their breath as they do under water, with what air they have.
func smother(on: bool) -> void:
	smothered = on


## The chant cannot be said under water, so the lungs are full when it takes hold, and breathing starts again, full, when it ends.
func grant_deep(seconds: float) -> void:
	wizard.deep_breath_time = seconds
	air = BREATH


## While the breath is held (under water, or with the air drawn out) the air runs down, and once it is gone the most stamina does too, until the wizard breathes
## again. That loss is only made good the usual ways. The Blessing of the Deep Breath holds the breath without using the air.
func tick(delta: float) -> void:
	if wizard.dead:
		return
	if wizard.deep_breath_time > 0.0 or wizard.golem.on:
		air = BREATH
	elif submerged() or smothered or wizard.is_frozen():  # (in a block of ice there is no breathing either)
		if air > 0.0:
			air = maxf(air - delta, 0.0)
		else:
			wizard.drown(DROWN_RATE * delta)
	else:
		air = minf(air + delta * BREATH * 2.0, BREATH)

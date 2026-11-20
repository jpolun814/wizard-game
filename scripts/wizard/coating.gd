class_name Coating
extends RefCounted

## What clings to a wizard's body: water (wet), flame (burning) and oil (oiled). Reached as `wizard.coat`. Each is a timed condition (`Wizard.wet_time` and
## its two fellows) that spells put on a wizard and other spells answer: a wet wizard cannot be set alight and takes lightning hard, water puts out a burning
## wizard, and an oiled one burns twice as long. The wizard shows each on its body (drips, flames, black beads) and the status ring shows it too.
## Only the machine that drives the wizard decides these; the others are told through `Wizard.marks` and only show them.

const WET_SECONDS := 8.0
const BURN_SECONDS := 5.0
const OIL_SECONDS := 10.0
const BURN_DAMAGE := 3          # each time it bites
const BURN_GAP := 0.5           # seconds between bites
const OILED_BURN := 2.0         # an oiled wizard burns this many times as long
const SHOCK := 1.6              # how much harder lightning strikes a wet wizard
const CHILL_WET := 2.0           # how much faster a snowstorm freezes a wet wizard
const FREEZE_WET := 1.5        # how much longer ice holds a wet wizard

var wizard: Wizard
var _burn_in := 0.0
var _by: Wizard                 # whose fire it is, for the count of what each wizard has done
var _flames: BodyFlames
var _show_in := 0.0
var _rain := 0.0


func _init(owner_wizard: Wizard) -> void:
	wizard = owner_wizard


## Water on the body. It puts out any flame on it.
func soak(seconds := WET_SECONDS) -> void:
	if wizard.dead or wizard.is_likeness():
		return
	if wizard.burning_time > 0.0:
		_put_out()
	wizard.wet_time = maxf(wizard.wet_time, seconds)


## Fire on the body, for as long as the fire's flames last. A wet wizard cannot be lit. Oil on the body burns longer, and burns away.
func ignite(seconds := BURN_SECONDS, by: Node = null) -> void:
	if wizard.dead or wizard.is_likeness() or wizard.wet_time > 0.0:
		return
	if wizard.oiled_time > 0.0:
		seconds *= OILED_BURN
		wizard.oiled_time = 0.0
	if wizard.burning_time <= 0.0:
		Sfx.cue("coating", "fire", wizard.center(), -6.0)
	wizard.burning_time = maxf(wizard.burning_time, seconds)
	_by = SpellTargets.striker_of(by)


## Oil on the body.
func oil(seconds := OIL_SECONDS) -> void:
	if wizard.dead or wizard.is_likeness():
		return
	wizard.oiled_time = maxf(wizard.oiled_time, seconds)


## Lightning on a wet body strikes harder.
func shocked(amount: int) -> int:
	return roundi(amount * SHOCK) if wizard.is_wet() else amount


## How long ice holds the body: longer when it is wet.
func frozen_for(seconds: float) -> float:
	return seconds * FREEZE_WET if wizard.is_wet() else seconds


func _put_out() -> void:
	wizard.burning_time = 0.0
	Fx.smoke(wizard.get_parent(), wizard.center(), Color(0.88, 0.92, 0.96, 0.5), 3, 18.0, 36.0)
	Sfx.cue("coating", "ice", wizard.center(), -10.0)


## Every physics frame: the bites of a burn, water putting a flame out, and the show of each.
func tick(delta: float) -> void:
	var burning := wizard.is_burning()
	if not wizard.is_likeness():
		if burning:
			if wizard.lungs.submerged() or wizard.swim_time > 0.0:
				_put_out()
				burning = false
			else:
				_burn_in -= delta
				if _burn_in <= 0.0:
					_burn_in = BURN_GAP
					MatchStats.strike(_by)
					wizard.take_damage(BURN_DAMAGE, false)
		elif wizard.lungs.submerged() or wizard.swim_time > 0.0:
			soak(1.0)  # in the water a body is wet
		_rain -= delta
		if _rain <= 0.0:
			_rain = 0.5
			if _in_rain():
				soak(3.0)
	_show(delta, burning)


func _show(delta: float, burning: bool) -> void:
	if burning and (_flames == null or not is_instance_valid(_flames)):
		_flames = BodyFlames.new()
		wizard.add_child(_flames)
	elif not burning and _flames != null and is_instance_valid(_flames):
		_flames.queue_free()
		_flames = null
	_show_in -= delta
	if _show_in > 0.0 or wizard.dead or not wizard.is_inside_tree():
		return
	_show_in = 0.18
	var at := wizard.center()
	var parent := wizard.get_parent()
	if wizard.is_wet():
		Fx.burst(parent, at + Vector2(randf_range(-10.0, 10.0), -8.0), Color(0.6, 0.8, 1.0, 0.9), 2, 30.0, 0.5, false)
	if wizard.is_oiled():
		Fx.burst(parent, at + Vector2(randf_range(-10.0, 10.0), -4.0), Color(0.08, 0.06, 0.1, 0.95), 2, 22.0, 0.6, false)
	if burning:
		Fx.burst(parent, at + Vector2(randf_range(-12.0, 12.0), -6.0), Color(1.0, 0.55, 0.15, 0.95), 4, 70.0, 0.5, true)


## True under open sky while a downpour is falling.
func _in_rain() -> bool:
	if not wizard.is_inside_tree():
		return false
	var falling := false
	for squall: Squall in wizard.get_tree().get_nodes_in_group("squalls"):
		if squall.rain and squall.level() > 0.3:
			falling = true
	if not falling:
		return false
	var query := PhysicsRayQueryParameters2D.create(wizard.center(), wizard.center() + Vector2(0.0, -700.0))
	query.collision_mask = 1
	return wizard.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

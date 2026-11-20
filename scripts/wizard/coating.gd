class_name Coating
extends RefCounted

## What clings to a wizard's body: water (wet), flame (burning) and oil (oiled). Reached as `wizard.coat`. Each is a timed condition (`Wizard.wet_time` and
## its two fellows) that spells put on a wizard and other spells answer: a wet wizard cannot be set alight and takes lightning hard, water puts out a burning
## wizard, and an oiled one burns twice as long. The wizard shows each on its body (drips, flames, black beads) and the status ring shows it too.
## Only the machine that drives the wizard decides these; the others are told through `Wizard.marks` and only show them.

const WET_SECONDS := Substances.WET_SECONDS  # (the laws and their numbers are `Substances`: these names stay for those who ask a wizard)
const BURN_SECONDS := Substances.BURN_SECONDS
const OIL_SECONDS := Substances.OIL_SECONDS
const BURN_DAMAGE := Substances.BURN_DAMAGE
const BURN_GAP := Substances.BURN_GAP
const CHILL_WET := Substances.CHILL_WET
const SHOCK := Substances.SHOCK
const FREEZE_WET := Substances.FREEZE_WET

var wizard: Wizard
var _burn_in := 0.0
var _by: Wizard                 # whose fire it is, for the count of what each wizard has done
var _flames: BodyFlames
var _show_in := 0.0
var _rain := 0.0


func _init(owner_wizard: Wizard) -> void:
	wizard = owner_wizard


func soak(seconds := WET_SECONDS) -> void:
	Substances.soak(wizard, seconds)


func ignite(seconds := BURN_SECONDS, by: Node = null) -> void:
	Substances.ignite(wizard, seconds, by)
	_by = SpellTargets.striker_of(by)


func oil(seconds := OIL_SECONDS) -> void:
	Substances.oil(wizard, seconds)


func shocked(amount: int) -> int:
	return Substances.shocked(wizard, amount)


func frozen_for(seconds: float) -> float:
	return Substances.frozen_for(wizard, seconds)


func _put_out() -> void:
	Substances.put_out(wizard)


## Every physics frame: the bites of a burn, water putting a flame out, and the show of each.
func tick(delta: float) -> void:
	var burning := wizard.is_burning()
	if not wizard.is_likeness():
		if Elements.soaked_at(wizard.get_tree(), wizard.center()):
			soak(3.0)  # any water that touches the body, from whatever spell or pond it comes: a burn is put out at once
			burning = wizard.is_burning()
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

class_name LearnedBrain
extends WizardBrain

## A wizard whose footwork is learned. Everything else it does is the scripted brain's (what it goes for, its spells, its chants, its reflexes), but the legs
## are told what to do by a trained policy, through the agent (training/wizard_agent.gd): walk left or right or stand, and jump or not, a few times a second.
## The scripted route is still followed for what it must do alone: a stair that swings, a vine, a drop through a platform.

var move := 0.0    # -1, 0 or 1: what the policy asks of the legs, kept until it asks again
var jump := false  # a jump asked for, made once when the wizard is on the ground
var learned := false  # a policy has given its first action: until then the scripted legs play


func _steer(delta: float) -> Dictionary:
	var steer := _route.steer(wizard, delta)
	if not learned or _route.riding() or steer["climb"] or steer["let_go"] or steer["drop"] or steer["replan"] or _route.waiting_for_stair:
		return steer
	steer["dir"] = move
	steer["speed"] = WALK_SPEED
	steer["jump"] = jump and wizard.is_on_floor()
	jump = false
	return steer

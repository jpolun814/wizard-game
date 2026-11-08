class_name LearnedBrain
extends WizardBrain

## A wizard whose footwork is learned. Everything else it does is the scripted brain's (what it goes for, its spells, its chants, its reflexes), but the legs
## are told what to do by a trained policy, through the agent (training/wizard_agent.gd): walk left or right or stand, and jump or not, a few times a second.
## The scripted route is still followed for what it must do alone: a stair that swings, a vine, a drop through a platform.

var move := 0.0    # -1, 0 or 1: what the policy asks of the legs, kept until it asks again
var jump := false  # a jump asked for, made once when the wizard is on the ground
var learned := false  # a policy has given its first action: until then the scripted legs play
var policy: PolicyNet  # a trained network run here, in the game; when the trainer drives it (training/wizard_agent.gd) this stays empty
var _decide_in := 0.0
static var _shared_net: PolicyNet


## The network that plays the legs of a match's AI wizards when the setting asks for it (ai/footwork.json, written by training/export_policy.py).
static func footwork() -> PolicyNet:
	if _shared_net == null:
		_shared_net = PolicyNet.load_file("res://ai/footwork.json")
	return _shared_net

const WAYPOINTS := 4
const DECISION_EVERY := 0.1  # seconds between the policy's choices


## What it senses (Sensing, which is also what is written into a person's recording), and the next few tiles of the way the scripted route is going, as a hint.
func observe() -> PackedFloat32Array:
	var obs := Sensing.observe(wizard)
	var here := Vector2i(floori(wizard.global_position.x / WizardRoute.TILE), floori((wizard.global_position.y - 1.0) / WizardRoute.TILE))
	for i in WAYPOINTS:
		var tile := _route.ahead(i)
		if tile == WorldNav.NONE:
			obs.append_array([0.0, 0.0, 0.0])
		else:
			obs.append_array([clampf(float(tile.x - here.x) / 12.0, -2.0, 2.0), clampf(float(tile.y - here.y) / 12.0, -2.0, 2.0), 1.0])
	obs.append(clampf(float(_route.remaining()) / 100.0, 0.0, 2.0))
	return obs


## The policy's choice, when there is one here: asked a few times a second.
func _decide(delta: float) -> void:
	_decide_in -= delta
	if _decide_in > 0.0:
		return
	_decide_in = DECISION_EVERY
	var obs := observe()
	if policy.inputs() == Sensing.SIZE:
		obs.resize(Sensing.SIZE)  # (a policy learned from people's recordings sees only what the recording held)
	var logits := policy.forward(obs)
	move = float(policy.choose(logits, "move") - 1)
	if policy.choose(logits, "jump") == 1:
		jump = true
	learned = true


func _steer(delta: float) -> Dictionary:
	var steer := _route.steer(wizard, delta)
	if policy != null:
		_decide(delta)
	if not learned or _route.riding() or steer["climb"] or steer["let_go"] or steer["drop"] or steer["replan"] or _route.waiting_for_stair:
		return steer
	steer["dir"] = move
	steer["speed"] = WALK_SPEED
	steer["jump"] = jump and wizard.is_on_floor()
	jump = false
	return steer

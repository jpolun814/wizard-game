class_name WizardAgent
extends AIController2D

## What a learning wizard senses, asks for and is rewarded for, for Godot RL Agents (addons/godot_rl_agents). It is the link between a wizard
## with a LearnedBrain and the trainer in Python. A decision is made every Sync.action_repeat physics frames.
##
## Senses (all scaled to about -1..1): its own speed, stamina and whether it stands; the next few tiles of the way it is going (where the scripted
## route would have it go: the policy has to find out how to get there); the ground about it (solid, a platform, or lethal) in a box of tiles round the feet; the nearest rival.
## Asks: left, stand or right; and a jump or not.
## Rewarded for: getting along its way, reading pages, and keeping its stamina; punished for being hurt and for jumping (it costs stamina), and for dying.

const WAYPOINTS := 4
const SEE_RIVAL := 700.0

var wizard: Wizard
var brain: LearnedBrain
var start := Vector2.ZERO  # where it stands again after it has fallen
var _last_remaining := -1
var _last_pages := 0
var _last_max := 200.0
var _last_goal := Vector2i(-999999, -999999)
var _spent := 0.0  # reward gathered since the trainer last asked for it
var deaths := 0
static var scripted := false  # the scripted legs play (to measure what a policy has to beat)
var _fallen := false  # it has died and been counted: it stands up again once the trainer has been told
var cause := {"progress": 0.0, "pages": 0.0, "hurt": 0.0, "death": 0.0, "jump": 0.0}  # what the reward came from, to see what a learner is doing


func init_for(body: Wizard) -> void:
	wizard = body
	brain = body.brain as LearnedBrain
	start = body.global_position
	_last_pages = body.ledger.count()
	_last_max = body.max_stamina
	reset_after = 3000  # decisions: about five minutes of play


func get_obs_space() -> Dictionary:
	return {"obs": {"size": [get_obs()["obs"].size()], "space": "box"}}


## What it senses (Sensing, which is also what is written into a person's recording), and the next few tiles of the way the scripted route is going, as a hint.
func get_obs() -> Dictionary:
	var seen := PackedFloat32Array()
	if brain != null and wizard != null and is_instance_valid(wizard):
		seen = brain.observe()
	else:
		seen.resize(Sensing.SIZE + LearnedBrain.WAYPOINTS * 3 + 1)
	var obs: Array = Array(seen)
	for i in obs.size():
		if is_nan(obs[i]) or is_inf(obs[i]):
			obs[i] = 0.0  # (a number that is not a number turns the whole message to nothing on the way to the trainer)
	return {"obs": obs}


func _nearest_rival() -> Wizard:
	var best: Wizard = null
	var gap := SEE_RIVAL
	for other: Wizard in SpellTargets.wizards(wizard.get_tree()):
		if other != wizard and not other.dead and other.global_position.distance_to(wizard.global_position) < gap:
			gap = other.global_position.distance_to(wizard.global_position)
			best = other
	return best


func get_action_space() -> Dictionary:
	return {"move": {"size": 3, "action_type": "discrete"}, "jump": {"size": 2, "action_type": "discrete"}}


func set_action(action) -> void:
	if brain == null or scripted:
		return
	brain.move = float(int(action["move"]) - 1)
	if int(action["jump"]) == 1 and wizard.is_on_floor():
		brain.jump = true
		cause["jump"] -= 0.05
		_spent -= 0.05  # a jump costs stamina: it should be worth it
	brain.learned = true


func get_reward() -> float:
	_gather()
	var out := _spent
	_spent = 0.0
	return 0.0 if is_nan(out) or is_inf(out) else out


## Adds up what has happened since the last look.
func _gather() -> void:
	if wizard == null or not is_instance_valid(wizard):
		return
	var goal := brain._route.goal()
	var remaining := brain._route.remaining()
	if goal == _last_goal and _last_remaining >= 0:
		cause["progress"] += clampf(float(_last_remaining - remaining), -3.0, 3.0) * 0.1
		_spent += clampf(float(_last_remaining - remaining), -3.0, 3.0) * 0.1  # nearer to where it is going
	_last_goal = goal
	_last_remaining = remaining
	var pages := wizard.ledger.count()
	if pages > _last_pages:
		_spent += 5.0 * float(pages - _last_pages)
	_last_pages = pages
	if wizard.max_stamina < _last_max:
		cause["hurt"] -= (_last_max - wizard.max_stamina) * 0.02
		_spent -= (_last_max - wizard.max_stamina) * 0.02  # hurt
	_last_max = wizard.max_stamina
	if wizard.dead and not done:
		cause["death"] -= 5.0
		_spent -= 5.0
		done = true
		_fallen = true
		deaths += 1
		if deaths == 6:
			print("AGENT ", wizard.name, " dead ", wizard.dead, " at ", wizard.global_position, " max ", wizard.max_stamina, " start ", start, " fallen ", _fallen, " needs ", needs_reset, " layer ", wizard.collision_layer)


## Godot RL Agents sets the flag when the time is up but leaves the standing up to the agent; a wizard that has fallen stands up again after the trainer has been told.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if wizard == null or not is_instance_valid(wizard):
		return
	if needs_reset or (_fallen and not done):
		reset()


func get_info() -> Dictionary:
	return {"deaths": deaths, "pages": wizard.ledger.count() if wizard != null and is_instance_valid(wizard) else 0, "progress": cause["progress"], "jumps": cause["jump"] / -0.05}


## A new life: it stands where it began, whole, with its way chosen again.
func reset() -> void:
	super.reset()
	done = false
	_fallen = false
	if wizard == null or not is_instance_valid(wizard):
		return
	wizard.revive()
	wizard.max_stamina = Wizard.MAX_STAMINA
	wizard.stamina = Wizard.MAX_STAMINA
	wizard.global_position = start
	wizard.velocity = Vector2.ZERO
	brain._route.clear()
	_last_remaining = -1
	_last_max = wizard.max_stamina
	_spent = 0.0

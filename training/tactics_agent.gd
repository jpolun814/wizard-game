class_name TacticsAgent
extends AIController2D

## The link between a wizard with learned tactics (TacticsBrain) and the trainer in Python (Godot RL Agents). A decision is made every
## Sync.action_repeat physics frames.
##
## Senses: what TacticsBrain.observe gives (its screen, its ready attacks, the rival it knows of).
## Asks: which attack (the scripted pick, hold fire, or a spell by name) and how to move in a fight (scripted, close in, keep away, stand).
## Rewarded for what wins a last-wizard-standing match: outliving others (each rival that falls while it stands), not falling, and, a little,
## for pages read and for rivals it can see losing strength while it loses none. Nothing else: the strategy is the learner's to find.

const OUTLIVE := 1.0      # a rival fell while it stands
const FALL := -3.0        # it fell
const PAGE := 0.2         # a page read (a little: pages are a means, not the end)
const HARM := 0.01        # for each point of strength a rival it sees loses, and against each point it loses itself

var wizard: Wizard
var brain: TacticsBrain
var start := Vector2.ZERO
var _spent := 0.0
var _last_pages := 0
var _last_max := 200.0
var _rival_max := {}      # rival instance id -> its maximum strength when last looked at
var _down := {}           # rival instance id -> true while it lies fallen
var _fallen := false
var deaths := 0
var outlived := 0
var cause := {"outlive": 0.0, "fall": 0.0, "pages": 0.0, "harm": 0.0}


func init_for(body: Wizard) -> void:
	wizard = body
	brain = body.brain as TacticsBrain
	start = body.global_position
	_last_pages = body.ledger.count()
	_last_max = body.max_stamina
	reset_after = 3000  # decisions: about ten minutes of play at five a second


func get_obs_space() -> Dictionary:
	return {"obs": {"size": [TacticsBrain.SIZE], "space": "box"}}


func get_obs() -> Dictionary:
	var seen := PackedFloat32Array()
	if brain != null and wizard != null and is_instance_valid(wizard) and wizard.is_inside_tree():
		seen = brain.observe()
	if seen.size() != TacticsBrain.SIZE:
		seen.resize(TacticsBrain.SIZE)
	return {"obs": Array(seen)}


func get_action_space() -> Dictionary:
	return {"cast": {"size": TacticsBrain.CASTS, "action_type": "discrete"}, "mode": {"size": TacticsBrain.MODES, "action_type": "discrete"}}


func set_action(action) -> void:
	if brain == null:
		return
	brain.cast_choice = int(action["cast"])
	brain.mode = int(action["mode"])
	brain.learned = true


func get_reward() -> float:
	_gather()
	var out := _spent
	_spent = 0.0
	return 0.0 if is_nan(out) or is_inf(out) else out


func _add(key: String, amount: float) -> void:
	cause[key] += amount
	_spent += amount


func _gather() -> void:
	if wizard == null or not is_instance_valid(wizard):
		return
	for other: Wizard in wizard.get_tree().get_nodes_in_group("wizards"):
		if other == wizard or other.is_in_group("player"):
			continue
		var id := other.get_instance_id()
		if other.dead and not _down.has(id):
			_down[id] = true
			if not wizard.dead:
				_add("outlive", OUTLIVE)
				outlived += 1
		elif not other.dead:
			_down.erase(id)
		var before: float = _rival_max.get(id, other.max_stamina)
		if other.max_stamina < before and not other.dead and wizard.eyes.sees_wizard(other):
			_add("harm", (before - other.max_stamina) * HARM)
		_rival_max[id] = other.max_stamina
	var pages := wizard.ledger.count()
	if pages > _last_pages:
		_add("pages", PAGE * float(pages - _last_pages))
	_last_pages = pages
	if wizard.max_stamina < _last_max:
		_add("harm", -(_last_max - wizard.max_stamina) * HARM)
	_last_max = wizard.max_stamina
	if wizard.dead and not done:
		_add("fall", FALL)
		done = true
		_fallen = true
		deaths += 1


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if wizard == null or not is_instance_valid(wizard):
		return
	if needs_reset or (_fallen and not done):
		reset()


func get_info() -> Dictionary:
	return {"deaths": deaths, "outlived": outlived, "pages": wizard.ledger.count() if wizard != null and is_instance_valid(wizard) else 0}


## A new life: it stands where it began, whole.
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
	_last_max = wizard.max_stamina
	_spent = 0.0

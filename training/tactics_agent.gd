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
const DUEL_HARM := 0.02   # in a duel, where every fight counts, harm weighs more
const DUEL_FALL := -1.0   # and falling weighs the same as felling the other: a duel is won or lost

signal bout_began  # a new life has begun (training/training_arena.gd sets the next duel up)

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
var duel := false         # set by the world: this learner fights one opponent over and over (training/tactics_env.gd)
var duel_harm := DUEL_HARM  # what each point of strength taken or lost is worth in a duel (HandAgent raises it: see there)
var opponent: Wizard      # in a duel, the one it fights: only that one's falls and wounds count (training/training_arena.gd)
var outlived := 0
var points_won := 0       # bouts that ran their time with nobody fallen, decided by who lost less of their strength (training/training_arena.gd)
var points_lost := 0
var draws := 0            # bouts that ran their time and were even
var hits := 0             # times it saw the opponent lose strength (a blow that landed)
var _casts_before := 0    # spells cast by the bodies it had before this one (the arena gives it a fresh one each bout)
var cause := {"outlive": 0.0, "fall": 0.0, "pages": 0.0, "harm": 0.0}


## A new body for the learner (the training arena stands up fresh wizards for every bout), and a new opponent: what it knew of the old ones goes.
func move_to(body: Wizard, rival: Wizard) -> void:
	if wizard != null and is_instance_valid(wizard):
		_casts_before += wizard.casts_made
	reparent(body, false)
	init_for(body)
	opponent = rival
	_rival_max.clear()
	_down.clear()


func init_for(body: Wizard) -> void:
	wizard = body
	brain = body.brain as TacticsBrain
	start = body.global_position
	_last_pages = body.ledger.count()
	_last_max = body.max_stamina
	reset_after = 3000  # decisions: about ten minutes of play at five a second


func get_obs_space() -> Dictionary:
	return {"obs": {"size": [TacticsBrain.SIZE], "space": "box"}}


## What it senses, packed: only the places that are not zero, and their values (training/gd_launch.py unpacks them into the whole list). Most of a
## screen of tiles is empty, so this is a few times shorter to write, send and read; nothing is lost, for a place not named is zero.
func get_obs() -> Dictionary:
	var seen := PackedFloat32Array()
	if brain != null and wizard != null and is_instance_valid(wizard) and wizard.is_inside_tree():
		seen = brain.observe()
	if seen.size() != TacticsBrain.SIZE:
		seen.resize(TacticsBrain.SIZE)
	var places := PackedInt32Array()
	var values := PackedFloat32Array()
	for i in seen.size():
		var value := seen[i]
		if value != 0.0 and not is_nan(value) and not is_inf(value):  # (a number that is not a number would turn the whole message to nothing)
			places.append(i)
			values.append(value)
	return {"obs": {"n": seen.size(), "i": places, "v": values}}


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
		if other == wizard or other.is_in_group("player") or (opponent != null and other != opponent):
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
			_add("harm", (before - other.max_stamina) * (duel_harm if duel else HARM))
			hits += 1
		_rival_max[id] = other.max_stamina
	var pages := wizard.ledger.count()
	if pages > _last_pages:
		_add("pages", PAGE * float(pages - _last_pages))
	_last_pages = pages
	if wizard.max_stamina < _last_max:
		_add("harm", -(_last_max - wizard.max_stamina) * (duel_harm if duel else HARM))
	_last_max = wizard.max_stamina
	if wizard.dead and not done:
		_add("fall", DUEL_FALL if duel else FALL)
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
	return {"deaths": deaths, "outlived": outlived, "points_won": points_won, "points_lost": points_lost, "draws": draws, "hits": hits, "casts": _casts_before + (wizard.casts_made if wizard != null and is_instance_valid(wizard) else 0), "pages": wizard.ledger.count() if wizard != null and is_instance_valid(wizard) else 0}


## The duel is over, the other having fallen: this life ends with it, so that the next begins with both standing (training/training_arena.gd).
func end_bout(points := 0, ran_out := false) -> void:
	_gather()  # (the other's fall is counted first)
	if points > 0:
		points_won += 1
	elif points < 0:
		points_lost += 1
	elif ran_out:
		draws += 1
	done = true
	_fallen = true


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
	bout_began.emit()

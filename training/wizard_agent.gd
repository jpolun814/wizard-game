class_name WizardAgent
extends AIController2D

## What a learning wizard senses, asks for and is rewarded for, for Godot RL Agents (addons/godot_rl_agents). It is the link between a wizard
## with a LearnedBrain and the trainer in Python. A decision is made every Sync.action_repeat physics frames.
##
## Senses (all scaled to about -1..1): its own speed, stamina and whether it stands; the next few tiles of the way it is going (where the scripted
## route would have it go: the policy has to find out how to get there); the ground about it (solid, a platform, or lethal) in a box of tiles round the feet; the nearest rival.
## Asks: left, stand or right; and a jump or not.
## Rewarded for: getting along its way, reading pages, and keeping its stamina; punished for being hurt and for jumping (it costs stamina), and for dying.

const GRID_W := 15  # tiles each side of the feet, so GRID_W across
const GRID_UP := 7  # tiles above the feet that it looks at
const GRID_DOWN := 3
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


func init_for(body: Wizard) -> void:
	wizard = body
	brain = body.brain as LearnedBrain
	start = body.global_position
	_last_pages = body.ledger.count()
	_last_max = body.max_stamina
	reset_after = 3000  # decisions: about five minutes of play


func get_obs_space() -> Dictionary:
	return {"obs": {"size": [get_obs()["obs"].size()], "space": "box"}}


func get_obs() -> Dictionary:
	var obs: Array = []
	if wizard == null or not is_instance_valid(wizard) or brain == null:
		obs.resize(_obs_size())
		obs.fill(0.0)
		return {"obs": obs}
	obs.append(wizard.velocity.x / 300.0)
	obs.append(clampf(wizard.velocity.y / 600.0, -2.0, 2.0))
	obs.append(1.0 if wizard.is_on_floor() else 0.0)
	obs.append(wizard.stamina / 200.0)
	obs.append(wizard.max_stamina / 200.0)
	obs.append(wizard.facing)
	obs.append(1.0 if wizard.air_jump_ready else 0.0)
	var here := Vector2i(floori(wizard.global_position.x / WizardRoute.TILE), floori((wizard.global_position.y - 1.0) / WizardRoute.TILE))
	for i in WAYPOINTS:
		var tile := brain._route.ahead(i)
		if tile == WorldNav.NONE:
			obs.append_array([0.0, 0.0, 0.0])
		else:
			obs.append_array([clampf(float(tile.x - here.x) / 12.0, -2.0, 2.0), clampf(float(tile.y - here.y) / 12.0, -2.0, 2.0), 1.0])
	obs.append(clampf(float(brain._route.remaining()) / 100.0, 0.0, 2.0))
	var space := wizard.get_world_2d().direct_space_state
	for dy in range(-GRID_UP, GRID_DOWN + 1):
		for dx in range(-GRID_W / 2, GRID_W / 2 + 1):
			var point := Vector2((here.x + dx + 0.5) * WizardRoute.TILE, (here.y + dy + 0.5) * WizardRoute.TILE)
			var query := PhysicsPointQueryParameters2D.new()
			query.position = point
			query.collision_mask = 1 | 16
			var solid := 0.0
			for hit in space.intersect_point(query, 2):
				solid = maxf(solid, 0.5 if (hit["collider"] is CollisionObject2D and hit["collider"].collision_layer & 16 != 0 and hit["collider"].collision_layer & 1 == 0) else 1.0)
			obs.append(solid)
			obs.append(1.0 if brain._lethal_at(point) else 0.0)
	var rival := _nearest_rival()
	if rival == null:
		obs.append_array([0.0, 0.0, 0.0])
	else:
		var off := rival.center() - wizard.center()
		obs.append_array([clampf(off.x / SEE_RIVAL, -1.0, 1.0), clampf(off.y / SEE_RIVAL, -1.0, 1.0), 1.0])
	return {"obs": obs}


func _obs_size() -> int:
	return 7 + WAYPOINTS * 3 + 1 + (GRID_UP + GRID_DOWN + 1) * (GRID_W / 2 * 2 + 1) * 2 + 3


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
	if brain == null:
		return
	brain.move = float(int(action["move"]) - 1)
	if int(action["jump"]) == 1 and wizard.is_on_floor():
		brain.jump = true
		_spent -= 0.05  # a jump costs stamina: it should be worth it
	brain.learned = true


func get_reward() -> float:
	_gather()
	var out := _spent
	_spent = 0.0
	return out


## Adds up what has happened since the last look.
func _gather() -> void:
	if wizard == null or not is_instance_valid(wizard):
		return
	var goal := brain._route.goal()
	var remaining := brain._route.remaining()
	if goal == _last_goal and _last_remaining >= 0:
		_spent += clampf(float(_last_remaining - remaining), -3.0, 3.0) * 0.1  # nearer to where it is going
	_last_goal = goal
	_last_remaining = remaining
	var pages := wizard.ledger.count()
	if pages > _last_pages:
		_spent += 5.0 * float(pages - _last_pages)
	_last_pages = pages
	if wizard.max_stamina < _last_max:
		_spent -= (_last_max - wizard.max_stamina) * 0.02  # hurt
	_last_max = wizard.max_stamina
	if wizard.dead and not done:
		_spent -= 5.0
		done = true
		deaths += 1


func get_info() -> Dictionary:
	return {"deaths": deaths}


## A new life: it stands where it began, whole, with its way chosen again.
func reset() -> void:
	super.reset()
	done = false
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

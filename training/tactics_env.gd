extends Node

## The place wizards learn tactics in: a match world with its seven AI wizards. Some learn (TacticsBrain with a TacticsAgent that Godot RL Agents
## drives); the rest are their opponents: the scripted brain, or an earlier version of the learner (an exported network), so that it learns to
## beat both and not only itself. Whoever falls stands up again where they began a few seconds later, so the world stays full.
##
## Start it with training/train_tactics.py. Arguments after the scene: --world_seed=N, --learners=K (how many of the seven learn, default 4),
## --opponent=PATH (an exported earlier network that plays half the opponents; without it they are all scripted), --duel=1 (each learner is given
## one opponent of its own, set down a short way from it, so that they fight all the time; the wizards left over stand aside).

const ACTION_REPEAT := 12  # physics frames to a decision: five a second (TacticsBrain.DECISION_EVERY)
const STAND_UP := 4.0      # seconds a fallen opponent lies before it stands up again
const DUEL_GAP := 260.0    # how far apart a learner and its opponent are set down in a duel
const DUEL_STAND_UP := 1.0

var _world: Node
var _starts := {}          # opponent -> where it began
var _down_for := {}        # opponent -> seconds it has lain fallen
var _duel := false


func _ready() -> void:
	var seed_value := 7
	var learners := 4
	var opponent := ""
	var duel := false
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--world_seed="):
			seed_value = int(arg.get_slice("=", 1))
		elif arg.begins_with("--learners="):
			learners = int(arg.get_slice("=", 1))
		elif arg.begins_with("--opponent="):
			opponent = arg.get_slice("=", 1)
		elif arg.begins_with("--duel="):
			duel = arg.get_slice("=", 1) == "1"
	seed(seed_value)
	World.next_seed = seed_value
	_world = load("res://scenes/world.tscn").instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_world.player.dead = true  # the seat of a person is empty here
	_world.player.hide()
	var old: PolicyNet = TacticsBrain.net(opponent) if opponent != "" else null
	var found := 0
	var others := 0
	var learning: Array[Wizard] = []
	if duel:
		learners = mini(learners, 3)  # seven seats: three pairs, and one left over
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if wizard == _world.player or wizard.brain == null:
			continue
		wizard.keep_when_dead = true
		if duel and found >= learners and others >= learners:
			wizard.set_physics_process(false)  # the one left over stands aside
			wizard.global_position = Vector2(-9000.0, -9000.0)
			continue
		if duel and found >= learners:
			var partner: Wizard = learning[others]
			wizard.global_position = partner.global_position + Vector2(DUEL_GAP if others % 2 == 0 else -DUEL_GAP, -40.0)
			wizard.velocity = Vector2.ZERO
		if found < learners:
			wizard.brain = TacticsBrain.new(wizard)
			var agent := TacticsAgent.new()
			wizard.add_child(agent)
			agent.init_for(wizard)
			if duel:
				agent.duel = true
			learning.append(wizard)
			found += 1
		else:
			if old != null and others % 2 == 0:
				var rival := TacticsBrain.new(wizard)
				rival.policy = old
				wizard.brain = rival
			_starts[wizard] = wizard.global_position
			others += 1
	_duel = duel
	var sync := Sync.new()
	sync.control_mode = Sync.ControlModes.TRAINING
	sync.action_repeat = ACTION_REPEAT
	add_child(sync)
	ready.emit()  # (Sync starts when its parent is ready, and this one has been for some time, with the world and its agents made since)
	print("tactics world seed %d%s: %d learning, %d opponents%s" % [seed_value, " (duels)" if duel else "", found, others, (" (half " + opponent + ")") if old != null else ""])


func _physics_process(delta: float) -> void:
	for wizard: Wizard in _starts.keys():
		if not is_instance_valid(wizard):
			_starts.erase(wizard)
			continue
		if not wizard.dead:
			_down_for.erase(wizard)
			continue
		_down_for[wizard] = _down_for.get(wizard, 0.0) + delta
		if _down_for[wizard] >= (DUEL_STAND_UP if _duel else STAND_UP):
			wizard.revive()
			wizard.global_position = _starts[wizard]
			wizard.velocity = Vector2.ZERO
			_down_for.erase(wizard)

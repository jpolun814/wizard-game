extends Node

## The place wizards learn tactics in: a match world with its seven AI wizards. Some learn (TacticsBrain with a TacticsAgent that Godot RL Agents
## drives); the rest are their opponents: the scripted brain, or an earlier version of the learner (an exported network), so that it learns to
## beat both and not only itself. Whoever falls stands up again where they began a few seconds later, so the world stays full.
##
## Start it with training/train_tactics.py. Arguments after the scene: --world_seed=N, --learners=K (how many of the seven learn, default 4),
## --opponent=PATH (an exported earlier network that plays half the opponents; without it they are all scripted).

const ACTION_REPEAT := 12  # physics frames to a decision: five a second (TacticsBrain.DECISION_EVERY)
const STAND_UP := 4.0      # seconds a fallen opponent lies before it stands up again

var _world: Node
var _starts := {}          # opponent -> where it began
var _down_for := {}        # opponent -> seconds it has lain fallen


func _ready() -> void:
	var seed_value := 7
	var learners := 4
	var opponent := ""
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--world_seed="):
			seed_value = int(arg.get_slice("=", 1))
		elif arg.begins_with("--learners="):
			learners = int(arg.get_slice("=", 1))
		elif arg.begins_with("--opponent="):
			opponent = arg.get_slice("=", 1)
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
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if wizard == _world.player or wizard.brain == null:
			continue
		wizard.keep_when_dead = true
		if found < learners:
			wizard.brain = TacticsBrain.new(wizard)
			var agent := TacticsAgent.new()
			wizard.add_child(agent)
			agent.init_for(wizard)
			found += 1
		else:
			if old != null and others % 2 == 0:
				var rival := TacticsBrain.new(wizard)
				rival.policy = old
				wizard.brain = rival
			_starts[wizard] = wizard.global_position
			others += 1
	var sync := Sync.new()
	sync.control_mode = Sync.ControlModes.TRAINING
	sync.action_repeat = ACTION_REPEAT
	add_child(sync)
	ready.emit()  # (Sync starts when its parent is ready, and this one has been for some time, with the world and its agents made since)
	print("tactics world seed %d: %d learning, %d opponents%s" % [seed_value, found, others, (" (half " + opponent + ")") if old != null else ""])


func _physics_process(delta: float) -> void:
	for wizard: Wizard in _starts.keys():
		if not is_instance_valid(wizard):
			_starts.erase(wizard)
			continue
		if not wizard.dead:
			_down_for.erase(wizard)
			continue
		_down_for[wizard] = _down_for.get(wizard, 0.0) + delta
		if _down_for[wizard] >= STAND_UP:
			wizard.revive()
			wizard.global_position = _starts[wizard]
			wizard.velocity = Vector2.ZERO
			_down_for.erase(wizard)

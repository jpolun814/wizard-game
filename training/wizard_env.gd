extends Node

## The place wizards learn in: a world with its seven AI wizards, each with learned footwork (LearnedBrain) and an agent (WizardAgent) that
## Godot RL Agents reads and drives. Start it with `training/train_sb3.py`, which starts the game and connects to it. Arguments after the scene: `--world_seed=N`.

const ACTION_REPEAT := 6  # physics frames to a decision: ten a second

var _world: Node


func _ready() -> void:
	var seed_value := 7
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--world_seed="):
			seed_value = int(arg.get_slice("=", 1))
		elif arg.begins_with("--stage="):
			MatchState.stage = int(arg.get_slice("=", 1))
	seed(seed_value)
	World.next_seed = seed_value
	_world = load("res://scenes/world.tscn").instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_world.player.dead = true  # the seat of a person is empty here
	_world.player.hide()
	var found := 0
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if wizard == _world.player or wizard.brain == null:
			continue
		wizard.brain = LearnedBrain.new(wizard)
		var agent := WizardAgent.new()
		wizard.add_child(agent)
		agent.init_for(wizard)
		found += 1
	var sync := Sync.new()
	sync.control_mode = Sync.ControlModes.TRAINING
	sync.action_repeat = ACTION_REPEAT
	add_child(sync)
	ready.emit()  # (Sync starts when its parent is ready, and this one has been for some time, with the world and its agents made since)
	print("training world seed %d: %d learning wizards" % [seed_value, found])

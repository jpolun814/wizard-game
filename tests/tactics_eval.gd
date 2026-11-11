extends Node

## Plays one whole match of AI wizards (the person's seat empty), some seats with learned tactics (TacticsBrain with an exported network) and the rest
## with the scripted brain, at the real times through every collapse, and prints who won and which side they were on:
##
##     godot --headless --fixed-fps 60 --path . tests/tactics_eval.tscn -- seed=3 policy=res://ai/tactics.json seats=1,3,5,7
## seats= names the AI seats (1 to 7) that play the learned tactics; policy=scripted makes them scripted too (to measure the seats themselves).
## The line it ends with: RESULT seed=N seats=... winner=SEAT side=trained|scripted|none seconds=S. training/eval_tactics.py runs many and sums them.

const LIMIT := 1500.0  # seconds of play after which the match is given up on (no winner)

var _seed := 3
var _policy_path := "res://ai/tactics.json"
var _seats := [1, 3, 5, 7]
var _clock := 0.0
var _world: World
var _net: PolicyNet
var _done := false


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("seed="):
			_seed = int(argument.trim_prefix("seed="))
		elif argument.begins_with("policy="):
			_policy_path = argument.trim_prefix("policy=")
		elif argument.begins_with("seats="):
			_seats = Array(argument.trim_prefix("seats=").split(",")).map(func(s: String) -> int: return int(s))
	if _policy_path != "scripted":
		_net = PolicyNet.load_file(_policy_path)
		if _net == null:
			print("RESULT error=no_policy path=%s" % _policy_path)
			get_tree().quit(2)
			return
	seed(_seed)
	MatchState.hurry = 1.0
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = _seed
	call_deferred("_start")


func _start() -> void:
	reparent(get_tree().root)  # this node outlives the scenes that come and go
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _process(delta: float) -> void:
	if _done:
		return
	_clock += delta
	var scene := get_tree().current_scene
	if scene is World and scene != _world and scene.player != null and scene.ledgers.size() > 0 and scene.nav != null:
		_arrived(scene)
	if _world == null or not is_instance_valid(_world) or _world._leaving:
		return
	var standing := _standing()
	if standing.size() <= 1 or _clock > LIMIT:
		_finish(standing)


func _arrived(world: World) -> void:
	_world = world
	world.player.dead = true
	world._on_player_died()
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if wizard == world.player or wizard.brain == null:
			continue
		if _net != null and _seat(wizard) in _seats:
			var brain := TacticsBrain.new(wizard)
			brain.policy = _net
			wizard.brain = brain


func _seat(wizard: Wizard) -> int:
	return int(String(wizard.name).trim_prefix("Rival"))


func _standing() -> Array[Wizard]:
	var out: Array[Wizard] = []
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if wizard != _world.player and is_instance_valid(wizard) and not wizard.dead:
			out.append(wizard)
	return out


func _finish(standing: Array[Wizard]) -> void:
	_done = true
	var winner := -1
	var side := "none"
	if standing.size() == 1:
		winner = _seat(standing[0])
		side = "trained" if winner in _seats and _net != null else "scripted"
	elif not standing.is_empty():  # time ran out: a side that alone still stands has won it
		var sides := {}
		for wizard in standing:
			sides["trained" if _seat(wizard) in _seats and _net != null else "scripted"] = true
		if sides.size() == 1:
			side = sides.keys()[0]
	print("RESULT seed=%d seats=%s winner=%d side=%s seconds=%.0f standing=%d" % [_seed, ",".join(_seats.map(func(s: int) -> String: return str(s))), winner, side, _clock, standing.size()])
	get_tree().quit(0)

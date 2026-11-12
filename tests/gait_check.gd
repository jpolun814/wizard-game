extends Node

## How the AI wizards move in a real match, as a person watching would judge it: whether one runs backwards (moving one way while facing the other),
## which the body must not allow any wizard, since a person's cannot, and how often they jump (reported, not judged: a person may jump a lot). Plays the first world of a match with every AI seat on the scripted brain, or on learned tactics (policy=PATH), and counts
## frames on the ground at running speed whose facing disagrees with the motion, and take-offs per minute.
##
##     godot --headless --fixed-fps 60 --path . tests/gait_check.tscn -- seed=3 [policy=res://ai/tactics.json] [seconds=240]
##
## A person's wizard never runs backwards (Wizard._animate turns every wizard the way it moves). Fails when any running frame is backwards.
## For comparison, a recorded person jumps 9 to 16 times a minute.

const RUNNING := 60.0     # px/s along the ground that counts as running

var _seed := 3
var _seconds := 240.0
var _policy_path := ""
var _net: PolicyNet
var _world: World
var _clock := 0.0
var _running := 0
var _backwards := 0
var _why := {}
var _jumps := 0
var _jump_why := {}
var _wizard_seconds := 0.0
var _was_on_floor := {}
var _done := false


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("seed="):
			_seed = int(argument.trim_prefix("seed="))
		elif argument.begins_with("policy="):
			_policy_path = argument.trim_prefix("policy=")
		elif argument.begins_with("seconds="):
			_seconds = float(argument.trim_prefix("seconds="))
	if _policy_path != "":
		_net = PolicyNet.load_file(_policy_path)
	seed(_seed)
	MatchState.hurry = 1.0
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = _seed
	call_deferred("_start")


func _start() -> void:
	reparent(get_tree().root)
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _physics_process(delta: float) -> void:
	if _done:
		return
	var scene := get_tree().current_scene
	if _world == null and scene is World and scene.player != null and scene.ledgers.size() > 0 and scene.nav != null:
		_world = scene
		_world.player.dead = true
		_world._on_player_died()
		if _net != null:
			for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
				if wizard != _world.player and wizard.brain != null:
					var brain := TacticsBrain.new(wizard)
					brain.policy = _net
					wizard.brain = brain
	if _world == null or not is_instance_valid(_world):
		return
	_clock += delta
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if wizard == _world.player or wizard.dead or wizard.brain == null:
			continue
		_wizard_seconds += delta
		var on_floor := wizard.is_on_floor()
		if _was_on_floor.get(wizard, true) and not on_floor and wizard.velocity.y < -200.0:
			_jumps += 1
			var brain: WizardBrain = wizard.brain
			var near: bool = brain._foe != null and is_instance_valid(brain._foe) and brain._foe.global_position.distance_to(wizard.global_position) < 900.0
			var kind := ("fight" if near else "travel") + ("+wall" if wizard.is_on_wall() else "")
			_jump_why[kind] = _jump_why.get(kind, 0) + 1
		_was_on_floor[wizard] = on_floor
		if on_floor and absf(wizard.velocity.x) > RUNNING:
			_running += 1
			if signf(wizard.velocity.x) != wizard.facing:
				_backwards += 1
				var why := _reason(wizard)
				_why[why] = _why.get(why, 0) + 1
	if _clock >= _seconds or _world._leaving:
		_finish()


## What the wizard was doing while it ran backwards, for finding the cause.
func _reason(wizard: Wizard) -> String:
	var brain: WizardBrain = wizard.brain
	var parts: Array[String] = []
	if wizard.is_drawing():
		parts.append("drawing")
	if wizard.casting:
		parts.append("casting")
	if brain.is_typing():
		parts.append("typing")
	if not brain._lift.is_empty():
		parts.append("lift")
	if brain._escape_time > 0.0:
		parts.append("escape")
	if brain._react > 0.0:
		parts.append("react")
	if wizard.wind != 0.0:
		parts.append("wind")
	if parts.is_empty():
		parts.append("none")
	return "+".join(parts)


func _finish() -> void:
	_done = true
	var share := float(_backwards) / maxf(_running, 1.0)
	var per_minute := _jumps / maxf(_wizard_seconds / 60.0, 0.001)
	print("  %.0f s of play, %.0f wizard-minutes" % [_clock, _wizard_seconds / 60.0])
	print("  running backwards: %d of %d running frames (%.1f%%)  %s" % [_backwards, _running, share * 100.0, str(_why)])
	print("  jumps: %d, %.1f a minute per wizard  %s" % [_jumps, per_minute, str(_jump_why)])
	var ok := _backwards == 0
	print("GAIT %s" % ("PASS" if ok else "FAILED"))
	get_tree().quit(0 if ok else 1)

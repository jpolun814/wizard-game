class_name DuelArena
extends TrainingArena

## The curriculum's arena (training/train_duel.py): the training arena's walled lanes, one duel to a lane, but both wizards are played through a
## person's controls (HandBrain) and the scripted brain plays nobody. The learner (a HandAgent the trainer drives) fights an earlier version of itself:
## the latest most of the time and an older one now and then (OpenAI Five's 80 to 20), so it keeps beating what it was and does not go round in
## circles. Both have only the stage's spells. For a measure the opponent can instead be a yardstick: one that stands and does nothing ("dummy"), or
## one that stands and casts the stage's first spell at the learner over and over ("turret").
##
## Arguments after the scene (besides the training arena's --lanes): --stage=N (STAGES), --pool=DIR (the folder of round_N.json networks to draw
## opponents from), --opponent=pool|dummy|turret|PATH (default pool), --learner=PATH|latest (a network plays the learner's side too, with no trainer:
## to watch one, with --watch, which keeps the camera on the first lane's learner; "latest" takes the newest of the pool at every bout, so a window
## left open shows the network as it improves), --opponent_stage=N (the opponent has only that stage's spells: a measure against an earlier
## stage's champion).

## The spells of each stage of the curriculum: each stage adds to the last.
const STAGES := {1: ["Ignite"], 2: ["Frostbolt", "Barrier", "Stone Wall"]}
const EARLIER_SHARE := 0.25  # of the training bouts past stage 1, the share fought with an earlier stage's book (both alike), so what was learned
                            # with fewer spells is kept
const LATEST_SHARE := 0.8  # of the bouts against the pool, the share against the latest version

var _stage := 1
var _pool_dir := ""
var _opponent_kind := "pool"
var _learner_path := ""
var _follow_curriculum := false
var _dummy_share := 0.0  # of the bouts against the pool, the share against a dummy that stands still instead (--dummy_share): a still target first
var _watch := false
var _opponent_stage := 0  # (--opponent_stage=N) the opponent's book is that stage's, the learner's the whole of this one: does what it learned
                          # since beat a network of that stage, playing with what it was trained on? 0: both have the bout's book
var _bout_stage := 1      # the stage whose book this bout is fought with
static var _nets := {}  # path -> PolicyNet, loaded once


func _begin_encounter(camera: Camera2D) -> void:
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			_stage = int(arg.get_slice("=", 1))
		elif arg.begins_with("--pool="):
			_pool_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--opponent="):
			_opponent_kind = arg.get_slice("=", 1)
		elif arg == "--dummy_share=follow":
			_follow_curriculum = true  # (a window to watch: the same share as training has now, read from the pool's curriculum.json at every bout)
		elif arg.begins_with("--dummy_share="):
			_dummy_share = clampf(float(arg.get_slice("=", 1)), 0.0, 1.0)
		elif arg.begins_with("--learner="):
			_learner_path = arg.get_slice("=", 1)
		elif arg.begins_with("--opponent_stage="):
			_opponent_stage = int(arg.get_slice("=", 1))
		elif arg == "--watch":
			_watch = true
	add_child(Grade.new())
	camera.reset_smoothing()
	player.dead = true  # the seat of a person is empty here
	player.hide()
	player.set_physics_process(false)
	player.global_position = Vector2(ArenaGen.column_x(ArenaGen.FIRST_COL + 2), ArenaGen.GROUND_Y - 4.0)
	_rng_bouts.randomize()
	for lane in lanes:
		var nav := WorldNav.new()
		var learner := _new_wizard(nav, true, null)
		var opponent := _new_wizard(nav, false, null)
		var agent := HandAgent.new()
		learner.add_child(agent)
		agent.init_for(learner)
		agent.duel = true
		agent.opponent = opponent
		var pair := {"learner": learner, "opponent": opponent, "agent": agent, "lane": lane, "nav": nav, "down": 0.0, "age": 0.0, "bouts": 0,
			"rival_net": null, "began": [1.0, 1.0]}
		_aim_turret(opponent, learner)
		agent.bout_began.connect(_next_bout.bind(pair))
		_pairs.append(pair)
		_read_lane(pair)
		_next_bout(pair)
	var sync := Sync.new()
	sync.control_mode = Sync.ControlModes.TRAINING
	sync.action_repeat = ACTION_REPEAT
	add_child(sync)
	print("duel arena: stage %d %s, %d lanes, opponents %s" % [_stage, str(_spells()), lanes, _opponent_kind])


## A hand-played wizard: the learner (no network: the trainer chooses), or its opponent (a network from the pool, or a yardstick).
func _new_wizard(nav: WorldNav, learns: bool, _net: PolicyNet) -> Wizard:
	var wizard := _add_wizard("dark_wizard", Vector2(ArenaGen.column_x(ArenaGen.FIRST_COL + 2), ArenaGen.GROUND_Y))
	wizard.keep_when_dead = true
	wizard.nav = nav
	var brain := HandBrain.new(wizard)
	wizard.brain = brain
	if not learns:
		brain.policy = _pick_opponent()
	elif _learner_path == "latest":
		var newest := _newest_round()
		brain.policy = _net_at(_pool_dir.path_join("round_%d.json" % newest)) if newest >= 0 else null
		if _watch and newest >= 0:
			print("watching round %d" % newest)
	elif _learner_path != "":
		brain.policy = _net_at(_learner_path)
	return wizard


## With a network on the learner's side there is no trainer to read the end of a bout and say so (Sync clears "done" when the trainer has read it):
## the arena does it, or the next bout would wait for the agent's long reset (a window to watch sat still for up to 50 s after a fall).
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _learner_path == "":
		return
	for pair: Dictionary in _pairs:
		var agent: TacticsAgent = pair["agent"]
		if agent.done:
			agent.set_done_false()


func _process(delta: float) -> void:
	super._process(delta)
	if _watch and not _pairs.is_empty() and is_instance_valid(_pairs[0]["learner"]):
		player.global_position = (_pairs[0]["learner"] as Wizard).global_position  # (the camera rides on the empty seat of a person)


## The bout's book, for both.
func _a_book() -> Ledger:
	return Ledger.of(_spells(_bout_stage))


## The spells of a stage and the stages before it (this one's, if none is given).
func _spells(upto := 0) -> Array:
	var last := upto if upto > 0 else _stage
	var out: Array = []
	for stage: int in STAGES:
		if stage <= last:
			out.append_array(STAGES[stage])
	return out


## Fresh wizards for the next bout (TrainingArena), and a turret told whom to cast at.
func _set_bout(pair: Dictionary) -> void:
	_bout_stage = _stage
	if _stage > 1 and _opponent_kind == "pool" and _rng_bouts.randf() < EARLIER_SHARE:
		_bout_stage = _rng_bouts.randi_range(1, _stage - 1)
	super._set_bout(pair)
	if _opponent_stage > 0:
		(pair["opponent"] as Wizard).ledger = Ledger.of(_spells(_opponent_stage))
	_aim_turret(pair["opponent"], pair["learner"])


func _aim_turret(opponent: Wizard, learner: Wizard) -> void:
	var brain := opponent.brain as HandBrain
	if brain != null and _opponent_kind == "turret":
		brain.turret = learner


## The network an opponent plays with this bout: the latest of the pool most of the time, an older one now and then; or none (a yardstick).
func _pick_opponent() -> PolicyNet:
	if _opponent_kind == "dummy" or _opponent_kind == "turret":
		return null
	if _opponent_kind != "pool":
		return _net_at(_opponent_kind)
	if _follow_curriculum:
		var file := FileAccess.open(_pool_dir.path_join("curriculum.json"), FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text()) if file != null else null
		_dummy_share = float(data.get("dummy_share", 0.5)) if data is Dictionary else 0.5
	if _rng_bouts.randf() < _dummy_share:
		if _watch:
			print("a dummy this bout")
		return null  # a dummy: it stands, and learning to hit what stands comes before hitting what moves
	var rounds := _rounds()
	if rounds.is_empty():
		return null
	var pick: int = rounds[-1] if _rng_bouts.randf() < LATEST_SHARE else rounds[_rng_bouts.randi() % rounds.size()]
	return _net_at(_pool_dir.path_join("round_%d.json" % pick))


## The rounds saved in the pool, oldest first.
func _rounds() -> Array:
	var rounds: Array = []
	for file in DirAccess.get_files_at(_pool_dir):
		if file.begins_with("round_") and file.ends_with(".json"):
			rounds.append(int(file.trim_prefix("round_").trim_suffix(".json")))
	rounds.sort()
	return rounds


func _newest_round() -> int:
	var rounds := _rounds()
	return rounds[-1] if not rounds.is_empty() else -1


static func _net_at(path: String) -> PolicyNet:
	if not _nets.has(path):
		var net := PolicyNet.load_file(path)
		_nets[path] = net if HandBrain.fits(net) else null  # (one of another layout would play nonsense: a dummy stands in)
	return _nets[path]

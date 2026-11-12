class_name TrainingArena
extends Lab

## A bare place to learn tactics in, fast: flat ground cut into lanes by tall walls, one duel to a lane. In each lane a learner (TacticsBrain with a
## TacticsAgent that Godot RL Agents drives) fights one opponent (the scripted brain, or an earlier network) over and over: when either falls, both
## stand up again, a new gap apart, with new books, and the next bout begins. A fight every few seconds, instead of every few minutes in a match world.
## Nothing else is here: no water, no creatures, no weather; the room's own things (the book, the pond, the dummies) are left out.
##
## Each lane is walled at both ends, and the lanes lie far enough apart that nobody sees from one into the next.
##
## Started by training/train_tactics.py (--arena). Arguments after the scene: --lanes=N (default 3), --opponent=PATH (an earlier network that plays
## half the opponents), --scripted_share=F (the share of opponents that are scripted when there is an earlier network, default 0.5).

const LANE_COLS := 60        # tiles of fighting ground in a lane
const BUFFER_COLS := 16      # tiles of empty ground outside each lane's walls: two of these lie between lanes, more than a screen's width
const WALL_ROWS := 120       # how high the walls between lanes (and at the ends) stand: higher than any rocket, updraft or jump carries anyone
const ACTION_REPEAT := 12    # physics frames to a decision: five a second (TacticsBrain.DECISION_EVERY)
const GAP_LEAST := 200.0     # how far apart a bout begins
const GAP_MOST := 380.0     # (at most: both start on the screen, whose half is about 427 px wide (Eyes.HALF); at 560 a third of bouts began with the other out of sight, and the learner, which sees only the screen, often walked away and never found it: a search that belongs to the worlds, not to stage 1, 2026-11-12)
const STAND_UP := 0.5        # seconds a fallen opponent lies before the next bout
const ATTACKS_LEAST := 3     # attacking spells in a book, at the least and the most
const ATTACKS_MOST := 9
const OTHERS_MOST := 4       # and other spells (a shield, a wall, a step...)
const NAV_EVERY := 5.0       # seconds between new readings of a lane's ways (a Stone Wall cast changes them)
const BOUT_LIMIT := 45.0     # seconds a bout lasts at the most: then it is called off, and the next begins (a draw, no reward either way)
const WOUNDED_LEAST := 40.0  # a bout begins with each wizard's most stamina drawn from here to whole: a match has its wounded, and a short bout teaches as much

## The groups that what a bout leaves behind is in: every spell (a thicket, a wall, rising air, a skeleton raised, a vine...) and every creature. All of
## it in a lane goes when a bout ends there, so that nothing of one bout decides the next (a skeleton left standing killed the wizard who stood up
## beside it, bout after bout: one lane went 0 to 24 while the others were even, and the measure of the network swung from 0.31 to 0.79).
const LEFTOVERS := ["danger", "lasting", "fires", "shots", "clouds", "breakables", "projectiles", "lights", "smoke_plumes", "sight_blockers", "pages",
	"climbables", "walls", "vacuums", "updrafts", "slick", "silences", "rocks", "oaks", "moonbeams", "mobs", "lily_pads", "leeches", "hunts", "hexes",
	"glowcaps", "flares", "earthquakes", "darkness", "eclipses", "decoys", "flora", "dowsings", "eye_marks", "drifts", "ground_watchers"]

static var lanes := 3

var _pairs: Array = []       # {"learner", "opponent", "agent", "lane", "nav", "down": seconds the opponent has lain fallen, "age": seconds the bout has lasted, "bouts": how many have begun}
var _rng_bouts := RandomNumberGenerator.new()
var _nav_wait := 0.0


func _init() -> void:
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--lanes="):
			lanes = maxi(int(arg.get_slice("=", 1)), 1)
	heals_wounds = false
	ArenaGen.chunk_count = ceili(float(_cols()) / ArenaGen.CHUNK_WIDTH)
	ArenaGen.right_wall = ArenaGen.FIRST_COL + ArenaGen.CHUNK_WIDTH * ArenaGen.chunk_count


func _exit_tree() -> void:
	ArenaGen.chunk_count = ArenaGen.CHUNK_COUNT  # the other rooms are their usual width
	ArenaGen.right_wall = ArenaGen.FIRST_COL + ArenaGen.CHUNK_WIDTH * ArenaGen.CHUNK_COUNT
	super()


static func _cols() -> int:
	return lanes * (LANE_COLS + BUFFER_COLS * 2 + 1)


## Flat ground from wall to wall, and a tall wall between each lane and the next.
func _build_map() -> Variant:
	var heights := PackedFloat32Array()
	heights.resize(ArenaGen.right_wall - ArenaGen.FIRST_COL)
	var cells: Dictionary = ArenaGen.build(_rng, heights)
	for key: Vector2i in cells.keys():
		if key.y < ArenaGen.GROUND_ROW and key.x > ArenaGen.LEFT_WALL and key.x < ArenaGen.right_wall:
			cells.erase(key)  # (the room's pieces of platform and stone: none here)
	var walls: Array = [ArenaGen.LEFT_WALL, ArenaGen.right_wall]
	for lane in lanes:
		walls.append(_lane_left(lane) - 1)  # each lane walled at both ends, with empty ground between one lane's wall and the next's
		walls.append(_lane_left(lane) + LANE_COLS)
	for col: int in walls:
		for row in range(ArenaGen.GROUND_ROW - WALL_ROWS, ArenaGen.GROUND_ROW):
			cells[Vector2i(col, row)] = ArenaGen.STONE
	return cells


## The first column of a lane's fighting ground.
func _lane_left(lane: int) -> int:
	return ArenaGen.FIRST_COL + lane * (LANE_COLS + BUFFER_COLS * 2 + 1) + BUFFER_COLS


func _begin_encounter(camera: Camera2D) -> void:
	add_child(Grade.new())
	camera.reset_smoothing()
	player.dead = true  # the seat of a person is empty here
	player.hide()
	player.set_physics_process(false)
	player.global_position = Vector2(ArenaGen.column_x(ArenaGen.FIRST_COL + 2), ArenaGen.GROUND_Y - 4.0)
	_rng_bouts.randomize()
	var opponent_path := ""
	var scripted_share := 0.5
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--opponent="):
			opponent_path = arg.get_slice("=", 1)
		elif arg.begins_with("--scripted_share="):
			scripted_share = float(arg.get_slice("=", 1))
	var old: PolicyNet = TacticsBrain.net(opponent_path) if opponent_path != "" else null
	for lane in lanes:
		var nav := WorldNav.new()
		var middle := _lane_left(lane) + LANE_COLS / 2
		var rival_net: PolicyNet = old if old != null and lane % 2 == 1 and _rng_bouts.randf() >= scripted_share else null
		var learner := _new_wizard(nav, true, null)
		var opponent := _new_wizard(nav, false, rival_net)
		var agent := TacticsAgent.new()
		learner.add_child(agent)
		agent.init_for(learner)
		agent.duel = true
		agent.opponent = opponent
		var pair := {"learner": learner, "opponent": opponent, "agent": agent, "lane": lane, "nav": nav, "down": 0.0, "age": 0.0, "bouts": 0, "rival_net": rival_net, "began": [1.0, 1.0]}
		agent.bout_began.connect(_next_bout.bind(pair))
		_pairs.append(pair)
		_read_lane(pair)
		_next_bout(pair)
	var sync := Sync.new()
	sync.control_mode = Sync.ControlModes.TRAINING
	sync.action_repeat = ACTION_REPEAT
	add_child(sync)
	print("training arena: %d lanes, opponents %s" % [lanes, ("scripted and " + opponent_path) if old != null else "scripted"])


func _place_lectern() -> void:
	pass  # (no book to touch: nobody leaves)


func _scene_name() -> String:
	return "training"


func _title() -> String:
	return ""


## A lane's ways, read again (a Stone Wall cast in it changes them).
func _read_lane(pair: Dictionary) -> void:
	var start := Vector2i(_lane_left(pair["lane"]) + LANE_COLS / 2, ArenaGen.GROUND_ROW - 1)
	RoomScan.read(get_tree(), _cells, start).build_nav(pair["nav"], start)


## A wizard for a lane: the learner (tactics the trainer drives) or its opponent (the scripted brain, or an earlier network).
func _new_wizard(nav: WorldNav, learns: bool, net: PolicyNet) -> Wizard:
	var wizard := _add_wizard("dark_wizard", Vector2(ArenaGen.column_x(ArenaGen.FIRST_COL + 2), ArenaGen.GROUND_Y))
	wizard.keep_when_dead = true
	wizard.nav = nav
	if learns or net != null:
		var brain := TacticsBrain.new(wizard)
		brain.policy = net
		wizard.brain = brain
	return wizard


## The next bout. After the first, it begins once this frame is over (it is asked for in the middle of the agent's own reset): see _fresh_bout.
func _next_bout(pair: Dictionary) -> void:
	if pair["bouts"] == 0:
		_set_bout(pair)
	else:
		pair["down"] = -1.0e9  # (no bout is judged over until it has begun)
		pair["age"] = -1.0e9
		_fresh_bout.call_deferred(pair)


## Everything the last bout left in the lane goes, a pit dug in it is filled, and two fresh wizards stand up in it: a wizard carries many things
## (frozen, cursed, a wolf, short of breath, shielded...), and a new one is the only sure way that none of them is carried into the next bout.
func _fresh_bout(pair: Dictionary) -> void:
	var left := (_lane_left(pair["lane"]) - BUFFER_COLS) * float(ArenaGen.TILE)
	var right := (_lane_left(pair["lane"]) + LANE_COLS + BUFFER_COLS) * float(ArenaGen.TILE)
	var old: Array[Wizard] = [pair["learner"], pair["opponent"]]
	var gone := {}
	for group: String in LEFTOVERS:
		for node in get_tree().get_nodes_in_group(group):
			if gone.has(node) or not node is Node2D or node is Wizard or not is_instance_valid(node):
				continue
			var x: float = (node as Node2D).global_position.x
			if x < left or x > right or old.any(func(w: Wizard) -> bool: return w.is_ancestor_of(node)):
				continue  # (another lane's; or on an old wizard, which goes with it)
			gone[node] = true
			node.queue_free()
	_ground.mend(left, right)
	var learner := _new_wizard(pair["nav"], true, null)
	var opponent := _new_wizard(pair["nav"], false, pair["rival_net"])
	var agent: TacticsAgent = pair["agent"]
	agent.move_to(learner, opponent)
	pair["learner"] = learner
	pair["opponent"] = opponent
	for wizard in old:
		wizard.queue_free()
	_set_bout(pair)


## Both stand, a new gap apart, the learner on either side, each with a new book.
func _set_bout(pair: Dictionary) -> void:
	var learner: Wizard = pair["learner"]
	var opponent: Wizard = pair["opponent"]
	var middle := ArenaGen.column_x(_lane_left(pair["lane"]) + LANE_COLS / 2)
	var gap := _rng_bouts.randf_range(GAP_LEAST, GAP_MOST)
	var side := 1.0 if _rng_bouts.randf() < 0.5 else -1.0
	var shift := _rng_bouts.randf_range(-300.0, 300.0)
	var agent: TacticsAgent = pair["agent"]
	agent.start = Vector2(middle + shift - side * gap * 0.5, ArenaGen.GROUND_Y - 2.0)
	learner.global_position = agent.start
	opponent.revive()
	opponent.max_stamina = Wizard.MAX_STAMINA
	opponent.stamina = Wizard.MAX_STAMINA
	opponent.global_position = Vector2(middle + shift + side * gap * 0.5, ArenaGen.GROUND_Y - 2.0)
	opponent.velocity = Vector2.ZERO
	pair["down"] = 0.0
	pair["age"] = 0.0
	pair["bouts"] += 1
	for wizard: Wizard in [learner, opponent]:
		wizard.ledger = _a_book()
		wizard.max_stamina = _rng_bouts.randf_range(WOUNDED_LEAST, Wizard.MAX_STAMINA)
		wizard.stamina = wizard.max_stamina
		wizard.facing = signf((opponent.global_position.x if wizard == learner else learner.global_position.x) - wizard.global_position.x)
	pair["began"] = [learner.max_stamina, opponent.max_stamina]


## Who won a bout that ran its time: 1 the learner, -1 its opponent, 0 neither (each lost the same share of the strength they began with, give or
## take a little).
func _points(pair: Dictionary) -> int:
	var began: Array = pair["began"]
	var learner_lost := 1.0 - (pair["learner"] as Wizard).max_stamina / maxf(began[0], 1.0)
	var opponent_lost := 1.0 - (pair["opponent"] as Wizard).max_stamina / maxf(began[1], 1.0)
	if absf(learner_lost - opponent_lost) < 0.02:
		return 0
	return 1 if learner_lost < opponent_lost else -1


## A book of a few attacking spells and a few others, drawn at random: a match deals books unlike each other, and so does this.
func _a_book() -> Ledger:
	var attacks: Array = TacticsBrain.ATTACKS.duplicate()
	var others: Array = SpellData.SPELLS.keys().filter(func(n: String) -> bool: return not n in TacticsBrain.ATTACKS)
	var pages: Array = []
	for i in _rng_bouts.randi_range(ATTACKS_LEAST, ATTACKS_MOST):
		pages.append(attacks.pop_at(_rng_bouts.randi() % attacks.size()))
	for i in _rng_bouts.randi_range(0, OTHERS_MOST):
		pages.append(others.pop_at(_rng_bouts.randi() % others.size()))
	return Ledger.of(pages)


func _physics_process(delta: float) -> void:
	for pair: Dictionary in _pairs:
		var learner: Wizard = pair["learner"]
		var opponent: Wizard = pair["opponent"]
		var agent: TacticsAgent = pair["agent"]
		if learner.dead or agent.done:
			continue
		pair["age"] += delta
		if opponent.dead:
			pair["down"] += delta
		if pair["down"] >= STAND_UP or pair["age"] >= BOUT_LIMIT:
			# The learner won the bout, or it went on too long and is decided on points (who lost the smaller share of their strength; even, nobody):
			# it ends, and the next begins with both standing (see _next_bout). Few bouts end in a fall, and a measure needs every bout to say something.
			agent.end_bout(0 if pair["down"] >= STAND_UP else _points(pair), pair["down"] < STAND_UP)
			pair["down"] = -1.0e9  # (once: _next_bout starts the counts again)
			pair["age"] = -1.0e9
	_nav_wait -= delta
	if _nav_wait <= 0.0:
		_nav_wait = NAV_EVERY
		for pair: Dictionary in _pairs:
			_read_lane(pair)

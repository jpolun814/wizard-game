extends Node

## Sets the AI wizards' brain against the frozen copy of the one before it (tests/legacy_brain, see tools/make_legacy_brain.py), and writes down who
## wins. Run many of them side by side with tools/ai_bench.py, which also adds the results up.
##
##     godot --headless --fixed-fps 60 --path . tests/tools/ai_arena.tscn -- mode=royale seed=7 old=1,3,5,7 result=FILE
##
## mode=royale: the whole match, eight wizards in the world, the seats named in old= play with the old brain (default none), the rest with the new.
## mode=duel: two wizards (seat 0 new, seat 1 old unless swap=1) a little way apart on level ground, each with the same spells, picked from the seed
## (three attacks, a way about and a defence); nobody else is in it.
## Each run appends one line of JSON to result=FILE: who played with which brain, and when each wizard fell (-1 for one still standing at the end).

var seed_value := 7
var mode := "royale"
var seconds := 1100.0  # of play, all the worlds of the match
var old_seats: Array[int] = []
var swap := false
var need: Array[String] = []  # need=A,B: these are in both books of a duel, whatever else the seed picks
var weak := -1  # weak=K: seat K begins worn down to a maximum of 60, for studying how a wounded wizard behaves
var result_file := ""
var log_file := ""  # log=FILE: every cast and wound, and where each wizard is every half second, for studying how they fight
var _log: FileAccess
var _log_t := 0.0
var _bonfires := 0
var fine := false  # fine=1: also a line of what everyone and every shot is doing, ten times a second (P and F lines)
var _fine_t := 0.0
var _world: World
var _seats: Array[Wizard] = []
var _clock := 0.0
var _fell := {}
var _done := false
var _worlds := 0
var _taken := {}  # seat -> damage it has taken in all
var _settle := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):
			seed_value = int(arg.substr(5))
		elif arg.begins_with("mode="):
			mode = arg.substr(5)
		elif arg.begins_with("seconds="):
			seconds = float(arg.substr(8))
		elif arg.begins_with("old=") and arg.length() > 4:
			for part in arg.substr(4).split(","):
				old_seats.append(int(part))
		elif arg == "fine=1":
			fine = true
		elif arg.begins_with("weak="):
			weak = int(arg.substr(5))
		elif arg.begins_with("need="):
			need.assign(arg.substr(5).split(","))
		elif arg == "swap=1":
			swap = true
		elif arg.begins_with("log="):
			log_file = arg.substr(4)
			_log = FileAccess.open(log_file, FileAccess.WRITE)
		elif arg.begins_with("result="):
			result_file = arg.substr(7)
	seed(seed_value)
	MatchState.begin(seed_value)
	if mode == "duel":  # (a flat open world, by the seed: no portals to carry them apart, no halls to lose each other in)
		MatchState.forced_biome = ["graveyard", "mountains", "jungle", "ashlands"][seed_value % 4]
	World.next_seed = seed_value
	# (a collapsing world takes the main scene with it, and the match goes on in the next: this stays where it is, above them, as the main scene no longer)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/world.tscn")


## A world of the match has just been built: the person's seat is given to a brain, and the seats named in old= to the old brain.
func _attach() -> void:
	_world = get_tree().current_scene
	_world.seat_work.give_player_to_a_brain()
	_seats.clear()
	for seat in _world.seats:
		_seats.append(seat)
	if mode == "duel":
		old_seats = [0 if swap else 1]
		_set_up_duel()
	for k in _seats.size():
		if old_seats.has(k) and _seats[k] != null:
			_seats[k].brain = OldSkyBrain.new(_seats[k]) if _world.flies() else OldWizardBrain.new(_seats[k])
	_worlds += 1
	for k in _seats.size():
		if _seats[k] != null:
			var seat := k
			_seats[k].damaged.connect(func(amount: int) -> void: _taken[seat] = _taken.get(seat, 0) + amount)
	if weak >= 0 and _worlds == 1 and weak < _seats.size() and _seats[weak] != null:
		_seats[weak].max_stamina = 60.0
		_seats[weak].stamina = 60.0
	if _log != null:
		for k in _seats.size():
			var w: Wizard = _seats[k]
			if w == null:
				continue
			var seat := k
			w.ensure_caster().cast_resolved.connect(func(spell: String, _t: String, _o: Vector2, _a: float, _i: Dictionary) -> void: _log.store_line("C %.2f %d %s" % [_clock, seat, spell]))
			w.damaged.connect(func(amount: int) -> void: _log.store_line("D %.2f %d %d %d %d %d" % [_clock, seat, amount, 1 if w.pen.active() else 0, int(w.velocity.length()), 1 if w.is_on_floor() else 0]))  # (then: drawing, how fast it moves, on the ground)


## Two wizards face to face on level ground with the same spells; everyone else is put away.
func _set_up_duel() -> void:
	for k in range(2, _seats.size()):
		if _seats[k] == null:
			continue
		_seats[k].set_physics_process(false)
		_seats[k].global_position = Vector2(-9000.0, -9000.0 - 200.0 * k)
		_seats[k].dead = true
		_seats[k].hide()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 977 + 13
	var spells: Array = need.duplicate()  # three attacks, a way about and a defence, as a match's first pages come
	for list: Array in [Pages.RANGED, Pages.RANGED, Pages.RANGED, Pages.MOVES, Pages.DEFENCES]:
		var pick: String = list[rng.randi() % list.size()]
		while spells.has(pick):
			pick = list[rng.randi() % list.size()]
		spells.append(pick)
	var spot := _seats[0].global_position
	_seats[0].global_position = _world.ground_below(spot + Vector2(0.0, -300.0))
	_seats[1].global_position = _world.ground_below(spot + Vector2(320.0, -300.0))
	for k in 2:
		for spell: String in spells:
			_seats[k].ledger.learn(spell)
	_duel_book = spells


var _duel_book: Array = []


func _physics_process(delta: float) -> void:
	if _done:
		return
	var scene := get_tree().current_scene
	if scene is World and scene != _world:
		_settle += 1
		if _settle >= 3:
			_settle = 0
			_attach()
		return
	if _world == null or scene != _world or not is_instance_valid(_world):
		return
	_clock += delta
	if int(_clock * 60.0) % 3600 == 0:
		print("%4.0f s of play, world %d, %d s of the clock" % [_clock, _worlds, Time.get_ticks_msec() / 1000])
	_log_t += delta
	if _log != null and _log_t >= 0.5:
		_log_t = 0.0
		var fires := get_tree().get_nodes_in_group("fires").filter(func(n: Node) -> bool: return n is Bonfire).size()
		if fires != _bonfires:
			_log.store_line("B %.1f %d" % [_clock, fires])
			_bonfires = fires
		for k in _seats.size():
			var w: Wizard = _seats[k]
			if is_instance_valid(w) and not w.dead:
				_log.store_line("S %.1f %d %d %d %d %d %s" % [_clock, k, w.global_position.x, w.global_position.y, w.stamina, w.max_stamina, w.brain.status()])
	_fine_t += delta
	if fine and _log != null and _fine_t >= 0.1:
		_fine_t = 0.0
		for k in _seats.size():
			var w: Wizard = _seats[k]
			if is_instance_valid(w) and not w.dead and (mode == "royale" or k < 2):
				_log.store_line("P %.1f %d %d %d %d %d %d %d %d" % [_clock, k, w.global_position.x, w.global_position.y, w.velocity.x, w.velocity.y, w.stamina, 1 if w.pen.active() else 0, 1 if w.is_on_floor() else 0])
		for shot: Node2D in get_tree().get_nodes_in_group("projectiles"):
			var owner_seat := _seats.find(shot.caster) if "caster" in shot else -1
			_log.store_line("F %.1f %d %d %d %s" % [_clock, owner_seat, shot.global_position.x, shot.global_position.y, shot.get_class() if shot.get_script() == null else str(shot.get_script().get_global_name())])
	var standing := 0
	var last := mode == "duel" or _seats.size() < 2
	for k in 8:
		var w: Wizard = _seats[k] if k < _seats.size() else null
		if is_instance_valid(w) and not w.dead:
			standing += 1
		elif not _fell.has(k) and (mode == "royale" or k < 2):
			_fell[k] = _clock
	if _clock >= seconds or standing <= 1 or (mode == "duel" and _fell.size() >= 1):
		_finish()


func _finish() -> void:
	_done = true
	var line := {"mode": mode, "seed": seed_value, "old": old_seats, "seconds": snappedf(_clock, 0.1), "worlds": _worlds, "taken": _taken, "fell": {}, "stamina": {}, "book": _duel_book}
	for k in 8:
		if mode == "duel" and k > 1:
			continue
		var w: Wizard = _seats[k] if k < _seats.size() else null
		line["fell"][str(k)] = snappedf(_fell[k], 0.1) if _fell.has(k) else -1.0
		line["stamina"][str(k)] = int(w.stamina + w.max_stamina) if is_instance_valid(w) and not w.dead else 0  # (stamina and what is left of the maximum: the one who has lost less is ahead when time runs out)
	if _log != null:
		_log.close()
	var text := JSON.stringify(line)
	print("RESULT ", text)
	if result_file != "":
		var file := FileAccess.open(result_file, FileAccess.READ_WRITE if FileAccess.file_exists(result_file) else FileAccess.WRITE)
		file.seek_end()
		file.store_line(text)
		file.close()
	get_tree().quit(0)

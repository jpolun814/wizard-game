extends Node

## Plays a world with only the AI wizards in it (the player's wizard stands down), and reports how they get on: where each one is, what it is
## after, how many pages it has read, who has been beaten. For finding out whether the wizards can walk the world, collect its pages and fight, and
## for balancing them. It needs the game's own scenes, so it runs as a scene, and with a fixed frame rate so that a minute of play takes seconds:
##
##     godot --headless --path . --fixed-fps 60 tests/arena_sim.tscn -- seed=7 seconds=240
## Other arguments: watch=1 follows a wizard with a camera (run without --headless to see it), report=SECONDS between reports (default 30), keep=1 to leave the player's wizard in play as a target that stands still.
## It prints a summary at the end and exits with code 1 when a wizard never gets going (reads no page in the time) or falls out of the world.

var seed_value := 7
var seconds := 240.0
var report := 30.0
var keep_player := false
var _world: World
var _wizards: Array[Wizard] = []
var _clock := 0.0
var _next_report := 0.0
var _first_page := {}  # wizard -> game seconds when it read its first page
var _beaten := {}
var _failed := false
var _shot := ""  # shot=FILE saves a picture of the screen after two seconds (needs a window)
var _stage := 0  # stage=N plays in the Nth world of a match, with everyone as they start
var _sketch := Vector2i(-1, -1)  # sketch=X,Y prints the map round that tile at the end
var _finished := false
var _seen: Array[Dictionary] = []  # for each wizard, in the order of _wizards: {"kind", "pages": how many it held when last seen}
var _set_up := false
var _kill_at := -1.0  # kill=SECONDS fells the wizard with the most pages then, and reports whether anyone reads the book it drops
var _killed := false
var _log: FileAccess  # log=FILE writes what every wizard does, four times a second, and each cast and wound, for studying how they behave
var _log_t := 0.0
var _shot_at := 2.0  # shotat=SECONDS: when shot= takes its picture
var _follow := -1  # follow=N: the camera stays on the Nth wizard
var _probe := Vector2(-1, 0)  # probe=N,SECONDS prints every variable of the Nth wizard's brain at that time
var _probed := false
var _zoom := 1.5
var _fight_dir := ""  # fightshots=DIR: pictures of the first wizards who come to blows
var _fight_frames := 0
var _fight_t := 0.0
var _watch := false  # watch=1: a camera follows a wizard still standing, for looking at the match in a window
var _camera: Camera2D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):
			seed_value = int(arg.substr(5))
		elif arg.begins_with("seconds="):
			seconds = float(arg.substr(8))
		elif arg.begins_with("report="):
			report = float(arg.substr(7))
		elif arg.begins_with("stage="):
			_stage = int(arg.substr(6))
		elif arg.begins_with("shot="):
			_shot = arg.substr(5)
		elif arg.begins_with("sketch="):
			_sketch = Vector2i(int(arg.get_slice(",", 0).substr(7)), int(arg.get_slice(",", 1)))
		elif arg.begins_with("kill="):
			_kill_at = float(arg.substr(5))
		elif arg.begins_with("log="):
			_log = FileAccess.open(arg.substr(4), FileAccess.WRITE)
		elif arg.begins_with("shotat="):
			_shot_at = float(arg.substr(7))
		elif arg.begins_with("follow="):
			_follow = int(arg.substr(7))
		elif arg.begins_with("probe="):
			_probe = Vector2(int(arg.substr(6).get_slice(",", 0)), float(arg.substr(6).get_slice(",", 1)))
		elif arg.begins_with("zoom="):
			_zoom = float(arg.substr(5))
		elif arg.begins_with("fightshots="):
			_fight_dir = arg.substr(11)
			_watch = true
		elif arg == "watch=1":
			_watch = true
		elif arg == "keep=1":
			keep_player = true
	seed(seed_value)  # the starting places are chosen with the global rng
	World.next_seed = seed_value
	if _stage > 0:
		MatchState.begin(seed_value)
		MatchState.stage = _stage
		MatchState.pending = true
		MatchState.ledgers = Pages.deal(seed_value + 31, World.WIZARDS)
		for k in World.WIZARDS:
			MatchState.vitals.append({"alive": true, "max": 200.0, "stamina": 200.0})
	_world = load("res://scenes/world.tscn").instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	if not keep_player:
		_world.player.dead = true  # a wizard that is down is no one's target
		_world.player.hide()
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if wizard != _world.player:
			_wizards.append(wizard)
	if _log != null:
		for w in _wizards:
			var who: String = w.look + str(_wizards.find(w))
			if w.caster != null:
				w.caster.cast_resolved.connect(func(spell: String, _t: String, _o: Vector2, _a: float, _i: Dictionary) -> void: _log.store_line("C %.2f %s %s" % [_clock, who, spell]))
			w.damaged.connect(func(amount: int) -> void: _log.store_line("D %.2f %s %d" % [_clock, who, amount]))
	if _watch:
		_camera = Camera2D.new()
		_camera.zoom = Vector2(_zoom, _zoom)
		_camera.position_smoothing_enabled = true
		add_child(_camera)
		_camera.make_current()
	_set_up = true
	print("seed %d: %d wizards in a world of %s tiles; the player stands at %s" % [seed_value, _wizards.size(), str(ArenaGen.world_size), str(_world.player.global_position)])
	for wizard in _wizards:
		_seen.append({"kind": wizard.look, "pages": wizard.ledger.count()})
		print("   %s at %s holds %d pages" % [wizard.look, str(wizard.global_position), wizard.ledger.count()])


func _physics_process(delta: float) -> void:
	if not _set_up or _finished:
		return
	if _wizards.is_empty():
		_fail_to_start()
		return
	_clock += delta
	if _camera != null:
		if _follow >= 0 and is_instance_valid(_wizards[_follow]):
			_camera.global_position = _wizards[_follow].global_position
		var followed := _wizards.filter(func(w) -> bool: return is_instance_valid(w) and not w.dead)
		if not followed.is_empty():
			var target: Wizard = _camera.get_meta(&"target", null) if _camera.has_meta(&"target") else null
			if target == null or not is_instance_valid(target) or target.dead:
				target = followed[0]
				_camera.set_meta(&"target", target)
			if _follow < 0:
				_camera.global_position = target.global_position
	if _shot != "" and _clock > _shot_at:
		get_viewport().get_texture().get_image().save_png(_shot)
		_shot = ""
	_log_t += delta
	if _log != null and _log_t >= 0.25:
		_log_t = 0.0
		for i in _wizards.size():
			var w := _wizards[i]
			if is_instance_valid(w) and not w.dead:
				var foe_gap := -1
				var foe_at := -1
				if w.brain._foe != null and is_instance_valid(w.brain._foe):
					foe_gap = int(w.center().distance_to(w.brain._foe.center()))
					foe_at = _wizards.find(w.brain._foe)
				_log.store_line("S %.2f %s%d %d %d %d %d %d %d %d %d %d %d %s %s" % [_clock, w.look, i, w.global_position.x, w.global_position.y, w.velocity.x, w.velocity.y, 1 if w.is_on_floor() else 0, w.stamina, w.max_stamina, foe_at, foe_gap, 1 if w.is_drawing() else 0, _flags(w), w.brain.status()])
	for i in _wizards.size():
		var wizard := _wizards[i]
		if is_instance_valid(wizard) and not wizard.dead:
			_seen[i]["pages"] = wizard.ledger.count()
			if not _first_page.has(wizard) and wizard.ledger.count() > 5:
				_first_page[wizard] = _clock
			if wizard.global_position.y > ArenaGen.world_size.y * 32.0:
				print("FAIL  %s has fallen out of the world" % wizard.look)
				_failed = true
		elif not _beaten.has(wizard):
			_beaten[wizard] = _clock
			if is_instance_valid(wizard):
				print("        %s fell at tile (%d, %d)" % [wizard.look, wizard.global_position.x / 32.0, wizard.global_position.y / 32.0])
	if _kill_at >= 0.0 and _clock >= _kill_at and not _killed:
		_killed = true
		var richest: Wizard = null
		for w in _wizards:
			if is_instance_valid(w) and not w.dead and (richest == null or w.ledger.count() > richest.ledger.count()):
				richest = w
		if richest != null:
			print("KILL %s at tile (%d, %d) holding %d pages" % [richest.look, richest.global_position.x / 32.0, richest.global_position.y / 32.0, richest.ledger.count()])
			richest.take_damage(100000, false)
	if _killed and fmod(_clock, 10.0) < delta:
		for pickup: PagePickup in get_tree().get_nodes_in_group("pages"):
			if not pickup.spoils.is_empty():
				print("SPOILS still lie at tile (%d, %d) at %.0fs" % [pickup.global_position.x / 32.0, pickup.global_position.y / 32.0, _clock])
	if _probe.x >= 0 and not _probed and _clock >= _probe.y:
		_probed = true
		var b: Object = _wizards[int(_probe.x)].brain
		for prop in b.get_property_list():
			if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
				var v: Variant = b.get(prop["name"])
				if v is Object or v is Callable:
					continue
				print("PROBE ", prop["name"], " = ", str(v).substr(0, 160))
		if b._goal_page != null and is_instance_valid(b._goal_page):
			print("PROBE page at ", b._goal_page.global_position / 32.0, " ", b._goal_page.name, " spoils ", b._goal_page.spoils.size())
		print("PROBE pos ", _wizards[int(_probe.x)].global_position / 32.0, " floor ", _wizards[int(_probe.x)].is_on_floor())
	if _fight_dir != "" and _camera != null:
		_fight_t -= delta
		var best := 1e9
		var pair: Array = []
		for a in _wizards:
			for b in _wizards:
				if a != b and is_instance_valid(a) and is_instance_valid(b) and not a.dead and not b.dead:
					var d: float = a.global_position.distance_to(b.global_position)
					if d < best:
						best = d
						pair = [a, b]
		if pair.size() == 2 and (best < 380.0 or _fight_frames > 0) and _fight_frames < 14:
			_camera.global_position = (pair[0].global_position + pair[1].global_position) * 0.5 - Vector2(0, 40)
			if _fight_t <= 0.0:
				_fight_t = 0.35
				get_viewport().get_texture().get_image().save_png("%s/f%02d.png" % [_fight_dir, _fight_frames])
				_fight_frames += 1
	if _clock >= _next_report:
		_next_report += report
		_print_state()
	var standing := _wizards.filter(func(w) -> bool: return is_instance_valid(w) and not w.dead)
	if _clock >= seconds or standing.size() <= (0 if keep_player else 1):
		_finish(standing.size())


func _fail_to_start() -> void:
	print("FAIL  no wizards in the world")
	get_tree().quit(1)


func _print_state() -> void:
	var pages := get_tree().get_nodes_in_group("pages").size()
	print("%5.0fs  %d pages still lie on the map" % [_clock, pages])
	for i in _wizards.size():
		var wizard := _wizards[i]
		if not is_instance_valid(wizard) or wizard.dead:
			print("        %-12s beaten at %.0fs" % [_seen[i]["kind"], _beaten.get(wizard, _clock)])
			continue
		var brain: WizardBrain = wizard.brain
		print("        %-12s at tile (%d, %d)  %3d pages  max %3d  stamina %3d  going for: %s  [%s%s v(%d,%d)]" % [wizard.look, wizard.global_position.x / 32.0, wizard.global_position.y / 32.0, wizard.ledger.count(), wizard.max_stamina, wizard.stamina, brain.status(), "floor " if wizard.is_on_floor() else "air ", "wall %s" % _hit(wizard) if wizard.is_on_wall() else "", wizard.velocity.x, wizard.velocity.y])


func _finish(standing: int) -> void:
	_finished = true
	for w in _wizards:
		if is_instance_valid(w):
			var known := []
			for id in RitualInput.RITUALS:
				if w.ledger.knows_chant(id):
					known.append(id)
			print("CHANTS ", w.look, " ", known, " spells ", w.ledger.count())
	if _log != null:
		_log.close()
	print("--- after %.0f seconds: %d of %d wizards standing" % [_clock, standing, _wizards.size()])
	for i in _wizards.size():
		var wizard := _wizards[i]
		var alive := is_instance_valid(wizard) and not wizard.dead
		var info: Dictionary = _seen[i]
		var got: int = info["pages"] - 5
		print("    %-12s %s, read %d pages%s" % [info["kind"], "standing" if alive else "beaten at %.0fs" % _beaten.get(wizard, 0.0), got, ", the first at %.0fs" % _first_page[wizard] if _first_page.has(wizard) else ", none at all"])
		if got <= 0 and _clock >= 120.0 and not _beaten.has(wizard):
			print("FAIL  %s read no page in %.0f seconds" % [info["kind"], _clock])
			_failed = true
	for i in _wizards.size():
		if is_instance_valid(_wizards[i]):
			var held: Array[String] = _wizards[i].brain.stuck_at
			print("    %s was held up %d times%s" % [_seen[i]["kind"], held.size(), (": " + "; ".join(held.slice(0, 4))) if not held.is_empty() else ""])
	for pickup: PagePickup in get_tree().get_nodes_in_group("pages"):  # the pages still lying about at the end, and whether anyone standing could walk to them
		var tile := Vector2i(floori(pickup.global_position.x / 32.0), floori(pickup.global_position.y / 32.0))
		var line := "    page left at tile %s (%s)" % [tile, pickup.name]
		for i in _wizards.size():
			if is_instance_valid(_wizards[i]) and not _wizards[i].dead:
				var brain: WizardBrain = _wizards[i].brain
				var from: Vector2i = _world.nav.nearest(Vector2i(floori(_wizards[i].global_position.x / 32.0), floori(_wizards[i].global_position.y / 32.0)), true)
				var to: Vector2i = _world.nav.nearest(tile)
				line += " | %s: seen %s path %d" % [_seen[i]["kind"].substr(0, 4), brain._seen_pages.has(pickup.get_instance_id()), _world.nav.path(from, to, []).size()]
				break
		print(line)
	if _sketch.x >= 0:
		print(_world.nav.sketch(_sketch))
	print("the wizards' play looks right" if not _failed else "something is wrong")
	get_tree().quit(1 if _failed else 0)


## What a wizard that is against a wall has run into.
func _hit(wizard: Wizard) -> String:
	var out := ""
	for k in wizard.get_slide_collision_count():
		var hit := wizard.get_slide_collision(k)
		out += "%s at %s normal %s; " % [hit.get_collider(), str(hit.get_position()), str(hit.get_normal())]
	return out


## A letter for each thing that holds a wizard back, for the log: Rooted, Sinking, Tangled, Fainted, Frozen, slowed (Mud), Waiting for danger, Settling, Off the map, Wandering.
func _flags(w: Wizard) -> String:
	var out := ""
	if w.root_time > 0.0: out += "R"
	if w.sink_time > 0.0: out += "S"
	if w.tangle_time > 0.0: out += "T"
	if w.fainted: out += "F"
	if w.is_frozen(): out += "Z"
	if w.is_slowed(): out += "M"
	var b: WizardBrain = w.brain
	if b._danger_wait > 0.5: out += "W"
	if b._settle > 0.0: out += "s"
	if b._off_map: out += "O"
	if b._wander_time > 0.0: out += "w"
	if b._resting: out += "r"
	if b._camped: out += "c"
	return out if out != "" else "-"

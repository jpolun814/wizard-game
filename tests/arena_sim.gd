extends Node

## Plays a world with only the AI wizards in it (the player's wizard stands down), and reports how they get on: where each one is, what it is
## after, how many pages it has read, who has been beaten. For finding out whether the wizards can walk the world, collect its pages and fight, and
## for balancing them. It needs the game's own scenes, so it runs as a scene, and with a fixed frame rate so that a minute of play takes seconds:
##
##     godot --headless --path . --fixed-fps 60 tests/arena_sim.tscn -- seed=7 seconds=240
## Other arguments: report=SECONDS between reports (default 30), keep=1 to leave the player's wizard in play as a target that stands still.
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
		elif arg == "keep=1":
			keep_player = true
	seed(seed_value)  # the starting places are chosen with the global rng
	World.next_seed = seed_value
	if _stage > 0:
		MatchState.begin(seed_value)
		MatchState.stage = _stage
		MatchState.pending = true
		MatchState.ledgers = Pages.deal(seed_value + 31, World.WIZARDS)
		for k in 4:
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
	if _shot != "" and _clock > 2.0:
		get_viewport().get_texture().get_image().save_png(_shot)
		_shot = ""
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
	print("--- after %.0f seconds: %d of %d wizards standing" % [_clock, standing, _wizards.size()])
	for i in _wizards.size():
		var wizard := _wizards[i]
		var alive := is_instance_valid(wizard) and not wizard.dead
		var info: Dictionary = _seen[i]
		var got: int = info["pages"] - 5
		print("    %-12s %s, read %d pages%s" % [info["kind"], "standing" if alive else "beaten at %.0fs" % _beaten.get(wizard, 0.0), got, ", the first at %.0fs" % _first_page[wizard] if _first_page.has(wizard) else ", none at all"])
		if got <= 0 and _clock >= 60.0 and not _beaten.has(wizard):
			print("FAIL  %s read no page in %.0f seconds" % [info["kind"], _clock])
			_failed = true
	for i in _wizards.size():
		if is_instance_valid(_wizards[i]):
			var held: Array[String] = _wizards[i].brain.stuck_at
			print("    %s was held up %d times%s" % [_seen[i]["kind"], held.size(), (": " + "; ".join(held.slice(0, 4))) if not held.is_empty() else ""])
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

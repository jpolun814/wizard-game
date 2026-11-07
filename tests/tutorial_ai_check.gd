extends Node

## An AI wizard is put in the tutorial room with nothing but its own mind, and watched. Nothing here is written for the room: it is the same brain that plays
## a match. It prints where it is every ten seconds, and passes if it reaches the portal at the far end.
##
##     godot --headless --fixed-fps 60 --path . tests/tutorial_ai_check.tscn -- seconds=600

var seconds := 600.0
var start_col := -1000  ## begin here with every page read (to look at one place)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seconds="):
			seconds = float(arg.substr(8))
		elif arg.begins_with("start="):
			start_col = int(arg.substr(6))
		elif arg.begins_with("speed="):
			Engine.time_scale = float(arg.substr(6))
			Engine.max_physics_steps_per_frame = 16
	var room: Tutorial = load("res://scenes/tutorial.tscn").instantiate()
	add_child(room)
	for k in 20:
		await get_tree().process_frame
	var wizard: Wizard = room.player
	if start_col > -1000:
		wizard.ledger = Ledger.complete()
		wizard.global_position = Vector2(ArenaGen.column_x(start_col), ArenaGen.surface_y(room._cells, start_col) - 20.0)
	wizard.human = false
	wizard.ensure_caster()
	room.read_room(Vector2i(floori(wizard.global_position.x / 32.0), floori(wizard.global_position.y / 32.0)))
	wizard.nav = room.nav
	wizard.brain = WizardBrain.new(wizard)
	print("nav tiles: %d" % wizard.nav.size())
	for crossing in room.crossings():
		print("crossing ", crossing["kind"], " ", crossing["key"], " ", crossing["span"])
	for gate in room.closed_gates():
		print("gate ", gate["kind"], " ", gate["outside"])
	var here := Vector2i(floori(wizard.global_position.x / 32.0), floori((wizard.global_position.y - 1.0) / 32.0))
	print("start tile ", here, " nearest ", wizard.nav.nearest(here, true))
	for pickup in get_tree().get_nodes_in_group("pages"):
		var tile := Vector2i(floori(pickup.global_position.x / 32.0), floori(pickup.global_position.y / 32.0))
		print("page ", tile, " stand ", wizard.nav.nearest(tile))
		var way := wizard.nav.path(wizard.nav.nearest(here, true), wizard.nav.nearest(tile))
		print("path size ", way.size(), " standing there? ", wizard.nav.can_stand(here), " ", wizard.nav.can_stand(here + Vector2i(1, 0)), " ", wizard.nav.can_stand(here + Vector2i(5, 0)))
		print("gives ", pickup.gives(wizard.ledger), " dist ", absi(wizard.nav.nearest(tile).x - tile.x) + absi(wizard.nav.nearest(tile).y - tile.y))
		break
	print("brain path: ", wizard.brain._path(wizard.nav.nearest(here, true), Vector2i(-16, 12)))
	wizard.brain._choose_goal()
	print("goal after choosing: ", wizard.brain._goal, " ", wizard.brain._skip, " wizards ", SpellTargets.wizards(get_tree()).size(), " foe ", wizard.brain._nearest_foe())
	var deaths := 0
	wizard.died.connect(func() -> void: deaths += 1)
	var far := float(ArenaGen.right_wall - 8)
	var elapsed := 0.0
	var next_report := 0.0
	var last_word := ""
	while elapsed < seconds:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
		var word: String = wizard.brain._goal
		if elapsed > 160.0 and word != last_word:
			last_word = word
			print("CHANGE t=%.1f goal '%s' col %.1f stamina %.0f gate %s" % [elapsed, word, wizard.global_position.x / 32.0, wizard.stamina, wizard.brain._goal_gate.get("kind", "-")])
		if elapsed >= next_report:
			next_report += 10.0 if elapsed < 235.0 else 0.5
			print("t=%3.0f column %.0f  stamina %.0f/%.0f  deaths %d  barrier %s smoke %s  goal %s" % [elapsed, wizard.global_position.x / 32.0, wizard.stamina, wizard.max_stamina, deaths, wizard.brain._knows("Barrier"), wizard.brain._knows("Smoke Screen"), wizard.brain.status()])
		if wizard.global_position.x / 32.0 >= far:
			print("PASS  reached the end at t=%.0f" % elapsed)
			get_tree().quit(0)
			return
	for gate in room.closed_gates():
		print("gate ", gate["kind"], " ", gate["outside"], " clearing: '", wizard.brain._clearing_spell(gate["kind"]), "' skip ", wizard.brain._skip.has(wizard.brain._gate_key(gate)))
	var b = wizard.brain
	print("INTERNALS leap ", b._leap, " lift ", b._lift, " wade ", b._wade, " settle ", b._settle, " resting ", b._resting, " drawing ", wizard.is_drawing(), " cd ", b._cast_cooldown, " react ", b._react, " goal_timer ", b._goal_timer, " floor ", wizard.is_on_floor(), " fainted ", wizard.fainted, " stam ", wizard.stamina, " vel ", wizard.velocity, " rocket ", wizard.rocket_time, " feather ", wizard.get("feather_time"), " tangle ", wizard.tangle_time, " obstacle ", wizard.is_on_wall())
	var begin: Vector2i = wizard.nav.nearest(Vector2i(floori(wizard.global_position.x / 32.0), floori((wizard.global_position.y - 1.0) / 32.0)), true)
	print("start ", begin, " choose gate -> ", wizard.brain._choose_gate(begin), " goal ", wizard.brain._goal, " tolls at start '", wizard.nav.toll_at(begin), "' pos ", wizard.global_position / 32.0)
	print(wizard.nav.sketch(Vector2i(375, 5)))
	print("AHEAD ", wizard.brain._crossing_ahead().get("kind", "-"), " ", wizard.brain._crossing_ahead().get("key", "-"), " bridged ", wizard.brain._bridged, " cannot ", wizard.brain._cannot, " cross_run ", wizard.brain._cross_run, " drawing ", wizard.is_drawing(), " react ", wizard.brain._react)
	if wizard.brain._goal == "gate":
		var entry: Dictionary = wizard.brain._goal_gate
		print("GATE ", entry["kind"], " target ", room.gate_target(entry["entry"]), " wizard ", wizard.center(), " spell ", wizard.brain._clearing_spell(entry["kind"]))
	print("FAIL  got as far as column %.0f" % (wizard.global_position.x / 32.0))
	get_tree().quit(1)

extends Node

## An AI wizard is put in the tutorial room with nothing but its own mind, and watched. Nothing here is written for the room: it is the same brain that plays
## a match. It prints where it is every ten seconds, and passes if it reaches the portal at the far end.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/tutorial_ai_check.tscn -- seconds=600

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
	print("brain path: ", wizard.brain.travel.find_path(wizard.nav.nearest(here, true), Vector2i(-16, 12)))
	wizard.brain.travel.choose_goal()
	print("goal after choosing: ", wizard.brain.goal, " ", wizard.brain.skip, " wizards ", SpellTargets.wizards(get_tree()).size(), " foe ", wizard.brain.sight.nearest_foe())
	var deaths := 0
	wizard.died.connect(func() -> void: deaths += 1)
	var far := float(ArenaGen.right_wall - 8)
	var elapsed := 0.0
	var next_report := 0.0
	var last_word := ""
	while elapsed < seconds:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
		var word: String = wizard.brain.goal
		if elapsed > 160.0 and word != last_word:
			last_word = word
			print("CHANGE t=%.1f goal '%s' col %.1f stamina %.0f gate %s" % [elapsed, word, wizard.global_position.x / 32.0, wizard.stamina, wizard.brain.gates.goal_gate.get("kind", "-")])
		if elapsed >= next_report:
			next_report += 10.0 if elapsed < 235.0 else 0.5
			print("t=%3.0f column %.0f  stamina %.0f/%.0f  deaths %d  barrier %s smoke %s  goal %s" % [elapsed, wizard.global_position.x / 32.0, wizard.stamina, wizard.max_stamina, deaths, wizard.brain.knows("Barrier"), wizard.brain.knows("Smoke Screen"), wizard.brain.status()])
		if wizard.global_position.x / 32.0 >= far:
			print("PASS  reached the end at t=%.0f" % elapsed)
			get_tree().quit(0)
			return
	for gate in room.closed_gates():
		print("gate ", gate["kind"], " ", gate["outside"], " clearing: '", wizard.brain.gates.clearing_spell(gate["kind"]), "' skip ", wizard.brain.skip.has(wizard.brain.gates.gate_key(gate)))
	var b = wizard.brain
	print("INTERNALS leap ", b.moves.leap, " lift ", b.moves.lift, " wade ", b.moves.wade, " settle ", b.settle, " resting ", b.mend.resting, " drawing ", wizard.pen.active(), " cd ", b.cast_cooldown, " react ", b.react, " goal_timer ", b.goal_timer, " floor ", wizard.is_on_floor(), " fainted ", wizard.fainted, " stam ", wizard.stamina, " vel ", wizard.velocity, " rocket ", wizard.rocket_time, " feather ", wizard.get("feather_time"), " tangle ", wizard.tangle_time, " obstacle ", wizard.is_on_wall())
	var begin: Vector2i = wizard.nav.nearest(Vector2i(floori(wizard.global_position.x / 32.0), floori((wizard.global_position.y - 1.0) / 32.0)), true)
	print("start ", begin, " choose gate -> ", wizard.brain.travel.choose_gate(begin), " goal ", wizard.brain.goal, " tolls at start '", wizard.nav.toll_at(begin), "' pos ", wizard.global_position / 32.0)
	print(wizard.nav.sketch(Vector2i(375, 5)))
	print("AHEAD ", wizard.brain.gates.crossing_ahead().get("kind", "-"), " ", wizard.brain.gates.crossing_ahead().get("key", "-"), " bridged ", wizard.brain.gates.bridged, " cannot ", wizard.brain.gates.cannot, " cross_run ", wizard.brain.gates.cross_run, " drawing ", wizard.pen.active(), " react ", wizard.brain.react)
	if wizard.brain.goal == "gate":
		var entry: Dictionary = wizard.brain.gates.goal_gate
		print("GATE ", entry["kind"], " target ", room.gate_target(entry["entry"]), " wizard ", wizard.center(), " spell ", wizard.brain.gates.clearing_spell(entry["kind"]))
	print("FAIL  got as far as column %.0f" % (wizard.global_position.x / 32.0))
	get_tree().quit(1)

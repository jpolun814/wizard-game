extends Node

## An AI wizard is put in the tutorial room with nothing but its own mind, and watched. Nothing here is written for the room: it is the same brain that plays
## a match. It prints where it is every ten seconds, and passes if it reaches the portal at the far end.
##
##     godot --headless --fixed-fps 60 --path . tests/tutorial_ai_check.tscn -- seconds=600

var seconds := 600.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seconds="):
			seconds = float(arg.substr(8))
	var room: Tutorial = load("res://scenes/tutorial.tscn").instantiate()
	add_child(room)
	for k in 20:
		await get_tree().process_frame
	var wizard: Wizard = room.player
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
	while elapsed < seconds:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
		if elapsed >= next_report:
			next_report += 10.0
			print("t=%3.0f column %.0f  stamina %.0f/%.0f  deaths %d  barrier %s smoke %s  goal %s" % [elapsed, wizard.global_position.x / 32.0, wizard.stamina, wizard.max_stamina, deaths, wizard.brain._knows("Barrier"), wizard.brain._knows("Smoke Screen"), wizard.brain.status()])
		if wizard.global_position.x / 32.0 >= far:
			print("PASS  reached the end at t=%.0f" % elapsed)
			get_tree().quit(0)
			return
	print("FAIL  got as far as column %.0f" % (wizard.global_position.x / 32.0))
	get_tree().quit(1)

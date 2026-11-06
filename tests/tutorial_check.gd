extends Node

## The tutorial room: the book starts empty, the keys to walk and jump show at the start, a page lies at each place and reading it puts its spell in the
## book, whoever falls keeps what they have read, and the library counts what a match does.
## With `-- out=DIR` (and no --headless) it also saves a picture of the start.
##
##     godot --headless --fixed-fps 60 --path . tests/tutorial_check.tscn
## It prints PASS or FAIL and exits with code 1 if any failed.

var _failures := 0
var _out := ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			_out = argument.trim_prefix("out=")
	await _library_check()
	var room: Tutorial = load("res://scenes/tutorial.tscn").instantiate()
	add_child(room)
	for k in 90:
		await get_tree().physics_frame
	var player: Wizard = room.player
	_verdict(player.ledger.count() == 0 and not player.ledger.knows_spell("Ignite"), "the book starts empty")
	_verdict(room._hint != null, "the keys to walk and jump are on screen at the start")
	if _out != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(_out)
		get_viewport().get_texture().get_image().save_png("%s/tutorial_start.png" % _out)
	if _out != "" and DisplayServer.get_name() != "headless":
		room._dummy.take_damage(1000)  # (so that the pictures are of the room, not of a wizard struck down)
		room._giant.faint()
		player.veil = 999
		for look: Array in [[2, "giant"], [22, "pond"], [214, "dark"], [330, "wall"], [396, "sentinel"], [490, "pond2"]]:
			player.global_position = Vector2(ArenaGen.column_x(look[0]), ArenaGen.surface_y(room._cells, look[0]) - 20.0)
			player.velocity = Vector2.ZERO
			if look[1] == "dark":
				room.spawn_spell("Flare", "positional", player.center() + Vector2(60.0, -40.0), 0.0, {}, player)
			for f in 40:
				await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/tutorial_%s.png" % [_out, look[1]])
		player.global_position = Vector2(ArenaGen.column_x(-31), ArenaGen.surface_y(room._cells, -31) - 20.0)
		player.veil = 0
		for f in 20:
			await get_tree().physics_frame
	player.ledger = Ledger.of(["Ignite"])  # a fan with a page the book has is laid out again with only the new one
	for f in 10:
		await get_tree().physics_frame
	var burn_pages: Array = get_tree().get_nodes_in_group("pages").filter(func(n: PagePickup) -> bool: return not n.is_queued_for_deletion() and absf(n.position.x - ArenaGen.column_x(108)) < 4.0)
	_verdict(burn_pages.size() == 1 and burn_pages[0].spoils.is_empty() and burn_pages[0].page == "Fire Breath", "a fan with a page the book already holds shows only what is new")
	player.ledger = Ledger.of([])
	for f in 10:
		await get_tree().physics_frame
	var pickups := get_tree().get_nodes_in_group("pages")
	_verdict(pickups.size() == Tutorial.PAGE_SPOTS.size(), "a page or a fan of pages lies at each spot (%d)" % pickups.size())
	for spot: Array in Tutorial.PAGE_SPOTS:
		for name: String in spot[1]:
			_verdict(SpellData.SPELLS.has(name) or name.begins_with("chant:"), "the page %s exists" % name)
	# each place's pages, read in turn from an empty book
	for pickup: PagePickup in pickups.duplicate():
		if not pickup.is_queued_for_deletion() and pickup.gives(player.ledger):
			var names: Array = pickup.spoils.duplicate() if not pickup.spoils.is_empty() else [pickup.page]
			pickup.take(player.ledger)
			for name: String in names:
				_verdict(player.ledger.knows(name), "reading the pages at one place puts %s in the book" % name)
	for f in 10:
		await get_tree().physics_frame
	var left := 0
	for pickup: PagePickup in get_tree().get_nodes_in_group("pages"):
		if not pickup.is_queued_for_deletion():
			left += 1
	_verdict(left == 0, "a page the book already has is taken away (left %d)" % left)
	# whoever falls keeps what they have read, and is put back at the start of the place
	var column := 58
	player.global_position = Vector2(ArenaGen.column_x(column), ArenaGen.surface_y(room._cells, column) - 20.0)
	for f in 10:
		await get_tree().physics_frame
	room._on_player_died()
	for f in 20:
		await get_tree().physics_frame
	_verdict(player.ledger.knows_spell("Barrier") and player.ledger.knows_spell("Faint"), "whoever falls keeps the spells they had read")
	_verdict(absf(player.global_position.x / float(ArenaGen.TILE) - 47.0) < 2.0, "and is back at the start of the place (column %.1f)" % (player.global_position.x / float(ArenaGen.TILE)))
	player.ledger = Ledger.of(["Faint", "Ignite", "chant:double_jump", "Barrier"])  # the book holds pages in the order they were found, not by school
	room.spellbook.refresh()
	var order: Dictionary = room.spellbook._page_of
	_verdict(order["Faint"] < order["Ignite"] and order["Ignite"] < order["chant:double_jump"] and order["chant:double_jump"] < order["Barrier"], "the book keeps its pages in the order they were found")
	var lectern_run := room._lectern != null
	room._lectern.body_entered.emit(player)
	_verdict(lectern_run and room._leaving and room._lectern.body_entered.is_connected(room._on_book_touched), "touching the book leads back to the first screen, not into a match")
	print("the tutorial room works" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## The library keeps what it is told, and writes it out and reads it back.
func _library_check() -> void:
	Library.force = true
	Library.use_file("user://library_test.json")
	Library.clear()
	MatchState.begin(3)
	Library.record_match_begun()
	Library.record_page("Ignite")
	Library.record_page("Ignite")
	Library.record_cast("Ignite")
	Library.record_win(["Ignite", "chant:minimap"])
	Library.flush()
	var stats := Library.stats()
	_verdict(stats["matches"] == 1 and stats["wins"] == 1, "the library counts a match and a win")
	_verdict(stats["pages"]["Ignite"] == 2 and stats["casts"]["Ignite"] == 1 and stats["won_with"]["chant:minimap"] == 1, "and each page found, each spell cast, each win with a page")
	var here := Library.stats_for(str(MatchState.biome_of(MatchState.stage)))
	_verdict(here["wins"] == 1 and here["casts"]["Ignite"] == 1 and Library.stats_for("")["wins"] == 1, "and the same counts are kept for the kind of world it was in")
	var text := FileAccess.get_file_as_string(Library.path)
	var read: Variant = JSON.parse_string(text)
	_verdict(read is Dictionary and int(read["pages"]["Ignite"]) == 2, "and it is written to a file that can be read back")
	Library.clear()
	Library.force = false
	Library.use_file(Library.PATH)
	MatchState.begin(0)  # as it was before the check


func _left_click() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

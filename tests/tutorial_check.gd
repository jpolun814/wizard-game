extends Node

## The tutorial room: a page shows at each place, trying its spell marks it done, and the library counts what a match does.
## With `-- out=DIR` (and no --headless) it also saves a picture of the page at each place.
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
	for k in 20:
		await get_tree().process_frame
	var player: Wizard = room.player
	for k in Tutorial.PLACES.size():
		var place: Dictionary = Tutorial.PLACES[k]
		var spot := Vector2(ArenaGen.column_x(place["col"]), ArenaGen.surface_y(room._cells, place["col"]))
		player.global_position = spot + Vector2(0.0, -20.0)
		player.velocity = Vector2.ZERO
		for f in 12:
			await get_tree().physics_frame
		_verdict(room._shown == k and room._panel != null, "the page for %s is up where it stands" % place["title"])
		if _out != "" and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(_out)
			get_viewport().get_texture().get_image().save_png("%s/tutorial_%d_%s.png" % [_out, k, place["title"]])
		if place.has("steps"):
			for step: Array in place["steps"]:
				if String(step[0]).begins_with("chant:"):
					room._on_ritual_finished(String(step[0]).trim_prefix("chant:"), 1.0, false)
				else:
					room.spawn_spell(step[0], "directional", player.center() + Vector2(60.0, 0.0), 0.0, {}, player)
			_verdict(room._done.get(k, {}).size() == place["steps"].size(), "and trying its spells marks them done")
	player.global_position = Vector2(ArenaGen.column_x(-5), ArenaGen.surface_y(room._cells, -30))
	for f in 12:
		await get_tree().physics_frame
	var apart := true
	for k in range(1, Tutorial.PLACES.size()):
		apart = apart and Tutorial.PLACES[k]["col"] - Tutorial.PLACES[k - 1]["col"] >= 14
	_verdict(apart, "the places are at least fourteen columns apart")
	var has_chants := Tutorial.PLACES.any(func(p: Dictionary) -> bool: return p["title"] == "Chants")
	_verdict(has_chants, "a place teaches chants")
	for spell: String in ["Ignite", "Frostbolt", "Frost Bridge", "Barrier", "Stonefall", "Liana", "Decoy", "Adrenaline"]:
		_verdict(SpellData.SPELLS.has(spell), "the example spell %s exists" % spell)
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

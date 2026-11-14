extends Node

## The library screen: its ledger line says what was played and won, every page has a card that stays face down until the page has been found or
## its spell cast, and choosing a kind of world shows what was done there. It reads a file of its own, never the real library.
##
##     godot --headless --fixed-fps 60 --path . tests/library_screen_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	Library.force = true
	Library.use_file("user://library_screen_test.json")
	Library.clear()
	var every := Pages.every()
	var screen := await _open()
	_verdict(_figure(screen, "Matches played") == "0" and _figure(screen, "Matches won") == "0", "an empty library has played and won nothing")
	_verdict(_figure(screen, "Pages known") == "0 of %d" % every.size(), "and knows no page (%s)" % _figure(screen, "Pages known"))
	_verdict(_covered(screen) == every.size(), "every page of every tome is blank and torn (%d)" % _covered(screen))
	screen.queue_free()
	# A match, a world, a page, a cast and a win.
	Library.record_match_begun()
	Library.record_world_entered("castle")
	Library.record_page("Ignite")
	Library.record_cast("Frostbolt")
	Library.record_win(["Ignite"])
	screen = await _open()
	_verdict(_figure(screen, "Matches played") == "1" and _figure(screen, "Matches won") == "1", "a match played and won is counted")
	_verdict(_figure(screen, "Pages known") == "2 of %d" % every.size(), "a page found and a spell cast are both counted (%s)" % _figure(screen, "Pages known"))
	_verdict(_covered(screen) == every.size() - 2, "so two pages are no longer blank")
	screen.open_tome("Fire")
	screen.set("_spread", screen.call("_pages_of", "Fire").find("Ignite") / 2)
	screen.call("_show_spread")
	_verdict(_has_text(screen, "Ignite"), "the Fire tome carries Ignite's name")
	screen.open_tome("Water")
	screen.set("_spread", screen.call("_pages_of", "Water").find("Frostbolt") / 2)
	screen.call("_show_spread")
	_verdict(_has_text(screen, "Frostbolt"), "the Water tome carries Frostbolt's name")
	_verdict(_figure(screen, "Title") == "Novice", "a wizard with few casts is a Novice (%s)" % _figure(screen, "Title"))
	screen.open_tome("Water")
	screen.set("_spread", screen.call("_pages_of", "Water").find("Frostbolt") / 2)
	screen.call("_show_spread")
	_verdict(Library.average_accuracy("Frostbolt") < 0.0 and _has_text(screen, "-"), "a cast whose shape could not be judged leaves accuracy blank")
	screen.queue_free()
	# Accuracy is the average of the casts that were judged, shown as a percentage.
	Library.record_cast("Frostbolt", 0.80)
	Library.record_cast("Frostbolt", 0.90)
	Library.record_cast("Frostbolt", 0.0)  # not judged: not in the average
	_verdict(is_equal_approx(Library.average_accuracy("Frostbolt"), 0.85), "accuracy averages the judged casts (%f)" % Library.average_accuracy("Frostbolt"))
	screen = await _open()
	screen.open_tome("Water")
	screen.set("_spread", screen.call("_pages_of", "Water").find("Frostbolt") / 2)
	screen.call("_show_spread")
	_verdict(_has_text(screen, "85%"), "and its page shows it as a percentage")
	_check_titles()
	# Choosing a kind of world shows what was done there.
	screen.open_tome("Fire")
	_choose(screen, "Castle")
	await get_tree().process_frame
	_verdict(_figure(screen, "Matches played here") == "1", "the Castle's counts show the world entered there")
	_choose(screen, "Graveyard")
	await get_tree().process_frame
	_verdict(_figure(screen, "Matches played here") == "0", "and a kind of world never entered shows none")
	screen.set("_spread", screen.call("_pages_of", "Fire").find("Ignite") / 2)
	screen.call("_show_spread")
	await get_tree().create_timer(0.6).timeout
	await _picture("library_book")
	screen.close_tome()
	await _picture("library_shelf")
	screen.close_tome()
	screen.open_tome("chronicle")
	_verdict(_has_text(screen, "Pages known"), "the screen still stands once the tome is shelved again")
	screen.queue_free()
	# The Chronicle: a page for each match that was played to its end, newest first, found pages before blank ones.
	var line: Array = []
	for k in 24:
		line.append(k * 9)
	Library.record_match_end({"when": 1793800000, "place": 3, "field": 4, "seconds": 412, "worlds": ["graveyard", "jungle"], "stages": [["graveyard", 0], ["jungle", 150], ["mountains", 405], ["ashlands", 408], ["castle", 410]], "kills": 1, "dealt": 120, "taken": 260,
		"casts": 40, "misses": 3, "accuracy": 0.81, "pages": 9, "favourites": [["Ignite", 22]], "online": false, "dealt_line": line, "taken_line": line})
	Library.record_match_end({"when": 1793900000, "place": 1, "field": 4, "seconds": 1260, "worlds": ["castle"], "stages": [["castle", 0]], "kills": 3, "dealt": 900, "taken": 300,
		"casts": 150, "misses": 9, "accuracy": 0.9, "pages": 20, "favourites": [["Push", 40], ["Ignite", 30]], "online": true, "dealt_line": line, "taken_line": line})
	screen = await _open()
	screen.open_tome("chronicle")
	_verdict(screen.call("_pages_of", "chronicle").size() == 3, "the Chronicle has its first page and a page for each match (%d)" % screen.call("_pages_of", "chronicle").size())
	screen.set("_spread", 1)
	screen.call("_show_spread")
	_verdict(_has_text(screen, "Victory"), "the newest match, won, comes first")
	screen.set("_spread", 0)
	screen.call("_show_spread")
	_verdict(_has_text(screen, "Best placing") and _has_text(screen, "1st"), "and the first page tells the best placing")
	_choose(screen, "Graveyard")
	_verdict(screen.call("_pages_of", "chronicle").size() == 2, "a world chosen leaves only the matches that went through it")
	_choose(screen, "All")
	await get_tree().create_timer(0.6).timeout
	screen.set("_spread", 1)
	screen.call("_show_spread")
	await _picture("library_chronicle")
	_verdict(Library.stats()["history"].size() == 2, "and the matches are kept in the file")
	screen.queue_free()
	# What was counted under the old name of the Chant of Dowsing is kept under the new, and is not left behind to be read as the Scrying Eye's.
	var old := FileAccess.open("user://library_carry_test.json", FileAccess.WRITE)
	old.store_string(JSON.stringify({"matches": 2, "wins": 0, "pages": {"chant:scrying": 3}, "casts": {"chant:scrying": 5}, "won_with": {},
		"accuracy_sum": {}, "accuracy_n": {}, "in": {"castle": {"worlds": 1, "wins": 0, "pages": {"chant:scrying": 2}, "casts": {}, "won_with": {}}}}))
	old.close()
	Library.use_file("user://library_carry_test.json")
	var carried := Library.stats()
	_verdict(carried["pages"].get("chant:dowsing", 0) == 3 and carried["casts"].get("chant:dowsing", 0) == 5 and not carried["pages"].has("chant:scrying"),
			"counts kept under the old name of the Chant of Dowsing are carried over")
	_verdict(carried["in"]["castle"]["pages"].get("chant:dowsing", 0) == 2, "in every kind of world too")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://library_carry_test.json"))
	Library.use_file("user://library_screen_test.json")
	Library.clear()
	Library.use_file(Library.PATH)
	Library.force = false
	print("the library shows what was done" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## With `-- out=DIR` (and a window), a picture of the screen as it stands.
func _picture(label: String) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			await get_tree().process_frame
			await get_tree().process_frame
			DirAccess.make_dir_recursive_absolute(arg.substr(4))
			get_viewport().get_texture().get_image().save_png("%s/%s.png" % [arg.substr(4), label])


## The title rules, from counts alone. Ignite and Firewall are Fire; Frostbolt and Icicles Water; Push Air; Stonefall Earth; Adrenaline Blood.
func _check_titles() -> void:
	_verdict(Library.title_of({"Ignite": 99}) == "Novice", "99 casts is still a Novice")
	_verdict(Library.title_of({"Ignite": 100}) == "Pyromancer", "100 casts, all fire, is a Pyromancer")
	_verdict(Library.title_of({"Frostbolt": 60, "Icicles": 40}) == "Aquamage", "water casts give a Aquamage")
	_verdict(Library.title_of({"Adrenaline": 100}) == "Necromancer", "blood casts give a Necromancer")
	_verdict(Library.title_of({"Ignite": 50, "Frostbolt": 47, "Push": 3}) == "Sorcerer", "two schools within 5 points are a Sorcerer")
	_verdict(Library.title_of({"Ignite": 52, "Frostbolt": 47, "Push": 1}) == "Sorcerer", "a lead of 5 points is not enough")
	_verdict(Library.title_of({"Ignite": 54, "Frostbolt": 46}) == "Pyromancer", "a lead of 8 points is")
	_verdict(Library.title_of({"Ignite": 20, "Frostbolt": 19, "Push": 19, "Stonefall": 19, "Adrenaline": 19, "Liana": 4}) == "Sorcerer", "no school at 30% is a Sorcerer")
	_verdict(Library.title_of({"Ignite": 100, "chant:haste": 500}) == "Pyromancer", "rituals do not count")
	_verdict(Library.title_of({"Ignite": 30, "chant:haste": 500}) == "Novice", "and are not counted towards the first 100 either")


func _open() -> Node:
	var screen: Node = load("res://scenes/library.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	return screen


## The figure written after a ledger label ("Matches played" then its number), or "" when there is no such label.
func _figure(screen: Node, label: String) -> String:
	screen.open_tome("chronicle")  # the figures are written on the Chronicle's first page
	var found: Array = screen.find_children("*", "Label", true, false)
	for k in found.size():
		if found[k].text == label and k + 1 < found.size():
			return found[k + 1].text
	return ""


## How many pages, over every tome, are blank.
func _covered(screen: Node) -> int:
	var blank := 0
	for tome: String in screen.call("_tomes"):
		screen.open_tome(tome)
		for spread in ceili(screen.call("_pages_of", tome).size() / 2.0):
			screen.set("_spread", spread)
			screen.call("_show_spread")
			blank += screen.find_children("*", "Control", true, false).filter(func(c: Control) -> bool: return c is BlankPage and not c.is_queued_for_deletion()).size()
	screen.close_tome()
	return blank


func _has_text(screen: Node, text: String) -> bool:
	return screen.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == text)


func _choose(screen: Node, words: String) -> void:
	for button: Button in screen.find_children("*", "Button", true, false):
		if button.text == words:
			button.pressed.emit()
			return
	_verdict(false, "there is a choice named %s" % words)


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

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
	_verdict(_covered(screen) == every.size(), "every page has a card, all face down (%d)" % _covered(screen))
	screen.queue_free()
	# A match, a world, a page, a cast and a win.
	Library.record_match_begun()
	Library.record_world_entered("castle")
	Library.record_page("Ignite")
	Library.record_cast("Frostbolt")
	Library.record_win(["Ignite"])
	screen = await _open()
	_verdict(_figure(screen, "Matches played") == "1" and _figure(screen, "Matches won") == "1", "a match played and won is counted")
	_verdict(_figure(screen, "Pages known") == "2 of %d" % every.size(), "a page found and a spell cast each turn a card up (%s)" % _figure(screen, "Pages known"))
	_verdict(_covered(screen) == every.size() - 2, "so two cards are no longer face down")
	_verdict(_has_text(screen, "Ignite") and _has_text(screen, "Frostbolt"), "and those cards carry their spells' names")
	# Choosing a kind of world shows what was done there.
	_choose(screen, "Castle")
	await get_tree().process_frame
	_verdict(_figure(screen, "Worlds entered") == "1", "the Castle's counts show the world entered there")
	_choose(screen, "Graveyard")
	await get_tree().process_frame
	_verdict(_figure(screen, "Worlds entered") == "0", "and a kind of world never entered shows none")
	_choose(screen, "Found")
	await get_tree().process_frame
	_verdict(_has_text(screen, "Pages known"), "the screen still stands after another way of showing is chosen")
	screen.queue_free()
	Library.clear()
	Library.use_file(Library.PATH)
	Library.force = false
	print("the library shows what was done" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _open() -> Node:
	var screen: Node = load("res://scenes/library.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	return screen


## The figure written after a ledger label ("Matches played" then its number), or "" when there is no such label.
func _figure(screen: Node, label: String) -> String:
	var found: Array = screen.find_children("*", "Label", true, false)
	for k in found.size():
		if found[k].text == label and k + 1 < found.size():
			return found[k + 1].text
	return ""


func _covered(screen: Node) -> int:
	return screen.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.text == "?").size()


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

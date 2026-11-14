extends Check
## Plays the cut-scene after a win and checks it: the winner walks in, the book is set on its stand, a second plaque goes up under the first, and
## the scene ends and hands over on time. Pass `-- look=pyre_wizard` for another wizard, or `out=DIR` for pictures (they need a window).
##
##     godot --headless --fixed-fps 60 --path . tests/checks/epilogue_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _scene: Epilogue
var _out := ""
var _look := "wizard"
var _done_at := -1.0
var _clock := 0.0
var _shots := [1.5, 3.3, 3.8, 4.4, 5.1, 5.9, 7.5]
var _checks := {3.0: _check_book_on_its_stand, 4.0: _check_second_plaque, 7.0: _check_words_cut}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.substr(4)
		elif arg.begins_with("look="):
			_look = arg.substr(5)
	_scene = Epilogue.new()
	_scene.next_scene = ""
	_scene.look = _look
	_scene.finished.connect(func() -> void: _done_at = _clock)
	add_child(_scene)


func _process(delta: float) -> void:
	_clock += delta
	for t: float in _checks.keys():
		if _clock >= t:
			_checks[t].call()
			_checks.erase(t)
			break
	if not _shots.is_empty() and _clock >= _shots[0]:
		var at: float = _shots.pop_front()
		if _out != "":
			get_viewport().get_texture().get_image().save_png("%s/epilogue_%04.1f.png" % [_out, at])
	if _done_at >= 0.0 and _clock >= _done_at + 0.2:
		_verdict(absf(_done_at - Epilogue.END) < 0.6, "the scene ends on time (at %.1fs, expected %.1fs)" % [_done_at, Epilogue.END])
		print("%s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
		get_tree().quit(1 if _failures > 0 else 0)
	elif _clock > 20.0:
		_verdict(false, "the scene never ended")
		get_tree().quit(1)


func _check_book_on_its_stand() -> void:
	var books := _scene.find_children("*", "Sprite2D", true, false).filter(func(s: Node) -> bool: return s.texture == Lectern.BOOK)
	_verdict(books.size() == 1 and books[0].visible, "the book is back on its stand (%d books)" % books.size())


func _check_second_plaque() -> void:
	_verdict(_scene.plaque != null, "a second plaque is up")
	_verdict(_scene.plaque != null and _scene.plaque.get_child(0) is Label and (_scene.plaque.get_child(0) as Label).text == Lectern.SECOND_LINES, "and it says what it should")


func _check_words_cut() -> void:
	var words: Label = _scene.plaque.get_child(0)
	_verdict(words.visible_characters == words.text.length(), "the words are cut into it (%d of %d letters)" % [words.visible_characters, words.text.length()])



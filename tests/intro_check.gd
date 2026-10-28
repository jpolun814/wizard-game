extends Node

## Plays the opening cut-scene and checks it: four wizards, a pile of pages that is knocked into the portal, a page kept by each wizard,
## and the hand-over when it ends or is skipped. Pass `-- mode=skip` to press a key part-way through; `out=DIR` saves pictures (they need
## a window, so leave off --headless).
##
##     godot --path . tests/intro_check.tscn -- out=C:/some/dir
##     godot --headless --path . tests/intro_check.tscn -- mode=skip
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _intro: Intro
var _out := ""
var _mode := "full"
var _failures := 0
var _done_at := -1.0
var _clock := 0.0
var _shots := [0.6, 1.6, 3.3, 3.8, 4.3, 5.1, 6.0, 7.2, 8.6, 9.7]
var _checks := {}  # seconds -> Callable


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.substr(4)
		elif arg.begins_with("mode="):
			_mode = arg.substr(5)
	_intro = Intro.new()
	_intro.next_scene = ""
	_intro.finished.connect(func() -> void: _done_at = _clock)
	add_child(_intro)
	_checks = {
		1.5: _check_set,
		3.4: _check_pile_still_there,
		6.2: _check_pile_gone,
		9.75: _check_all_in,
	}
	if _mode == "skip":
		_shots = []
		_checks = {1.5: _check_set}


func _process(delta: float) -> void:
	_clock += delta
	for t in _checks.keys():
		if _clock >= t:
			_checks[t].call()
			_checks.erase(t)
	for t in _shots.duplicate():
		if _clock >= t:
			_shots.erase(t)
			_snap(t)
	if _mode == "skip" and _clock >= 2.0 and not _intro._leaving and _done_at < 0.0 and not has_meta("pressed"):
		set_meta("pressed", true)
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.physical_keycode = KEY_SPACE
		key.pressed = true
		Input.parse_input_event(key)
	if _done_at >= 0.0 and _clock >= _done_at + 0.2:
		_finish()
	elif _clock > 16.0:
		_verdict(false, "the scene never ended")
		_finish()


func _finish() -> void:
	if _mode == "skip":
		_verdict(_done_at > 0.0 and _done_at < 3.0, "a key skips the scene (it ended at %.1fs, the key was pressed at 2.0s)" % _done_at)
	else:
		_verdict(absf(_done_at - Intro.END) < 0.6, "the scene ends on time and hands over (at %.1fs, expected %.1fs)" % [_done_at, Intro.END])
	print("all intro checks passed" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1


func _pages_in_view() -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for child in _intro.get_children():
		if child is Sprite2D and child.texture == Intro.PAGE:
			out.append(child)
	return out


func _check_set() -> void:
	_verdict(_intro._wizards.size() == 4, "four wizards stand in the hall")
	var frames := {}
	for wizard in _intro._wizards:
		var sprite: AnimatedSprite2D = wizard.get_child(0)
		frames[sprite.sprite_frames] = true
		_verdict(sprite.sprite_frames.has_animation(sprite.animation), "wizard animation '%s' exists" % sprite.animation)
	_verdict(frames.size() == 4, "the four wizards each have a look of their own (%d)" % frames.size())
	_verdict(_pages_in_view().size() == Intro.PAGES_IN_PILE, "a pile of %d pages lies on the floor (%d)" % [Intro.PAGES_IN_PILE, _pages_in_view().size()])


func _check_pile_still_there() -> void:
	_verdict(_pages_in_view().size() == Intro.PAGES_IN_PILE, "the pile is untouched until the scuffle (%d pages)" % _pages_in_view().size())
	for wizard in _intro._wizards:
		_verdict(absf(wizard.position.x - Intro.PILE_X) < 100.0, "a wizard has run to the pile (x %.0f)" % wizard.position.x)


func _check_pile_gone() -> void:
	var kept := 0
	for wizard in _intro._wizards:
		for child in wizard.get_children():
			if child is Sprite2D and child.texture == Intro.PAGE:
				kept += 1
	_verdict(kept == Intro.KEPT, "each wizard holds one page (%d held)" % kept)
	_verdict(_pages_in_view().is_empty(), "no loose page is left in the hall once they are through the portal (%d)" % _pages_in_view().size())


func _check_all_in() -> void:
	for wizard in _intro._wizards:
		_verdict(wizard.position.x > Intro.PORTAL_X - 40.0, "a wizard has reached the portal (x %.0f)" % wizard.position.x)


func _snap(t: float) -> void:
	if _out == "":
		return
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	image.save_png("%s/intro_%04.1f.png" % [_out, t])

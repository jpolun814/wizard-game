extends Node

## Plays the opening cut-scene and checks it: four wizards who square up round a pile of pages, shoot each other, have
## every loose page knocked into the portal, and are pulled in after them; and the hand-over when it ends or is skipped. Pass `-- mode=skip` to press a key part-way through; `out=DIR` saves pictures (they need
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
var _shots := [1.0, 2.5, 4.0, 5.0, 5.8, 6.8, 7.6, 8.4, 9.2, 9.8, 10.5, 11.2]
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
		5.2: _check_ring,
		6.2: _check_pile_still_there,
		11.6: _check_pile_gone,
		11.7: _check_all_in,
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
	elif _clock > 18.0:
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


## In the ring: each wizard at their own place, and the pile still on the floor.
func _check_ring() -> void:
	for i in _intro._wizards.size():
		_verdict(absf(_intro._wizards[i].position.x - float(Intro.WIZARDS[i]["to"])) < 6.0, "wizard %d has taken their place in the ring (x %.0f)" % [i, _intro._wizards[i].position.x])
	_verdict(_pages_in_view().size() == Intro.PAGES_IN_PILE, "the pile is untouched until the shooting (%d pages)" % _pages_in_view().size())


func _check_pile_still_there() -> void:
	_verdict(_intro._pile.size() == Intro.PAGES_IN_PILE, "the pile has not gone into the portal yet (%d)" % _intro._pile.size())


func _check_pile_gone() -> void:
	_verdict(_pages_in_view().is_empty(), "no loose page is left in the hall once they have all gone through the portal (%d)" % _pages_in_view().size())


func _check_all_in() -> void:
	for wizard in _intro._wizards:
		_verdict(absf(wizard.position.x - Intro.PORTAL_X) < 60.0 and wizard.position.y < Intro.FLOOR_Y - Intro.PORTAL_HEIGHT + 100.0, "a wizard has been pulled up into the portal (%.0f, %.0f)" % [wizard.position.x, wizard.position.y])


func _snap(t: float) -> void:
	if _out == "":
		return
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	image.save_png("%s/intro_%04.1f.png" % [_out, t])

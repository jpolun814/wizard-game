extends Check
## Plays the opening cut-scene and checks it: the camera runs with the first wizard, ten wizards square up round a pile of pages and fight over it,
## six fall, and the four left are pulled into the tearing portal after the pages; and the hand-over when it ends or is skipped. Pass `-- mode=skip` to press a key part-way through; `out=DIR` saves pictures (they need
## a window, so leave off --headless).
##
##     godot --path . tests/checks/intro_check.tscn -- out=C:/some/dir
##     godot --headless --path . tests/checks/intro_check.tscn -- mode=skip
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _intro: Intro
var _out := ""
var _mode := "full"
var _done_at := -1.0
var _pressed := false  # the key that skips the scene has been pressed
var _clock := 0.0
var _shots := [0.5, 1.4, 2.2, 3.0, 4.2, 5.5, 6.3, 7.8, 8.6, 9.6, 10.4, 11.2]
var _checks := {}  # seconds -> Callable


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.substr(4)
		elif arg.begins_with("mode="):
			_mode = arg.substr(5)
		elif arg.begins_with("look="):
			GameSettings.set_value("look", arg.substr(5))  # the person at this machine has chosen a figure
		elif arg.begins_with("palette="):
			GameSettings.set_value("palette", int(arg.substr(8)))
	_intro = Intro.new()
	_intro.next_scene = ""
	_intro.finished.connect(func() -> void: _done_at = _clock)
	add_child(_intro)
	var first: AnimatedSprite2D = _intro._wizards[0].get_child(0)
	var chosen := Net.look_of(Net.my_id())
	var scale_ok := is_equal_approx(first.scale.x, WizardLook.scale_of(chosen))
	_verdict(scale_ok, "the first wizard is the figure the person chose (%s), drawn at its size" % chosen)
	_verdict(first.material is ShaderMaterial and first.get_parent().get_child_count() > 0, "and it wears the person's colours (a material set from their palette)")
	_checks = {
		1.0: _check_camera_runs_with_the_first,
		1.5: _check_set,
		4.8: _check_ring,
		5.3: _check_camera_shows_the_ring,
		5.3001: _check_pile_still_there,
		7.4: _check_the_six_have_fallen,
		12.5: _check_pile_gone,
		12.7: _check_all_in,
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
	if _mode == "skip" and _clock >= 2.0 and not _intro._leaving and _done_at < 0.0 and not _pressed:
		_pressed = true
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


func _pages_in_view() -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for child in _intro.get_children():
		if child is Sprite2D and child.texture == Intro.PAGE:
			out.append(child)
	return out


func _check_set() -> void:
	_verdict(_intro._wizards.size() == 4 and _intro._extras.size() == 6, "ten wizards are in the hall: four, and six more (%d, %d)" % [_intro._wizards.size(), _intro._extras.size()])
	var frames := {}
	for wizard in _intro._wizards:
		var sprite: AnimatedSprite2D = wizard.get_child(0)
		frames[sprite.sprite_frames] = true
		_verdict(sprite.sprite_frames.has_animation(sprite.animation), "wizard animation '%s' exists" % sprite.animation)
	_verdict(frames.size() == 4, "the four wizards each have a look of their own (%d)" % frames.size())
	var figures := {}
	for wizard in _intro._wizards + _intro._extras:
		var texture: Texture2D = (wizard.get_child(0) as AnimatedSprite2D).sprite_frames.get_frame_texture("idle", 0)
		figures[texture.resource_path] = true
	var seen := 0
	for look: String in WizardLook.LOOKS:
		for path: String in figures:
			if path.begins_with("res://art/chars/" + look + "/") or path.begins_with("res://art/chars/" + look + "_"):
				seen += 1
				break
	_verdict(seen == WizardLook.LOOKS.size(), "all %d figures are among the ten (%d)" % [WizardLook.LOOKS.size(), seen])
	_verdict(_pages_in_view().size() == Intro.PAGES_IN_PILE, "a pile of %d pages lies on the floor (%d)" % [Intro.PAGES_IN_PILE, _pages_in_view().size()])


## The shot opens on the first wizard, running, with the camera beside them.
func _check_camera_runs_with_the_first() -> void:
	var first: Node2D = _intro._wizards[0]
	var sprite: AnimatedSprite2D = first.get_child(0)
	_verdict(sprite.animation == "run", "the first wizard is running (%s)" % sprite.animation)
	_verdict(absf(_intro._camera.position.x - first.position.x) < 200.0 and _intro._camera.zoom.x >= 2.5, "and the camera is close and beside them (%.0f from them, zoom %.1f)" % [_intro._camera.position.x - first.position.x, _intro._camera.zoom.x])


func _check_camera_shows_the_ring() -> void:
	_verdict(_intro._camera.zoom.x < 2.0 and absf(_intro._camera.position.x - Intro.PILE_X) < 60.0, "the camera has pulled back to show the whole ring (zoom %.1f, at %.0f)" % [_intro._camera.zoom.x, _intro._camera.position.x])


func _check_the_six_have_fallen() -> void:
	var down := 0
	for wizard in _intro._extras:
		var sprite: AnimatedSprite2D = wizard.get_child(0)
		if sprite.animation == "death":
			down += 1
	_verdict(down == 6, "all six of the others have fallen (%d)" % down)
	var up := 0
	for wizard in _intro._wizards:
		if wizard.alive:
			up += 1
	_verdict(up == 4, "and the four are still standing (%d)" % up)


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

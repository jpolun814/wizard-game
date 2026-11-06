extends Node

## The settings: the choices are kept and read back, the first screen has a Settings inscription (with a sign) that opens the page, the pause
## screen has one too, and the shake and cut-scene choices are asked. Add `-- out=DIR` for pictures (they need a window).
##
##     godot --headless --fixed-fps 60 --path . tests/settings_check.tscn

var _failures := 0


func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	GameSettings.path = "user://options_test.cfg"
	DirAccess.remove_absolute(GameSettings.path)
	_verdict(not GameSettings.skip_opening() and not GameSettings.skip_ending(), "the defaults: nothing skipped")
	GameSettings.set_value("skip_opening", true)
	GameSettings.set_value("effects", 0.5)
	GameSettings.values = GameSettings.DEFAULTS.duplicate()
	GameSettings.load_saved(true)
	_verdict(GameSettings.skip_opening() and is_equal_approx(float(GameSettings.get_value("effects")), 0.5), "choices come back from the file")
	_verdict(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), linear_to_db(0.5)), "the effects volume reaches its sound bus")
	GameSettings.set_value("frame_cap", 2)
	_verdict(Engine.max_fps == 120, "the frame-rate cap takes hold")
	GameSettings.set_value("frame_cap", 0)

	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	for k in 5:
		await get_tree().process_frame
	var button: Button = menu._options
	_verdict(button != null and menu._signs.has(button) and menu._signs[button] == "gear", "the first screen has a Settings inscription with its own sign")
	var drawn := PackedVector2Array()  # a cog drawn a little crooked, on a bigger scale, is still read as the Settings sign
	for point: Vector2 in menu.SHAPES["gear"]:
		drawn.append(point * 2.5 + Vector2(300.0, 300.0) + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)))
	var result: Dictionary = menu._recognizer.recognize(drawn, ["menu_one", "menu_four", "menu_book", "menu_gear"])
	_verdict(result["name"] == "menu_gear" and result["score"] >= menu.LEAST_SCORE, "a drawn cog is read as the Settings sign (%s, %.2f)" % [result["name"], result["score"]])
	button.pressed.emit()
	for k in 3:
		await get_tree().process_frame
	var panels := menu.find_children("*", "SettingsPanel", true, false)
	_verdict(panels.size() == 1, "it opens the page of settings")
	var toggles := (panels[0] as Node).find_children("*", "CheckButton", true, false) if panels.size() == 1 else []
	_verdict(toggles.size() == 3, "three switches (%d)" % toggles.size())
	if out != "":
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png(out + "/settings_menu.png")
	if panels.size() == 1:
		panels[0].close()
	for k in 3:
		await get_tree().process_frame
	_verdict(menu.find_children("*", "SettingsPanel", true, false).is_empty(), "and closes it again")
	_verdict(not menu._busy, "the book answers again once it is closed")
	menu.queue_free()

	var hud: Node = load("res://scenes/hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	_verdict(hud.get_node_or_null("Pause/Box/Settings") != null, "the pause screen has a Settings button")
	var normal := GameSettings.rival_skill()
	GameSettings.set_value("rival_skill", 0)
	var easy := GameSettings.rival_skill()
	GameSettings.set_value("rival_skill", 2)
	var hard := GameSettings.rival_skill()
	GameSettings.set_value("rival_skill", 1)
	_verdict(easy < normal and normal < hard and is_equal_approx(normal, 0.65), "rival skill: easy %.2f, normal %.2f (as it always was), hard %.2f" % [easy, normal, hard])
	var rival := WizardBrain.new(Wizard.new())
	_verdict(is_equal_approx(rival.skill, 0.65), "an AI wizard plays at the chosen skill (%.2f)" % rival.skill)
	DirAccess.remove_absolute(GameSettings.path)
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _verdict(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1

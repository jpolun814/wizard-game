extends Check
## The first screen is the open spellbook: drawing a sign with the left mouse button held chooses it, as clicking does.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/menu_check.tscn            (add `-- out=DIR` for pictures, needs a window)
## It prints PASS or FAIL for each check and exits with code 1 if any failed.



func _ready() -> void:
	var out := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			out = argument.trim_prefix("out=")
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await _frames(60)
	_verdict(menu._box.visible, "the book opens and its inscriptions are written")
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/menu_main.png")
	var cross: Dictionary = menu._recognizer.recognize(_line([Vector2(300, 250), Vector2(380, 330), Vector2(300, 330), Vector2(380, 250)]), ["menu_quit", "menu_one", "eight_top_cw", "menu_back", "menu_gear", "menu_book"])
	_verdict(cross["name"] == "menu_quit" and cross["score"] >= menu.LEAST_SCORE, "a cross drawn in one stroke reads as the way out (%s, %.2f)" % [cross["name"], cross["score"]])
	menu._show_sign("gear")  # the pointer had last been over the gear
	await _stroke(menu, PackedVector2Array([Vector2(200, 250), Vector2(200, 350), Vector2(200, 450)]))  # one stroke: single player
	_verdict(menu._demo.gesture == "one", "the left page shows the sign that was drawn, not the one that was hovered (%s)" % menu._demo.gesture)
	await _frames(90)
	_verdict(menu._single.visible and not menu._main.visible, "one stroke drawn on the first page turns to single player's")
	if out != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/menu_single.png")
	await _stroke(menu, _circle(Vector2(200, 300), 80.0))  # a circle: Play is an arrow, Tutorial a question mark
	await _frames(30)
	_verdict(menu._single.visible, "a circle drawn there is no sign on that page, so nothing is chosen")
	await _stroke(menu, _line([Vector2(240, 270), Vector2(160, 350), Vector2(240, 430), Vector2(240, 270)]))  # a triangle pointing back: the way back
	await _frames(90)
	_verdict(menu._main.visible and not menu._single.visible, "a triangle pointing back, drawn on single player's page, turns back to the first")
	await _stroke(menu, _moved(GestureTemplates.recognizer_templates()["eight_top_cw"], 2.0, Vector2(400, 400)))  # an 8: multiplayer
	await _frames(90)
	_verdict(menu._multi.visible, "an 8 drawn on the first page turns to multiplayer's")
	if out != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/menu_multi.png")
	await _stroke(menu, _line([Vector2(240, 270), Vector2(160, 350), Vector2(240, 430), Vector2(240, 270)]))
	await _frames(90)
	_verdict(menu._main.visible, "the same triangle turns back from multiplayer's page")
	menu._set_waiting(true)
	_verdict(not menu._multi_back.disabled and menu._joining, "while a join waits, Back is still there to give it up")
	menu._show_page(menu._main, menu._multiplayer, false)
	await _frames(90)
	_verdict(not menu._joining and not menu._join.disabled and Net.online() == false, "going back gives the join up")
	_verdict(menu._tutorial.get_parent() == menu._tutorial.get_parent() and menu._tutorial.is_visible_in_tree(), "the tutorial is on the first page")
	await _stroke(menu, _line([Vector2(200, 250), Vector2(200, 350), Vector2(200, 450)]))
	await _frames(90)
	var two: Dictionary = menu._recognizer.recognize(_line([Vector2(160, 300), Vector2(176, 275), Vector2(200, 265), Vector2(224, 275), Vector2(235, 300), Vector2(224, 325), Vector2(160, 365), Vector2(236, 365)]), ["menu_two", "arrow", "menu_back"])
	_verdict(two["name"] == "menu_two" and two["score"] >= menu.LEAST_SCORE, "a 2 reads as the duel (%s, %.2f)" % [two["name"], two["score"]])
	print("the first screen works" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## A stroke along straight runs between points, with a point every few pixels as a hand makes.
func _line(corners: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in corners.size() - 1:
		for j in 12:
			points.append(corners[k].lerp(corners[k + 1], j / 12.0))
	points.append(corners[corners.size() - 1])
	return points


func _moved(points: PackedVector2Array, scale: float, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		out.append(point * scale + by)
	return out


func _circle(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 41:
		points.append(center + Vector2(cos(k * TAU / 40.0), sin(k * TAU / 40.0)) * radius)
	return points


func _stroke(menu: Control, points: PackedVector2Array) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = points[0]
	menu._input(press)
	for point in points:
		var move := InputEventMouseMotion.new()
		move.position = point
		menu._input(move)
		await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = points[points.size() - 1]
	menu._input(release)


func _frames(count: int) -> void:
	for k in count:
		await get_tree().process_frame

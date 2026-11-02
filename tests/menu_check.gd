extends Node

## The first screen is the open spellbook: drawing a sign with the left mouse button held chooses it, as clicking does.
##
##     godot --headless --fixed-fps 60 --path . tests/menu_check.tscn            (add `-- out=DIR` for pictures, needs a window)
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0


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
	await _stroke(menu, PackedVector2Array([Vector2(200, 250), Vector2(200, 350), Vector2(200, 450)]))  # one stroke: single player
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
	await _stroke(menu, _line([Vector2(260, 430), Vector2(260, 270), Vector2(170, 350), Vector2(280, 350)]))  # a 4: multiplayer
	await _frames(90)
	_verdict(menu._multi.visible, "a 4 drawn on the first page turns to multiplayer's")
	if out != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/menu_multi.png")
	await _stroke(menu, _line([Vector2(240, 270), Vector2(160, 350), Vector2(240, 430), Vector2(240, 270)]))
	await _frames(90)
	_verdict(menu._main.visible, "the same triangle turns back from multiplayer's page")
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


func _circle(centre: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 41:
		points.append(centre + Vector2(cos(k * TAU / 40.0), sin(k * TAU / 40.0)) * radius)
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


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

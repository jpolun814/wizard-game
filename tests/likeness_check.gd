extends Node

## The wizard maker: the words at the spot on the hill open it, a figure and a set of colours chosen in it are worn at once and kept, the four figures
## are one height, and a brain's wizard takes a figure nobody else has. Add `-- out=DIR` for pictures (they need a window).
##
##     godot --headless --fixed-fps 60 --path . tests/likeness_check.tscn

var _failures := 0


func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	GameSettings.path = "user://options_test.cfg"
	DirAccess.remove_absolute(GameSettings.path)
	GameSettings.values = GameSettings.DEFAULTS.duplicate()

	for look: String in WizardLook.LOOKS:  # head to toe, the same for all: the top of the head over the middle of the frame
		var image: Image = (load("res://art/chars/%s/idle_0.png" % look) as Texture2D).get_image()
		var top := 0
		for y in image.get_height():
			var found := false
			for x in range(image.get_width() / 2 - 4, image.get_width() / 2 + 5):
				if image.get_pixel(x, y).a > 0.5:
					found = true
					break
			if found:
				top = image.get_height() - y
				break
		var high := float(top) * WizardLook.scale_of(look)
		_verdict(absf(high - 79.0) <= 4.0, "%s stands %.0f from feet to head (79 is the mark)" % [look, high])

	_verdict(Net.rival_look(1) != Net.look_of(Net.my_id()) and Net.rival_look(2) != Net.look_of(Net.my_id()) and Net.rival_look(3) != Net.look_of(Net.my_id()), "no brain wears the figure the person plays")
	GameSettings.set_value("look", "bone_wizard")
	var rivals := [Net.rival_look(1), Net.rival_look(2), Net.rival_look(3)]
	_verdict(not rivals.has("bone_wizard") and rivals.size() == 3 and rivals[0] != rivals[1] and rivals[1] != rivals[2], "and with another chosen they still share none (%s)" % str(rivals))
	GameSettings.set_value("look", "")

	var lab: Lab = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 10:
		await get_tree().process_frame
	var marks := lab.find_children("*", "LikenessMark", true, false)
	_verdict(marks.size() == 1, "the waiting room has the magic mirror (%d)" % marks.size())
	_verdict(lab.ritual.likeness_listens, "and the ritual box listens for its words")
	lab.ritual.likeness_spoken.emit()
	for k in 3:
		await get_tree().process_frame
	var panels := lab.find_children("*", "LikenessPanel", true, false)
	_verdict(panels.size() == 1, "the words open the wizard maker (anywhere in the room)")
	await get_tree().process_frame
	_verdict(lab.player.movement_enabled and not lab.ritual.visible, "and the person can still walk about while it is open")
	var plate: Rect2 = lab._visible_hud_rects().back()
	_verdict(plate.size.x > 100.0 and plate.size.y > 100.0, "though a stroke that starts on its plate is not a spell (%s)" % str(plate))
	if panels.size() == 1:
		panels[0]._choose_look("pyre_wizard")
		panels[0]._choose_palette(2)
		_verdict(lab.player.look == "pyre_wizard" and lab.player.palette == 2, "a figure and colours chosen are worn at once")
		_verdict(GameSettings.get_value("look") == "pyre_wizard" and int(GameSettings.get_value("palette")) == 2, "and kept")
		for k in 3:
			await get_tree().process_frame
		if out != "":
			await get_tree().create_timer(0.5).timeout
			get_viewport().get_texture().get_image().save_png(out + "/likeness_maker.png")
		panels[0].close()
	for k in 3:
		await get_tree().process_frame
	_verdict(lab._making == null, "closing it puts the plate away")
	var spot: Node2D = marks[0]  # standing on the circle, on top of the floating slab, brings up the page with the words; leaving it takes the page away
	_verdict(lab.find_children("*", "LikenessGuide", true, false).is_empty(), "no page with the words while the player is away from the circle")
	lab.player.global_position = spot.global_position + Vector2(0.0, -2.0)  # standing on the slab, under the circle
	lab.player.velocity = Vector2.ZERO
	for k in 5:
		await get_tree().physics_frame
	_verdict(lab.find_children("*", "LikenessGuide", true, false).size() == 1, "the page with the words comes up on the circle")
	if out != "":
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png(out + "/likeness_spot.png")
	lab.player.global_position = spot.global_position + Vector2(90.0, -2.0)  # a few steps off the slab
	for k in 5:
		await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_verdict(lab.find_children("*", "LikenessGuide", true, false).is_empty(), "a few steps from the circle is too far for the page")
	lab.player.global_position = spot.global_position + Vector2(0.0, -2.0)
	for k in 5:
		await get_tree().physics_frame
	lab.player.global_position = spot.global_position + Vector2(600.0, 0.0)
	for k in 5:
		await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_verdict(lab.find_children("*", "LikenessGuide", true, false).is_empty(), "and goes when the player leaves it")
	lab.queue_free()
	await get_tree().process_frame

	var next: Lab = load("res://scenes/lab.tscn").instantiate()  # the next visit: they are still who they chose to be
	add_child(next)
	for k in 5:
		await get_tree().process_frame
	_verdict(next.player.look == "pyre_wizard" and next.player.palette == 2, "the next visit has them as they chose")
	DirAccess.remove_absolute(GameSettings.path)
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _verdict(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1

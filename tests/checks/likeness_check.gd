extends Check
## The wizard maker: the words at the spot on the hill open it, the parts chosen in it are worn at once and kept, and a brain's wizard is made of parts nobody wears. Add `-- out=DIR` for pictures (they need a window).
##
##     godot --headless --fixed-fps 60 --path . tests/checks/likeness_check.tscn



func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	GameSettings.path = "user://options_test.cfg"
	DirAccess.remove_absolute(GameSettings.path)
	GameSettings.values = GameSettings.DEFAULTS.duplicate()

	var mine := Net.look_of(Net.my_id())
	_verdict(mine == PartsLook.default_look(), "a person who has not made a wizard yet wears the starting one")
	var image: Image = PartFrames.body(mine).get_frame_texture("idle", 0).get_image()
	var lowest := 0
	for y in image.get_height():
		for x in range(image.get_width() / 2 - 20, image.get_width() / 2 + 20):  # the boots, in the middle of the frame
			if image.get_pixel(x, y).a > 0.5:
				lowest = y
	var boots := PartFrames.OFFSET.y - float(image.get_height()) * 0.5 + float(lowest + 1)  # where the soles are, from the feet of the wizard (they must be at 0)
	_verdict(is_zero_approx(boots), "and its boots stand on the ground, not over it or in it (%.0f px off)" % boots)
	_verdict(Sfx.has_sound(WizardLook.jump_sound(mine)), "and it has a jump sound (%s)" % WizardLook.jump_sound(mine))
	var rivals := [Net.rival_look(1), Net.rival_look(2), Net.rival_look(3), Net.rival_look(4)]
	_verdict(rivals.all(func(look: String) -> bool: return PartsLook.is_valid(look) and look != mine) and rivals.size() == 4 and rivals[0] != rivals[1] and rivals[1] != rivals[2] and rivals[2] != rivals[3], "each brain's wizard is made of parts, and none wears the person's (%s)" % str(rivals))
	GameSettings.set_value("look", rivals[0])
	_verdict(Net.rival_look(1) != rivals[0], "and with another look chosen, a brain made the same is made again")
	GameSettings.set_value("look", "pyre_wizard")
	_verdict(Net.look_of(Net.my_id()) == PartsLook.default_look(), "a look saved by an older game (a found figure) is not worn")
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
		var panel: LikenessPanel = panels[0]
		panel._choose("hat", "hood")
		panel._choose("weapon", "wand")
		_verdict(lab.player.look == "parts:3:tan.coat.blue.gold.short.auburn.short.auburn.hood.blue.brown.wand.voice_1", "parts chosen are worn at once (%s)" % lab.player.look)
		_verdict(GameSettings.get_value("look") == lab.player.look, "and kept")
		panel._choose("color", "crimson")
		panel._choose("hair_color", "black")
		_verdict(PartsLook.option_of(lab.player.look, "hat_color") == "crimson" and PartsLook.option_of(lab.player.look, "beard_color") == "black", "the hat takes the robe's color and the beard the hair's")
		_verdict(PartsLook.option_of(PartsLook.seeded_look(5), "hat_color") == PartsLook.option_of(PartsLook.seeded_look(5), "color"), "and so does a wizard made at random")
		panel._step("skin", 1)
		_verdict(PartsLook.option_of(lab.player.look, "skin") == "bronze", "an arrow goes to the next (tan, then bronze)")
		panel._choose("skin", "pale")
		panel._step("skin", -1)
		_verdict(PartsLook.option_of(lab.player.look, "skin") == "bone", "and the one before the first is the last (round the list)")
		panel._randomize()
		_verdict(PartsLook.is_valid(lab.player.look) and Net.look_of(Net.my_id()) == lab.player.look, "Random makes a wizard of parts, worn at once")
		panel._choose("hat", "hood")
		panel._choose("weapon", "wand")
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
	_verdict(next.player.look == Net.look_of(Net.my_id()) and next.player.look == GameSettings.get_value("look") and PartsLook.option_of(next.player.look, "hat") == "hood", "the next visit has them as they chose")
	DirAccess.remove_absolute(GameSettings.path)
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)



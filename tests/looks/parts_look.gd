extends Node2D

## Pictures of the character creator's wizards, made through the game's own code. Needs a window:
##   godot --path . tests/looks/parts_look.tscn -- out=DIR [scenario=lineup|anims|magic]
## lineup: twelve made-up wizards at twice their size, each with the glow of a different school. anims: every animation of the starting wizard, one frame each, named.
## magic: one wizard drawing, with each of the seven schools in turn.

func _ready() -> void:
	var out := ""
	var scenario := "lineup"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
		elif arg.begins_with("scenario="):
			scenario = arg.substr(9)
	var port := SubViewport.new()
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	port.transparent_bg = false
	add_child(port)
	var back := ColorRect.new()
	back.color = Color(0.2, 0.18, 0.28)
	port.add_child(back)
	match scenario:
		"anims":
			_anims(port, back)
		"magic":
			_magic(port, back)
		"memory":
			await _memory()
		_:
			_lineup(port, back)
	for k in 8:
		await get_tree().process_frame
	if out != "":
		port.get_texture().get_image().save_png(out + "/parts_" + scenario + ".png")
	get_tree().quit()


func _figure(parent: Node, look: String, at: Vector2, scale: float, school: String, anim := "idle", frame := -1) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	var frames := PartFrames.body(look)
	PartFrames.ensure(frames, anim)
	sprite.sprite_frames = frames
	sprite.offset = PartFrames.OFFSET
	sprite.position = at
	sprite.scale = Vector2.ONE * scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sprite)
	sprite.play(anim)
	if frame >= 0:
		sprite.pause()
		sprite.frame = frame
	var magic := MagicLayer.new()
	magic.attach(sprite, PartsLook.option_of(look, "weapon"))
	magic.paint(SpellData.SCHOOL_COLORS[school])
	magic.position = at
	magic.scale = Vector2.ONE * scale
	magic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(magic)
	return sprite


func _lineup(port: SubViewport, back: ColorRect) -> void:
	port.size = Vector2i(1560, 560)
	back.size = Vector2(port.size)
	var schools := SpellData.SCHOOL_COLORS.keys()
	for k in 12:
		var look := PartsLook.default_look() if k == 0 else PartsLook.seeded_look(40 + k)
		_figure(port, look, Vector2(130.0 + (k % 6) * 260.0, 270.0 + (k / 6) * 270.0), 2.0, schools[k % schools.size()])


func _anims(port: SubViewport, back: ColorRect) -> void:
	var names: Array = PartFrames.manifest()["animations"].keys()
	var columns := 12
	var rows := ceili(names.size() / float(columns))
	port.size = Vector2i(columns * 150, rows * 150)
	back.size = Vector2(port.size)
	var look := PartsLook.default_look()
	for k in names.size():
		var anim: String = names[k]
		var count: int = PartFrames.manifest()["animations"][anim]["count"]
		var at := Vector2(75.0 + (k % columns) * 150.0, 125.0 + (k / columns) * 150.0)
		_figure(port, look, at, 1.0, "Fire", anim, count / 2)
		var label := Label.new()
		label.text = anim
		label.position = at + Vector2(-70.0, -118.0)
		label.add_theme_font_size_override("font_size", 12)
		port.add_child(label)


func _magic(port: SubViewport, back: ColorRect) -> void:
	port.size = Vector2i(1400, 330)
	back.size = Vector2(port.size)
	var schools := SpellData.SCHOOL_COLORS.keys()
	for k in schools.size():
		_figure(port, PartsLook.default_look(), Vector2(100.0 + k * 195.0, 260.0), 2.0, schools[k], "cast", 3)


## What eight wizards cost: the first made all the way (the one the person plays), the other seven as a match has them (only the animations they have played, the
## common ones), and then one more animation each, as a match does in the first minutes. Printed: texture memory and the time each step took.
func _memory() -> void:
	await get_tree().process_frame
	var before := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	var held: Array[SpriteFrames] = []
	var started := Time.get_ticks_usec()
	for k in 8:
		var look := PartsLook.seeded_look(300 + k)
		var frames := PartFrames.body(look)
		held.append(frames)
		held.append(PartFrames.magic(PartsLook.option_of(look, "weapon")))
		if k == 0:
			while PartFrames.warm_next(frames):
				pass
			while PartFrames.warm_next(held[1]):
				pass
	var built := (Time.get_ticks_usec() - started) / 1000.0
	await get_tree().process_frame
	var after := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	print("MEMORY eight wizards, one of them whole: %.0f MB of textures (was %.0f), made in %.0f ms" % [after - before, before, built])
	var each := 0.0
	var slowest := 0.0
	for k in 7:
		var t := Time.get_ticks_usec()
		PartFrames.ensure(held[(k + 1) * 2], "cower")
		var took := (Time.get_ticks_usec() - t) / 1000.0
		each += took
		slowest = maxf(slowest, took)
	print("MEMORY one more animation (cower) for each of the other seven: %.1f ms each, slowest %.1f ms" % [each / 7.0, slowest])
	var whole := held[0]
	print("MEMORY the whole wizard: %d animations" % whole.get_animation_names().size())

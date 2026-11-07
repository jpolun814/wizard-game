extends Node2D

## Pictures of the three figures in every set of colours, side by side, drawn at the sizes the game draws them (a line marks the height of the head).
## Needs a window:   godot --path . tests/look_palettes.tscn -- out=DIR

func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	var cam := Camera2D.new()
	cam.position = Vector2(640, 360)
	add_child(cam)
	var back := ColorRect.new()
	back.color = Color(0.2, 0.18, 0.28)
	back.size = Vector2(1280, 720)
	back.z_index = -10
	add_child(back)
	var line := ColorRect.new()
	line.color = Color(1, 1, 0, 0.5)
	line.position = Vector2(0, 700.0 - 79.0 * 1.0)
	line.size = Vector2(1280, 1)
	add_child(line)
	for row in WizardLook.LOOKS.size():
		var look: String = WizardLook.LOOKS[row]
		for palette in WizardLook.PALETTES.size():
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = CharFrames.build("res://art/chars/" + look, Wizard.animations_for(look))
			sprite.offset = Vector2(0, -PixelArt.CHARACTERS[look]["size"].y * 0.5)
			sprite.scale = Vector2.ONE * WizardLook.scale_of(look)
			sprite.material = WizardLook.material_for(look, palette)
			sprite.position = Vector2(80.0 + palette * 150.0, 160.0 + row * 170.0)
			sprite.play("idle")
			add_child(sprite)
	for k in 6:
		await get_tree().process_frame
	if out != "":
		get_viewport().get_texture().get_image().save_png(out + "/look_palettes.png")
	get_tree().quit()

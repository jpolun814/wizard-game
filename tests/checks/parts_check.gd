extends Check
## The character creator's parts: every packed layer is there, every choice finds its layers, a stack of them is pixel for pixel the one the art was
## made with, a look survives being written down, every animation is made with its frame count, and how long and how much that takes.
##
##     godot --headless --path . tests/checks/parts_check.tscn


func _ready() -> void:
	var m := PartFrames.manifest()
	var missing := 0
	var files := 0
	for slot: Dictionary in m["slots"]:
		for variant: String in slot["variants"]:
			files += 1
			if not FileAccess.file_exists("res://art/parts/%s/%s.parts" % [slot["name"], variant]):
				missing += 1
	_verdict(missing == 0 and files > 203, "all %d packed layers are there (%d missing)" % [files, missing])

	# Every value of every option, one at a time over the default, finds a file or a documented gap.
	var gaps := 0
	var wrong := 0
	for option: String in PartsLook.ORDER:
		for value: String in PartsLook.options_of_all()[option]:
			var config := PartsLook.default_config()
			config[option] = value
			for slot: Dictionary in m["slots"]:
				var path := PartFrames.layer_path(slot, config)
				if path == "":
					gaps += 1
					var empty_ok := _gap_is_meant(slot["name"], config)
					if not empty_ok:
						wrong += 1
						print("   no layer for %s with %s=%s" % [slot["name"], option, value])
				elif not FileAccess.file_exists(path):
					wrong += 1
	_verdict(wrong == 0, "every choice of every option finds its layers or draws nothing where that is meant (%d gaps, %d wrong)" % [gaps, wrong])

	# The default look, stacked, against the frames the art was made with.
	var config := PartsLook.default_config()
	var look := PartsLook.encode(config)
	var reference := Image.load_from_file("res://art_source/parts_sheets/reference/test_character_sheet.png")
	reference.convert(Image.FORMAT_RGBA8)
	var body := PartFrames.body(look)
	var glow := PartFrames.magic(config["weapon"])
	var ramp: Array = m["magic"]["example_spells"]["Fire"]
	var worst := 0
	var off := 0
	var tested := 0
	for anim: String in ["idle", "run", "cast", "release", "death", "swim", "climb", "dazed", "vanish", "victory"]:
		_verdict(PartFrames.ensure(body, anim) and PartFrames.ensure(glow, anim), "%s can be made" % anim)
		var spec: Dictionary = m["animations"][anim]
		for k in int(spec["count"]):
			var made := _flat(body.get_frame_texture(anim, k), glow.get_frame_texture(anim, k), ramp)
			var frame: int = int(spec["start"]) + k
			var want := reference.get_region(Rect2i((frame % 9) * 254, (frame / 9) * 138, 254, 138))
			for y in 138:
				for x in 254:
					var a := made.get_pixel(x, y)
					var b := want.get_pixel(x, y)
					var diff := maxi(maxi(absi(roundi((a.r - b.r) * 255.0)), absi(roundi((a.g - b.g) * 255.0))), maxi(absi(roundi((a.b - b.b) * 255.0)), absi(roundi((a.a - b.a) * 255.0))))
					worst = maxi(worst, diff)
					if diff > 2:
						off += 1
			tested += 1
	_verdict(off == 0, "%d frames of ten animations match the reference sheet (%d pixels differ by more than 2, worst %d)" % [tested, off, worst])

	# Looks written down and read back.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var same := 0
	for k in 200:
		var c := PartsLook.random_config(rng)
		if PartsLook.decode(PartsLook.encode(c)) == c:
			same += 1
	_verdict(same == 200, "200 random looks are read back as they were written (%d)" % same)
	_verdict(PartsLook.decode("").is_empty() and PartsLook.decode("wizard").is_empty() and PartsLook.decode("parts:1:tan.coat").is_empty() and PartsLook.decode("parts:1:tan.coat.blue.short.auburn.short.auburn.wide.blue.cannon").is_empty() and PartsLook.decode("parts:3:tan.coat.blue.short.auburn.short.auburn.wide.blue.staff_orb.voice_1").is_empty() and not PartsLook.decode("parts:1:tan.coat.blue.short.auburn.short.auburn.wide.blue.staff_orb").is_empty(), "garbage is read as no look")
	var old := PartsLook.decode("parts:2:tan.coat.charcoal.long.auburn.long.gray.wide.blue.staff_orb.voice_2")
	_verdict(old.get("trim") == "ivory" and old.get("boots") == "brown" and old.get("beard") == "long" and old.get("voice") == "voice_2" and PartsLook.decode("parts:1:tan.coat.blue.short.auburn.short.auburn.wide.blue.staff_orb")["trim"] == "gold", "a look from an older game is read with the trim and boots it was drawn with, and a beard that is gone as the one like it")
	var silent: Array[String] = []
	for voice: String in PartsLook.VOICES:
		var made := PartsLook.with_option(PartsLook.DEFAULT_LOOK, "voice", voice)
		for sound: String in [WizardLook.jump_sound(made), WizardLook.hurt_sound(made)]:
			if not Sfx.has_sound(sound):
				silent.append(voice + ": " + sound)
	_verdict(silent.is_empty(), "every voice has a jump and a hurt sound (missing: %s)" % str(silent))
	Sfx.speak(self, "jump_voice_5", Vector2.ZERO)
	Sfx.speak(self, "hurt_voice_5", Vector2.ZERO)
	var sounding := 0
	for child in Sfx.get_children():
		if child is AudioStreamPlayer2D and child.playing:
			sounding += 1
	_verdict(sounding == 1, "a voice never speaks over itself: a new sound cuts the one before (%d sounding)" % sounding)
	Sfx.speak(self, "hurt_voice_5", Vector2.ZERO)
	var first: Node = Sfx._voices.get(get_instance_id())
	Sfx.speak(self, "hurt_voice_5", Vector2.ZERO)
	_verdict(Sfx._voices.get(get_instance_id()) == first and first.playing, "the same sound asked for again carries on, it is not restarted")
	_verdict(PartsLook.is_valid(look) and not PartsLook.is_valid("parts:2:x.x.x.x.x.x.x.x.x.x.x"), "a look is valid only if every value is a part")
	_verdict(WizardLook.is_look(look) and not WizardLook.is_look("pyre_wizard") and not WizardLook.is_look("garbage"), "the game takes a look made of parts, and not the old figures")

	# Every animation of the manifest, with its frames.
	var every := PartFrames.body(look)
	var bad := 0
	var started := Time.get_ticks_usec()
	var slowest := 0.0
	var slowest_name := ""
	for anim: String in m["animations"]:
		PartFrames.ensure(every, anim)
		if PartFrames._last_ms > slowest and every.get_frame_count(anim) > 0:
			slowest = PartFrames._last_ms
			slowest_name = anim
		var spec: Dictionary = m["animations"][anim]
		if every.get_frame_count(anim) != int(spec["count"]) or not is_equal_approx(every.get_animation_speed(anim), float(spec["fps"])) or every.get_animation_loop(anim) != bool(spec["loop"]):
			bad += 1
	_verdict(bad == 0 and every.get_animation_names().size() == 48, "all 48 animations are there with the manifest's frames, speed and looping (%d wrong)" % bad)
	print("   (all of them made in %.0f ms; the slowest single one was %s, %.1f ms)" % [(Time.get_ticks_usec() - started) / 1000.0, slowest_name, slowest])

	# What a new look costs: its core animations, and what one more animation costs.
	var costs := PackedFloat64Array()
	for k in 5:
		var other := PartsLook.seeded_look(100 + k)
		var t0 := Time.get_ticks_usec()
		var frames := PartFrames.body(other)
		costs.append((Time.get_ticks_usec() - t0) / 1000.0)
		PartFrames.ensure(frames, "cower")
		print("   a new look: %.0f ms with its first fourteen animations; one more (cower): %.1f ms" % [costs[k], PartFrames._last_ms])
	var memory := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	print("   texture memory now: %.0f MB (the look and 5 more, all 48 animations of the first)" % memory)

	print("parts_check: ", "PASSED" if _failures == 0 else "FAILED (%d)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## A frame of the body with the magic over it, recolored with a ramp, as the art session's reference has it.
func _flat(body: Texture2D, glow: Texture2D, ramp: Array) -> Image:
	var image := body.get_image()
	var magic := glow.get_image()
	for y in magic.get_height():
		for x in magic.get_width():
			var p := magic.get_pixel(x, y)
			if p.a <= 0.0:
				continue
			var g := int(round(p.r * 255.0))
			var rgb: Array = [255, 255, 255] if g >= 247 else ramp[0] if g >= 213 else ramp[1] if g >= 159 else ramp[2] if g >= 99 else ramp[3]
			magic.set_pixel(x, y, Color(rgb[0] / 255.0, rgb[1] / 255.0, rgb[2] / 255.0, p.a))
	image.blend_rect(magic, Rect2i(Vector2i.ZERO, magic.get_size()), Vector2i.ZERO)
	return image


## Where a slot is meant to draw nothing for a choice of parts (a bare arm for an outfit with sleeves, a cuff for one without).
func _gap_is_meant(slot: String, config: Dictionary) -> bool:
	var sleeveless: bool = ["vest", "pelt", "sash", "toga"].has(config["outfit"])
	var bare_legs: bool = ["pelt", "toga"].has(config["outfit"])
	match slot:
		"far_sleeve", "near_sleeve", "far_cuff", "near_cuff":
			return sleeveless
		"far_arm", "near_arm", "torso_skin":
			return not sleeveless
		"far_leg", "near_leg":
			return bare_legs
		"far_bare_leg", "near_bare_leg":
			return not bare_legs
		"back_coat":
			return not ["cloak", "gothic"].has(config["outfit"])  # (a coat's flaps are all in the trim's color)
		"back_trim":
			return not ["coat", "cloak", "gothic"].has(config["outfit"])
		"front_coat":
			return ["coat", "cloak", "gothic", "vest", "sash"].has(config["outfit"])
		"belt":
			return ["rags", "tunic", "bodice", "sash", "toga"].has(config["outfit"])  # (their belts are cloth in the trim's color)
		"hat":
			return config["hat"] == "none"
		"hat_trim":
			return not ["circlet", "tiara", "crown", "horned", "headscarf", "pointy", "wide"].has(config["hat"])
		"beard":
			return config["beard"] == "none"
		"hair_back":
			return ["none", "short", "mohawk"].has(config["hair"])
		"hair_front":
			return config["hair"] == "none"
		"body_trim":
			return false
	return false

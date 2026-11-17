extends Check
## A wizard made of parts has 46 animations, and which it plays is read off its body: this puts the body in each state in turn (running, frozen, swimming, shoved, a spell
## going off...) and sees which animation is playing, that the layer of magic over it keeps to the body's animation and frame, and that the gem takes the spell's color.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/pose_check.tscn

var _lab: Lab
var _player: Wizard


func _ready() -> void:
	GameSettings.path = "user://options_test.cfg"
	DirAccess.remove_absolute(GameSettings.path)
	GameSettings.values = GameSettings.DEFAULTS.duplicate()
	_lab = load("res://scenes/lab.tscn").instantiate()
	add_child(_lab)
	for k in 30:
		await get_tree().physics_frame
	_player = _lab.player
	_verdict(PartsLook.is_parts(_player.look), "the wizard is made of parts (%s)" % _player.look)
	_player.global_position += Vector2(0.0, -4.0)
	await _frames(40)
	await _expect("idle", "standing still", func() -> void: pass)
	await _expect("run", "running", func() -> void: Input.action_press("move_right"), 8)
	Input.action_release("move_right")
	await _expect("walk", "walking slowly (slowed)", func() -> void:
		_player.slow_time = 2.0
		Input.action_press("move_right"), 8)
	Input.action_release("move_right")
	_player.slow_time = 0.0
	await _frames(20)
	_player.casting = true  # (the arena says each frame whether a stroke is being drawn: so this asks the body directly)
	_verdict(_player.pose.pick(0.016) == "cast", "drawing a spell plays cast")
	_player.casting = false
	await _frames(30)
	await _expect("hit", "hurt", func() -> void: _player.take_damage(1), 2)
	await _frames(40)
	await _expect("cower", "afraid", func() -> void: _player.fear_time = 1.0, 3)
	_player.fear_time = 0.0
	await _expect("dazed", "dazed", func() -> void: _player.apply_debuff("daze", 1.0), 3)
	_player.daze_time = 0.0
	_player.slow_time = 0.0
	await _frames(20)
	await _expect("gasping", "with the air drawn out of the lungs", func() -> void: _player.lungs.smothered = true, 3)
	_player.lungs.smothered = false
	await _expect("rocket", "on a rocket", func() -> void: _player.rocket_time = 0.4, 3)
	_player.rocket_time = 0.0
	await _frames(30)
	await _expect("surf", "on a wave", func() -> void: _player.start_surf(1.0, 0.3), 3)
	_player.surf_time = 0.0
	await _frames(30)
	var before := String(_player.shown_anim)
	var frame_before := (_player.get_node("Look") as AnimatedSprite2D).frame
	await _expect(before, "in ice (held on the pose it was caught in)", func() -> void: _player.freeze(2.0), 3)
	_verdict((_player.get_node("Look") as AnimatedSprite2D).speed_scale == 0.0, "and the picture does not move in the ice (frame %d, was %d)" % [(_player.get_node("Look") as AnimatedSprite2D).frame, frame_before])
	_player.thaw()
	_player.root_time = 0.0
	await _frames(2)
	_verdict(String(_player.shown_anim) == "thaw", "and the ice breaking is a thaw (%s)" % _player.shown_anim)
	await _frames(40)
	await _expect("pulled", "pulled along the ground", func() -> void: _player.pull(Vector2(60.0, 0.0), 0.016), 3, true)
	await _frames(30)
	await _expect("stuck", "caught in thorns and trying to go on", func() -> void:
		_player.tangle_time = 1.0
		Input.action_press("move_right"), 6)
	Input.action_release("move_right")
	_player.tangle_time = 0.0
	await _frames(20)

	# In the air, and what takes it there.
	await _expect("jump", "going up", func() -> void:
		_player.global_position += Vector2(0.0, -60.0)  # (off the floor, which holds a body that is on it)
		_player.velocity.y = -300.0, 2)

	await _frames(40)
	await _expect("float", "falling under a Featherfall", func() -> void:
		_player.global_position += Vector2(0.0, -200.0)
		_player.feather_time = 2.0
		_player.velocity.y = 40.0, 6)
	_player.feather_time = 0.0
	await _frames(60)
	await _expect("knockback", "thrown", func() -> void: _player.push(Vector2(-500.0, -420.0)), 3)
	_verdict(_player.look_dir > 0.0, "and turned to face what threw them (they were thrown to the left)")
	await _frames(80)
	_verdict(["get_up", "idle"].has(String(_player.shown_anim)), "and they get up from it (%s)" % _player.shown_anim)
	await _frames(40)
	_player.flying = true
	await _expect("float", "flying and still", func() -> void: pass, 3)
	await _expect("fly", "flying and moving", func() -> void: Input.action_press("move_right"), 6)
	Input.action_release("move_right")
	_player.flying = false
	await _frames(80)
	_player.swim_time = 0.0
	await _expect("swim", "out of its depth", func() -> void: _player.swim(), 3, true)
	await _frames(60)

	# Asked of the body directly, for what is hard to arrange in a room: a vine, a dive, a hard landing, a fall after being thrown.
	var vine := Node2D.new()
	_player.vine._vine = vine
	_verdict(_player.pose.pick(0.016) == "climb_hang", "hanging on a vine plays climb_hang")
	_player.vine._moved = 0.1
	_verdict(_player.pose.pick(0.016) == "climb", "climbing it plays climb")
	_player.vine._vine = null
	vine.free()
	_player.swim_time = 1.0
	Input.action_press("move_down")
	_verdict(_player.pose.pick(0.016) == "swim_dive", "swimming down plays swim_dive")
	Input.action_release("move_down")
	_player.swim_time = 0.0
	_player.pose._was_floor = false
	_player.pose._fall_speed = 600.0
	_player.pose.tick(0.016)
	_verdict(_player.pose.pick(0.016) == "land", "landing hard from a fall plays land")
	_player.pose._low_left = 0.0
	_player.pose._was_floor = false
	_player.pose._knock_air = 0.6
	_player.pose.tick(0.016)
	_verdict(_player.pose.pick(0.016) == "get_up", "landing from being thrown plays get_up")
	_player.pose._low_left = 0.0
	await _frames(20)

	# The other animations that are only seen at one moment.
	_player.pose.arrive()
	await _frames(2)
	_verdict(String(_player.shown_anim) == "spawn", "arriving out of the circle is a spawn (%s)" % _player.shown_anim)
	await _frames(50)
	_player.celebrate()
	await _frames(2)
	_verdict(String(_player.shown_anim) == "victory", "winning is a victory (%s)" % _player.shown_anim)
	await _frames(70)
	_player.facing = -_player.facing
	await _frames(3)
	_verdict(String(_player.shown_anim) == "turn", "turning round on the spot is a turn (%s)" % _player.shown_anim)
	await _frames(30)
	_player.pose._fidget_at = 0.05
	await _frames(12)
	_verdict(String(_player.shown_anim) == "idle_fidget", "standing a long while is a fidget (%s)" % _player.shown_anim)
	await _frames(90)
	_player.fainted = true
	_player.infinite_time = 0.0  # (the waiting room gives endless stamina, and it stands up again once the stamina is back)
	_player.stamina = 0.0
	await _frames(3)
	_verdict(String(_player.shown_anim) == "death", "a wizard who has fainted is lying down (death) (%s)" % _player.shown_anim)
	_player.fainted = false
	await _frames(3)
	_verdict(String(_player.shown_anim) == "wake", "and waking is a wake (%s)" % _player.shown_anim)
	await _frames(70)

	# Every spell that has a style of its own plays it.
	var wrong := 0
	for spell: String in CastStyles.STYLES:
		var want: String = CastStyles.STYLES[spell]
		if want == "rocket":
			continue
		_player.casting = false
		_player.show_cast(spell)
		await _frames(2)
		if String(_player.shown_anim) != want:
			wrong += 1
			print("   %s plays %s, not %s" % [spell, _player.shown_anim, want])
		_player.pose._shot_left = 0.0
		_player.pose._held_left = 0.0
		await _frames(2)
	_verdict(wrong == 0, "each of the %d spells with a style plays it (%d wrong)" % [CastStyles.STYLES.size(), wrong])
	_player.show_cast("Ice Prison")
	await _frames(2)
	_verdict(String(_player.shown_anim) == "release", "and a spell with none thrusts the staff (release)")
	await _frames(40)

	# The magic over the body keeps to it, and takes the spell's color.
	var magic: MagicLayer = _player.find_child("Magic", false, false)
	var sprite: AnimatedSprite2D = _player.get_node("Look")
	var drift := 0
	for anim: String in ["run", "swim", "cast_sky"]:
		sprite.play(anim)
		for k in 20:
			await get_tree().process_frame
			if magic.animation != sprite.animation or magic.frame != sprite.frame:
				drift += 1
	_verdict(drift == 0, "the magic is always on the animation and frame of the body (%d frames off in 60)" % drift)
	_player.cast_color = SpellData.SCHOOL_COLORS["Water"]
	_player.casting = true
	_player._animate(0.016)
	var mid: Color = (magic.material as ShaderMaterial).get_shader_parameter("mid")
	_verdict(mid.is_equal_approx(SpellData.SCHOOL_COLORS["Water"]), "drawing a Water spell makes the gem Water's color (%s)" % str(mid))
	_player.casting = false
	_player.cast_color = Color.WHITE
	_player._animate(0.016)
	mid = (magic.material as ShaderMaterial).get_shader_parameter("mid")
	_verdict(mid.is_equal_approx(SpellData.SCHOOL_COLORS["Water"]), "and it keeps that color after (%s)" % str(mid))
	_player.fear_time = 0.0
	_player.apply_debuff("daze", 1.0)
	await _frames(3)
	mid = (magic.material as ShaderMaterial).get_shader_parameter("mid")
	_verdict(not mid.is_equal_approx(SpellData.SCHOOL_COLORS["Water"]), "but a dazed wizard's stars are another (%s)" % str(mid))
	DirAccess.remove_absolute(GameSettings.path)
	print("pose_check: ", "PASSED" if _failures == 0 else "FAILED (%d)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame
	await get_tree().process_frame


## Puts the body in a state (and keeps it there for `held` frames, calling `setup` each one if `each`), then says which animation is playing.
func _expect(anim: String, state: String, setup: Callable, held := 3, each := false) -> void:
	for k in held:
		if k == 0 or each:
			setup.call()
		await get_tree().physics_frame
	await get_tree().process_frame
	var shown := String(_player.shown_anim)
	_verdict(shown == anim, "%s plays %s (%s)" % [state, anim, shown])

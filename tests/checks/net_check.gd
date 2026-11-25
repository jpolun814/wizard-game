extends Node

## Two machines in one network game, played by two copies of the game on this computer: one hosts, the other joins it by address.
## In the waiting room each must see the other's wizard walk, see a spell the other casts, and be hurt by the other's spell on its own
## machine, with the hurt shown on the other's.
##
##     godot --headless --path . tests/checks/net_check.tscn -- role=host  (in the background)
##     godot --headless --path . tests/checks/net_check.tscn -- role=client
## Each prints what it saw, then PASS or FAIL, and exits with code 1 on a failure. Run in real time (no --fixed-fps): a headless copy
## with a fixed frame rate runs faster than the clock, and its waits end before the other copy has answered.


func _ready() -> void:
	var driver := Driver.new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			driver.out = arg.get_slice("=", 1)
	NetDriver.start(self, driver)


class Driver extends NetDriver:
	var out := ""  # a folder for pictures of what each copy sees (needs a window: leave out --headless)
	var _arena: Node

	func _play() -> void:
		_arena = await _into_the_room(2)
		var me: Wizard = _arena.player
		await _until(func() -> bool: return _other() != null, "the other's wizard")
		var other := _other()
		_check(other.is_likeness() and other.human, "the other's wizard is a likeness of a person")
		_check(other.look != me.look, "the other's wizard wears a look of its own (%s, mine %s)" % [other.look, me.look])
		await _seconds(1.0)
		# The one who joined walks right; the host watches it go.
		var seen_from := other.global_position
		var stood := me.global_position
		if role == "client":
			Input.action_press("move_left")  # away from the lava pit
		await _seconds(0.4)  # both copies wait the same, so they keep in step
		Input.action_release("move_left")
		await _seconds(1.5)
		if role == "host":
			_check(seen_from.x - other.global_position.x > 80.0, "saw the other walk (%.0f px)" % (seen_from.x - other.global_position.x))
		else:
			_check(stood.x - me.global_position.x > 80.0, "walked (%.0f px)" % (stood.x - me.global_position.x))
		if out != "":
			await _pictures(me, other)
		# Each in turn casts a shot at the other: first the one who joined, then the host.
		for shooter in ["client", "host"]:
			await _seconds(5.0)  # the waiting room heals a hit after a few seconds: each shot starts from full
			var my_max: float = me.max_stamina
			var their_max: float = other.max_stamina
			await _seconds(0.5)
			if role == shooter:
				var from := me.center()
				var to := other.center()
				var points := PackedVector2Array()
				for i in 16:
					points.append(from.lerp(to, i / 15.0) + Vector2(0, -2))
				_arena.caster.cast_stroke(SpellData.LEFT, points)  # a flick with the fire button: Ignite
			await _seconds(1.5)
			if role == shooter:
				_check(other.max_stamina < their_max, "%s: my shot hurt the other, as their machine says (%.0f -> %.0f)" % [shooter, their_max, other.max_stamina])
			else:
				_check(me.max_stamina < my_max, "%s's shot hurt me here (%.0f -> %.0f)" % [shooter, my_max, me.max_stamina])
			await _seconds(0.5)
		# The one who joined leaves: the host's room lets them go.
		if role == "client":
			Net.leave()
		await _seconds(2.0)
		if role == "host":
			_check(_other() == null and Net.roster == [1], "the one who left is gone from the room (roster %s)" % [Net.roster])

	## Pictures of the room from each side: both wizards, a stroke the one who joined is drawing as the host sees it, and the host's menu.
	func _pictures(me: Wizard, other: Wizard) -> void:
		await _snap("room")
		if role == "client":
			Input.action_press("school_left")
			for i in 30:  # a wavy line going up, beside the wizard
				var at := me.center() + Vector2(90.0 + sin(i * 0.6) * 18.0, 40.0 - i * 5.0)
				Input.warp_mouse(get_viewport().get_canvas_transform() * at)  # the pointer itself moves: the caster reads where it is
				await get_tree().process_frame
				await get_tree().process_frame
		else:
			await _seconds(0.8)
			await _snap("stroke_seen")
			_arena.hud.toggle_pause()
			await _seconds(0.3)
			await _snap("pause")
			_arena.hud.toggle_pause()
		await _seconds(0.2)
		Input.action_release("school_left")
		await _seconds(2.0)

	func _snap(name: String) -> void:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, name, role])

	## The other person's wizard in the room, once it is there.
	func _other() -> Wizard:
		for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
			if wizard.human and wizard.is_likeness():
				return wizard
		return null



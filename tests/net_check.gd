extends Node

## Two machines in one network game, played by two copies of the game on this computer: one hosts, the other joins it by address.
## In the waiting room each must see the other's wizard walk, see a spell the other casts, and be hurt by the other's spell on its own
## machine, with the hurt shown on the other's.
##
##     godot --headless --path . tests/net_check.tscn -- role=host  (in the background)
##     godot --headless --path . tests/net_check.tscn -- role=client
## Each prints what it saw, then PASS or FAIL, and exits with code 1 on a failure. Run in real time (no --fixed-fps): a headless copy
## with a fixed frame rate runs faster than the clock, and its waits end before the other copy has answered.

const WAITING_ROOM := "res://scenes/lab.tscn"
const GIVE_UP := 40.0  # seconds before a copy that is still waiting for the other gives up


func _ready() -> void:
	var driver := Driver.new()
	driver.role = "host"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("role="):
			driver.role = arg.get_slice("=", 1)
		elif arg.begins_with("out="):
			driver.out = arg.get_slice("=", 1)
	get_tree().root.add_child.call_deferred(driver)  # the driver outlives this scene, which the waiting room replaces


class Driver extends Node:
	var role := "host"
	var out := ""  # a folder for pictures of what each copy sees (needs a window: leave out --headless)
	var _failures := 0
	var _arena: Node

	func _ready() -> void:
		get_tree().create_timer(GIVE_UP).timeout.connect(func() -> void:
			print("%s: gave up waiting" % role)
			get_tree().quit(1))
		if role == "host":
			if out != "":
				get_tree().change_scene_to_file("res://scenes/menu.tscn")
				await _seconds(0.8)
				await _snap("menu")
			Net.host()
			get_tree().change_scene_to_file(WAITING_ROOM)
		else:
			await get_tree().create_timer(1.0).timeout  # the host is listening by then
			Net.join("127.0.0.1")
			await Net.roster_changed
			get_tree().change_scene_to_file(WAITING_ROOM)
		await _until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == WAITING_ROOM)
		_arena = get_tree().current_scene
		var me: Wizard = _arena.player
		await _until(func() -> bool: return _other() != null and Net.is_here(_other().peer))
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
		print("%s: %s" % [role, "PASS" if _failures == 0 else "%d FAILED" % _failures])
		await _seconds(1.0)  # the other copy gets the last of what it needs before this one goes
		get_tree().quit(1 if _failures > 0 else 0)

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

	func _check(ok: bool, what: String) -> void:
		print("%s: %s %s" % [role, "ok  " if ok else "FAIL", what])
		if not ok:
			_failures += 1

	func _seconds(seconds: float) -> void:
		await get_tree().create_timer(seconds).timeout

	func _until(condition: Callable) -> void:
		while not condition.call():
			await get_tree().process_frame

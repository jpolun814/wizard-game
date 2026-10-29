extends Node

## Three machines in one network game, played by three copies of the game on this computer: a host and two who join. Each must see
## the other two, each in a look of its own, and a fireball cast by the second to join must hurt the first to join (a spell that
## goes from one guest to another through the host), as all three machines see it.
##
##     godot --headless --path . tests/net_crowd_check.tscn -- role=host    (in the background)
##     godot --headless --path . tests/net_crowd_check.tscn -- role=first   (in the background, a second later)
##     godot --headless --path . tests/net_crowd_check.tscn -- role=second  (a second after that)
## Each prints what it saw, then PASS or FAIL, and exits with code 1 on a failure. Run in real time (no --fixed-fps).

const WAITING_ROOM := "res://scenes/lab.tscn"
const GIVE_UP := 60.0


func _ready() -> void:
	var driver := Driver.new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("role="):
			driver.role = arg.get_slice("=", 1)
	get_tree().root.add_child.call_deferred(driver)


class Driver extends Node:
	var role := "host"
	var _failures := 0

	func _ready() -> void:
		get_tree().create_timer(GIVE_UP).timeout.connect(func() -> void:
			print("%s: gave up waiting" % role)
			get_tree().quit(1))
		if role == "host":
			Net.host()
		else:
			await _seconds(1.0)
			Net.join("127.0.0.1")
			await Net.roster_changed
		get_tree().change_scene_to_file(WAITING_ROOM)
		await _until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == WAITING_ROOM)
		var room: Node = get_tree().current_scene
		await _until(func() -> bool: return Net.roster.size() == 3 and Net.peers_here().size() == 2 and _others().size() == 2)
		var first: Wizard = room.get_node(Wizard.name_for(Net.roster[1]))
		var before: float = first.max_stamina  # read at once: the copies are not in step, and the shot comes later
		await _seconds(1.5)
		var looks := {room.player.look: true}
		for other in _others():
			looks[other.look] = true
		_check(looks.size() == 3, "three wizards, three looks (%s)" % [looks.keys()])
		if Net.my_id() == Net.roster[2]:  # whichever copy joined second
			await _seconds(1.5)  # the other two have read the first's stamina by now
			var from: Vector2 = room.player.center()
			var to := first.center()
			var points := PackedVector2Array()
			for i in 16:
				points.append(from.lerp(to, i / 15.0) + Vector2(0, -2))
			room.caster.cast_stroke(SpellData.LEFT, points)  # Ignite, at the first to join
		await _seconds(3.5)
		_check(first.max_stamina < before, "the second's fireball hurt the first, as seen here (%.0f -> %.0f)" % [before, first.max_stamina])
		print("%s: %s" % [role, "PASS" if _failures == 0 else "%d FAILED" % _failures])
		await _seconds(1.5)
		get_tree().quit(1 if _failures > 0 else 0)

	func _others() -> Array[Wizard]:
		var out: Array[Wizard] = []
		for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
			if wizard.human and wizard.is_likeness():
				out.append(wizard)
		return out

	func _check(ok: bool, what: String) -> void:
		print("%s: %s %s" % [role, "ok  " if ok else "FAIL", what])
		if not ok:
			_failures += 1

	func _seconds(seconds: float) -> void:
		await get_tree().create_timer(seconds).timeout

	func _until(condition: Callable) -> void:
		while not condition.call():
			await get_tree().process_frame

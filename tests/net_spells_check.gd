extends Node

## Two copies of the game in one world, to see that the new spells that need a second machine to see them do: a skeleton raised on one machine is a puppet on the
## other and keeps up with it; a Mirage cast on the second is there on the first; a Leech tether is seen on both and the other end pays half of a spell cast on the
## tether; the Scrying Eye's little eye floats over the watched wizard on every machine.
##
##     godot --headless --path . tests/net_spells_check.tscn -- role=host      (in the background)
##     godot --headless --path . tests/net_spells_check.tscn -- role=client
## Run in real time (no --fixed-fps). Each copy prints PASS or FAIL and exits with code 1 if any failed.

const WAITING_ROOM := "res://scenes/lab.tscn"
const WORLD := "res://scenes/world.tscn"
const GIVE_UP := 150.0


func _ready() -> void:
	var driver := Driver.new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("role="):
			driver.role = arg.get_slice("=", 1)
		elif arg.begins_with("seed="):
			World.next_seed = int(arg.get_slice("=", 1))
	get_tree().root.add_child.call_deferred(driver)


class Driver extends Node:
	var role := "host"
	var failures := 0
	var world: Node

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
		var room: Node = await _scene(WAITING_ROOM)
		await _until(func() -> bool: return Net.peers_here().size() == 1)
		await _seconds(1.0)
		var portal: Node2D = get_tree().get_first_node_in_group("portals")
		if role == "client":
			await _seconds(2.0)
		room.player.global_position = portal.global_position + Vector2(0, -30)
		await _until(func() -> bool: return get_tree().current_scene == null or get_tree().current_scene.scene_file_path != WAITING_ROOM)
		await _seconds(1.5)
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.pressed = true
		Input.parse_input_event(key)
		world = await _scene(WORLD)
		await _until(func() -> bool: return Net.peers_here().size() == 1)
		MatchState.hurry = 100.0  # no collapse while we watch
		world.player.ledger.learn_all()
		if role == "host":  # the host's brains are put away: one casting a Mirage, or a blow that breaks a tether, would spoil what is counted here
			for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
				if wizard.brain != null:
					wizard.set_physics_process(false)
					wizard.global_position = Vector2(-9000.0, -9000.0)
		await _seconds(4.0)
		await _skeleton()
		await _mirage()
		await _leech()
		await _eye()
		print("%s: %s" % [role, "everything seen on both machines" if failures == 0 else "%d FAILED" % failures])
		get_tree().quit(1 if failures > 0 else 0)

	func _check(ok: bool, message: String) -> void:
		print("%s  %s: %s" % ["PASS" if ok else "FAIL", role, message])
		if not ok:
			failures += 1

	## The other person's wizard, as seen from here.
	func _other() -> Wizard:
		for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
			if wizard != world.player and wizard.human:
				return wizard
		return null

	func _raised() -> Array:
		return get_tree().get_nodes_in_group("mobs").filter(func(m): return String(m.name).begins_with("Raised_") and not m.is_dead())

	func _skeleton() -> void:
		if role == "host":
			world.casting.by("Raise Dead", "positional", world.player.global_position + Vector2(60.0, 0.0), 0.0, {"accuracy": 0.9}, world.player)
		await _seconds(4.0)
		var risen := _raised()
		_check(risen.size() == 1, "a skeleton raised by the host stands on both machines (%d)" % risen.size())
		if risen.is_empty():
			return
		var skeleton: Mob = risen[0]
		_check(skeleton.puppet == (role == "client"), "it drives itself on the host machine and is a puppet on the other (puppet %s)" % skeleton.puppet)
		_check(skeleton.master != null, "and it has a master here")
		# The master walks off, and the skeleton keeps up on both.
		if role == "host":
			world.player.velocity = Vector2.ZERO
			world.player.global_position += Vector2(450.0, 0.0)
		await _seconds(8.0)
		if not is_instance_valid(skeleton) or not is_instance_valid(skeleton.master):
			return  # a rival it was set on, or the end of the match, took it
		var gap := skeleton.global_position.distance_to(skeleton.master.global_position)
		_check(gap < 400.0, "it follows its master on this machine (%.0f px apart)" % gap)
		for each: Node in _raised():  # (it hunts whoever is near, and a wizard it fells would end the match under the rest of the check)
			each.queue_free()

	func _mirage() -> void:
		if role == "client":
			world.casting.by("Mirage", "positional", world.player.global_position + Vector2(500.0, 0.0), 0.0, {"accuracy": 0.9}, world.player)
		await _seconds(3.0)
		var count := get_tree().get_nodes_in_group("pages").filter(func(p): return p is Mirage and not p.is_queued_for_deletion()).size()
		_check(count == 1, "a Mirage cast on one machine is there on both (%d)" % count)

	func _leech() -> void:
		var other := _other()
		_check(other != null, "the other person has a wizard here")
		if other == null:
			return
		if role == "host":  # the host steps up beside the other and tethers them
			world.player.global_position = other.global_position + Vector2(-110.0, -20.0)
			world.player.velocity = Vector2.ZERO
		await _seconds(3.0)
		if role == "host":
			var toward: float = (other.center() - world.player.center()).angle()
			world.casting.by("Leech", "directional", world.player.center(), toward, {"length": 90.0, "accuracy": 0.9}, world.player)
		await _seconds(2.0)
		var tethers := get_tree().get_nodes_in_group("leeches").filter(func(l): return not l.is_queued_for_deletion())
		_check(tethers.size() == 1, "a tether is seen on both machines (%d)" % tethers.size())
		world.player.stamina = world.player.max_stamina
		var before: float = world.player.stamina
		await _seconds(1.0)
		if role == "host":
			world.casting.by("Ignite", "directional", world.player.center(), -PI / 2.0, {"length": 90.0, "accuracy": 0.9}, world.player)
		await _seconds(0.25)  # soon after: stamina comes back on its own
		var cost: float = SpellData.SPELLS["Ignite"].cost_for({"length": 90.0, "accuracy": 0.9})
		var lost: float = before - world.player.stamina
		var who := "the one who cast pays half" if role == "host" else "the one on the tether pays the other half, on their own machine"
		_check(absf(lost - cost * 0.5) < 2.0, "%s (%.1f of %.1f)" % [who, lost, cost])

	func _eye() -> void:
		if role == "client":
			world.rituals.toggle(RitualInput.RITUALS["scrying_eye"], 1.0)
		await _seconds(3.0)
		var marks := get_tree().get_nodes_in_group("eye_marks").filter(func(m): return is_instance_valid(m) and not m.is_queued_for_deletion())
		if not is_instance_valid(world):
			return  # the other machine has already ended the match
		var eye: ScryingEye = world._eye
		_check(marks.size() == 1, "a little eye floats over the watched wizard on both machines (%d; window %s, watching %s, revealed %s)" % [marks.size(), eye.is_visible_in_tree(), eye.watched, world.revealed])

	func _scene(path: String) -> Node:
		await _until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == path and get_tree().current_scene.is_node_ready())
		return get_tree().current_scene

	func _seconds(seconds: float) -> void:
		await get_tree().create_timer(seconds).timeout

	func _until(condition: Callable) -> void:
		while not condition.call():
			await get_tree().process_frame

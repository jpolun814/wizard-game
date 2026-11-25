extends Node

## Two copies of the game in one world, to see that the new spells that need a second machine to see them do: a skeleton raised on one machine is a puppet on the
## other and keeps up with it; a Mirage cast on the second is there on the first; a Leech tether is seen on both and the other end pays half of a spell cast on the
## tether; the Scrying Eye's little eye floats over the watched wizard on every machine.
##
##     godot --headless --path . tests/checks/net_spells_check.tscn -- role=host      (in the background)
##     godot --headless --path . tests/checks/net_spells_check.tscn -- role=client
## Run in real time (no --fixed-fps). Each copy prints PASS or FAIL and exits with code 1 if any failed.


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):
			World.next_seed = int(arg.get_slice("=", 1))
	NetDriver.start(self, Driver.new())


class Driver extends NetDriver:
	var world: Node

	func _play() -> void:
		var room: Node = await _into_the_room(2)
		await _seconds(1.0)
		world = await _into_the_world(room, 1)
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
		_check(is_instance_valid(skeleton) and is_instance_valid(skeleton.master), "the skeleton and its master are still there")
		var gap := skeleton.global_position.distance_to(skeleton.master.global_position)
		_check(gap < 400.0, "it follows its master on this machine (%.0f px apart)" % gap)
		if role == "host":
			skeleton.take_damage(100000)  # (it hunts whoever is near, and a wizard it fells would end the match under the rest of the check)
		await _seconds(1.0)
		_check(_raised().is_empty(), "and when it falls on the host it has fallen here")

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
			for beside: Vector2 in [Vector2(-110.0, -20.0), Vector2(110.0, -20.0), Vector2(-60.0, -20.0), Vector2(60.0, -20.0)]:  # (on whichever side of them is open)
				var at := other.global_position + beside
				if not world.in_rock(at + Vector2(0.0, -30.0)) and Leech.sees(get_tree(), at + Vector2(0.0, -30.0), other.center(), world.get_world_2d()):
					world.player.global_position = at
					break
			world.player.velocity = Vector2.ZERO
		await _seconds(2.0)
		world.player.set_physics_process(false)  # (both stand still from here on: a tether that snaps because one slid out of sight is not what is being checked, nor is stamina coming back)
		await _seconds(1.0)
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
		_check(absf(lost - cost * 0.5) < 0.1, "%s (%.1f of %.1f)" % [who, lost, cost])
		world.player.set_physics_process(true)

	func _eye() -> void:
		if role == "client":
			world.rituals.toggle(RitualInput.RITUALS["scrying_eye"], 1.0)
		await _seconds(3.0)
		var marks := get_tree().get_nodes_in_group("eye_marks").filter(func(m): return is_instance_valid(m) and not m.is_queued_for_deletion())
		var eye: ScryingEye = world._eye
		_check(marks.size() == 1, "a little eye floats over the watched wizard on both machines (%d; window %s, watching %s, revealed %s)" % [marks.size(), eye.is_visible_in_tree(), eye.watched, world.revealed])



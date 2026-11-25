extends Node

## Three machines in one network game, played by three copies of the game on this computer: a host and two who join. Each must see
## the other two, each in a look of its own, and a fireball cast by the second to join must hurt the first to join (a spell that
## goes from one guest to another through the host), as all three machines see it.
##
##     godot --headless --path . tests/checks/net_crowd_check.tscn -- role=host    (in the background)
##     godot --headless --path . tests/checks/net_crowd_check.tscn -- role=first   (in the background, a second later)
##     godot --headless --path . tests/checks/net_crowd_check.tscn -- role=second  (a second after that)
## Each prints what it saw, then PASS or FAIL, and exits with code 1 on a failure. Run in real time (no --fixed-fps).


func _ready() -> void:
	NetDriver.start(self, Driver.new())


class Driver extends NetDriver:
	func _play() -> void:
		var room: Node = await _into_the_room(3)
		await _until(func() -> bool: return _others().size() == 2, "the other two wizards")
		await _seconds(1.5)
		var first := _first()
		var before: float = first.max_stamina
		var looks := {room.player.look: true}
		for other in _others():
			looks[other.look] = true
		_check(looks.size() == 3, "three wizards, three looks (%s)" % [looks.keys()])
		if Net.my_id() == Net.roster[2]:  # whichever copy joined second
			var from: Vector2 = room.player.center()
			var to := first.center()
			var points := PackedVector2Array()
			for i in 16:
				points.append(from.lerp(to, i / 15.0) + Vector2(0, -2))
			room.caster.cast_stroke(SpellData.LEFT, points)  # Ignite, at the first to join
		await _seconds(3.5)
		_check(first.max_stamina < before, "the second's fireball hurt the first, as seen here (%.0f -> %.0f)" % [before, first.max_stamina])

	## The first to join, as seen here: on its own machine, the wizard its person drives.
	func _first() -> Wizard:
		return get_tree().current_scene.get_node(Wizard.name_for(Net.roster[1]))

	func _others() -> Array[Wizard]:
		var out: Array[Wizard] = []
		for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
			if wizard.human and wizard.is_likeness():
				out.append(wizard)
		return out



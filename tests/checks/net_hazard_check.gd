extends Node

## Two copies of the game in one world, to see that its mobs and hazards are the same on both: the graveyard's roaming skeletons (their places)
## and the ashlands' volcanoes (whether each is erupting), printed once a second by each copy to be set side by side.
##
##     godot --headless --path . tests/checks/net_hazard_check.tscn -- role=host seed=1  (in the background)
##     godot --headless --path . tests/checks/net_hazard_check.tscn -- role=client seed=2
## seed=2 is a graveyard first, seed=5 the ashlands (the order of biomes follows the seed: `MatchState.biome_of(0)`). Run in real time (no --fixed-fps).


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):
			World.next_seed = int(arg.get_slice("=", 1))
	NetDriver.start(self, Driver.new())


class Driver extends NetDriver:
	var _lost_page := ""
	var _struck_name := ""

	func _play() -> void:
		var room: Node = await _into_the_room(2)
		await _seconds(1.0)
		var world: Node = await _into_the_world(room, 1)
		MatchState.hurry = 100.0  # no collapse while we watch
		print("%s: world seed %d, biome %s" % [role, world.seed_value, world.graph.surface["biomes"][0]["name"]])
		for second in 40:
			await _seconds(1.0)
			var line := "%s t=%02d" % [role, second]
			for mob: Node in get_tree().get_nodes_in_group("mobs"):
				if String(mob.name).begins_with("Dead") and int(String(mob.name).substr(4)) < 3:
					line += " %s=(%d,%d)" % [mob.name, mob.global_position.x, mob.global_position.y]
			if second == 0:  # a crypt guard is picked (the same on both machines: before anything has struck one)
				var guard := _a_guard()
				if guard != null:
					_struck_name = String(guard.name)
			if second == 10 and role == "host" and _struck_name != "":  # it falls on the host, and must fall here too
				for mob: Node in get_tree().get_nodes_in_group("mobs"):
					if String(mob.name) == _struck_name:
						mob.take_damage(100000)
						print("host: struck %s" % mob.name)
			if second == 8:  # a page, the same on both machines, that the host will lose without telling anyone
				var names := []
				for page: Node in get_tree().get_nodes_in_group("pages"):
					names.append(String(page.name))
				names.sort()
				_lost_page = names[names.size() - 1] if not names.is_empty() else ""
			if second == 9:
				var had := false
				for page: Node in get_tree().get_nodes_in_group("pages"):
					had = had or String(page.name) == _lost_page
				_check(had, "has the page (%s) before the host loses it" % _lost_page)
			if second == 9 and role == "host" and _lost_page != "":
				for page: Node in get_tree().get_nodes_in_group("pages"):
					if String(page.name) == _lost_page:
						page.free()
						print("host: lost page %s without a word" % _lost_page)
			if second == 20 and _lost_page != "":
				var still := false
				for page: Node in get_tree().get_nodes_in_group("pages"):
					still = still or String(page.name) == _lost_page
				_check(not still, "a page the host lost is off the ground here too (%s)" % _lost_page)
			if second == 25 and _struck_name != "":
				var gone := true
				for mob: Node in get_tree().get_nodes_in_group("mobs"):
					if String(mob.name) == _struck_name and not mob.is_dead():
						gone = false
				_check(gone, "the guard that fell on the host has fallen here too (%s)" % _struck_name)
			if second == 20 or second == 38:  # the pages still lying about: the same ones here as on the host
				var lying := []
				for page: Node in get_tree().get_nodes_in_group("pages"):
					if not page.is_queued_for_deletion():
						lying.append(String(page.name))
				lying.sort()
				print("%s PAGES t=%d %d %s" % [role, second, lying.size(), str(lying).md5_text().substr(0, 8)])
			if second == 12 or second == 30:  # every skeleton: how many, and what each machine shows of them
				var all := []
				for mob: Node in get_tree().get_nodes_in_group("mobs"):
					if String(mob.name).begins_with("Dead"):
						all.append("%s(%d,%d)%s%s%s" % [mob.name, mob.global_position.x, mob.global_position.y, "P" if mob.puppet else "H", "v" if mob.is_visible_in_tree() else "-", "x" if mob.is_dead() else ""] + _look_of(mob))
				all.sort()
				print("%s ALL %d: %s" % [role, all.size(), " ".join(all)])
				for mob: Node in get_tree().get_nodes_in_group("mobs"):  # one the host has lost must be lost here too, and not left standing at the corner of the map
					if String(mob.name).begins_with("Dead") and mob.global_position.length() < 50.0 and not mob.is_dead():
						_check(false, "%s stands at the corner of the map" % mob.name)
			for child in (world.get_children() if is_instance_valid(world) else []):
				if child is Eruption:
					line += " %s=%s" % [child.name, "ERUPT" if child.is_erupting() else "-"]
			print(line)

	## The first skeleton of a crypt that is still standing: it does not roam, and is the same one on both machines.
	func _a_guard() -> Mob:
		var best: Mob = null
		for mob: Node in get_tree().get_nodes_in_group("mobs"):
			if String(mob.name).begins_with("Dead") and not mob.roams and not mob.is_dead():
				if best == null or int(String(mob.name).substr(4)) < int(String(best.name).substr(4)):
					best = mob
		return best

	## What the sprite of a skeleton shows: its frame, its transparency and whether it is hidden.
	func _look_of(mob: Node) -> String:
		var sprite := mob.get_node_or_null("Visual") as AnimatedSprite2D
		if sprite == null:
			return "[no sprite]"
		return "[%s a=%.1f%s]" % [sprite.animation, sprite.modulate.a * sprite.self_modulate.a, "" if sprite.visible else " HIDDEN"]



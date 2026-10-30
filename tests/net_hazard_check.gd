extends Node

## Two copies of the game in one world, to see that its mobs and hazards are the same on both: the graveyard's roaming skeletons (their places)
## and the ashlands' volcanoes (whether each is erupting), printed once a second by each copy to be set side by side.
##
##     godot --headless --path . tests/net_hazard_check.tscn -- role=host seed=1  (in the background)
##     godot --headless --path . tests/net_hazard_check.tscn -- role=client seed=1
## seed=1 is a graveyard first, seed=5 the ashlands. Run in real time (no --fixed-fps).

const WAITING_ROOM := "res://scenes/lab.tscn"
const WORLD := "res://scenes/world.tscn"
const GIVE_UP := 120.0


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
		room.player.global_position = portal.global_position + Vector2(0, 30)
		await _until(func() -> bool: return get_tree().current_scene == null or get_tree().current_scene.scene_file_path != WAITING_ROOM)
		await _seconds(1.5)
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.pressed = true
		Input.parse_input_event(key)
		var world: Node = await _scene(WORLD)
		await _until(func() -> bool: return Net.peers_here().size() == 1)
		MatchState.hurry = 100.0  # no collapse while we watch
		print("%s: world seed %d, biome %s" % [role, world.seed_value, world.graph.surface["biomes"][0]["name"]])
		for second in 40:
			await _seconds(1.0)
			var line := "%s t=%02d" % [role, second]
			for mob: Node in get_tree().get_nodes_in_group("mobs"):
				if String(mob.name).begins_with("Dead") and int(String(mob.name).substr(4)) < 3:
					line += " %s=(%d,%d)" % [mob.name, mob.global_position.x, mob.global_position.y]
			for child in world.get_children():
				if child is Eruption:
					line += " %s=%s" % [child.name, "ERUPT" if child.is_erupting() else "-"]
			print(line)
		print("%s: done" % role)
		get_tree().quit(0)

	func _scene(path: String) -> Node:
		await _until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == path and get_tree().current_scene.is_node_ready())
		return get_tree().current_scene

	func _seconds(seconds: float) -> void:
		await get_tree().create_timer(seconds).timeout

	func _until(condition: Callable) -> void:
		while not condition.call():
			await get_tree().process_frame

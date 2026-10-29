extends Node

## A whole network match, played by two copies of the game on this computer: one hosts, the other joins. Both walk into the waiting
## room's portal, skip the cut-scene and land in the same world, where brains play the two empty seats on the host and likenesses of
## them stand on the other machine. The one who joined reads a page (the host says it may), the portal collapses into the next world for
## both at once, the one who joined falls and drops its book, and when the host is the last standing everyone goes back to the waiting
## room.
##
##     godot --headless --path . tests/net_match_check.tscn -- role=host  (in the background)
##     godot --headless --path . tests/net_match_check.tscn -- role=client
## Add `leave` to both for the one who joined to leave the game in the second world instead: its wizard must fall there all the same.
## Each prints what it saw, then PASS or FAIL, and exits with code 1 on a failure. Run in real time (no --fixed-fps): the two copies
## talk over the network, which keeps the clock on the wall.

const WAITING_ROOM := "res://scenes/lab.tscn"
const WORLD := "res://scenes/world.tscn"
const GIVE_UP := 300.0


func _ready() -> void:
	var driver := Driver.new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("role="):
			driver.role = arg.get_slice("=", 1)
		elif arg.begins_with("out="):
			driver.out = arg.get_slice("=", 1)
		elif arg == "leave":
			driver.leave = true
	get_tree().root.add_child.call_deferred(driver)  # the driver outlives every scene of the match


class Driver extends Node:
	var role := "host"
	var out := ""  # a folder for pictures of what each copy sees (needs a window: leave out --headless)
	var leave := false  # the one who joined leaves the game in the second world, rather than falling there
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
		var room: Node = await _scene(WAITING_ROOM)
		await _until(func() -> bool: return Net.peers_here().size() == 1)
		await _seconds(1.0)
		# Into the portal. The host goes first, and must wait for the other.
		var portal: Node2D = get_tree().get_first_node_in_group("portals")
		if role == "client":
			await _seconds(2.0)
		room.player.global_position = portal.global_position + Vector2(0, 30)
		await _until(func() -> bool: return get_tree().current_scene == null or get_tree().current_scene.scene_file_path != WAITING_ROOM)
		print("%s: left the waiting room" % role)
		await _seconds(1.5)
		var key := InputEventKey.new()  # any key skips the cut-scene
		key.keycode = KEY_SPACE
		key.pressed = true
		Input.parse_input_event(key)
		var world: Node = await _scene(WORLD)
		await _until(func() -> bool: return Net.peers_here().size() == 1)
		await _seconds(2.0)
		_check_world(world, 0)
		if out != "":
			await _snap("world")
			if role == "host":  # the host walks to the other, so the picture shows them both
				var guest: Wizard = world.get_node(Wizard.name_for(Net.roster[1]))
				world.player.global_position = guest.global_position + Vector2(-90, 0)
			await _seconds(1.5)
			await _snap("together")
		# The one who joined reads a page, which the host must allow. Both must see it gone, and in that wizard's book.
		var page: Node2D = get_tree().get_first_node_in_group("pages")
		var page_name := String(page.name)
		var page_text: String = page.page
		var reader_name := Wizard.name_for(Net.roster[1])
		var reader: Wizard = world.get_node(reader_name)
		if role == "client":
			reader.global_position = page.global_position
			await _seconds(0.3)
			world.read_page(page, reader)
		await _seconds(2.0)
		_check(world.get_node_or_null(page_name) == null, "the page read by the one who joined is gone here")
		_check(reader.ledger.knows(page_text), "it is in that wizard's book here (%s)" % page_text)
		# Gates cleared on the host's machine are gone from the other's too. (The brains clear gates of their own as they go, so each
		# machine's first gate may differ: the host clears every one.)
		var gates := func() -> Array:
			return world.get_children().filter(func(child: Node) -> bool: return String(child.name).begins_with("Gate") and not child.is_queued_for_deletion())
		var had: int = gates.call().size()
		if role == "host":
			for piece: Node in gates.call():
				piece.queue_free()
		await _seconds(2.0)
		_check(gates.call().is_empty(), "every gate the host cleared is gone here (%d of %d left)" % [gates.call().size(), had])
		# The collapse: the host hurries its clock; the other machine must follow the host's.
		if role == "host":
			MatchState.hurry = 0.01
		await _until(func() -> bool: return get_tree().current_scene != world)
		print("%s: the world collapsed" % role)
		var next: Node = await _scene(WORLD)
		await _until(func() -> bool: return Net.peers_here().size() == 1)
		await _seconds(2.0)
		MatchState.hurry = 100.0  # no second collapse while the rest is checked
		_check(MatchState.stage == 1, "in the second world of the match (stage %d)" % MatchState.stage)
		_check_world(next, 1)
		# The one who joined falls: its book lies where it fell, on both machines.
		var fallen: Wizard = next.get_node(reader_name)
		if role == "client" and leave:
			Net.leave()
			print("client: left the game")
			await _seconds(1.0)
			get_tree().quit(0)
			return
		if role == "client":
			fallen.take_damage(9999)
		await _seconds(2.0)
		_check(fallen.dead, "the one who joined has fallen, as seen here")
		_check(next.get_node_or_null("Spoils" + reader_name) != null, "its book lies where it fell")
		if out != "":
			await _snap("fallen")
		# The host beats the brains, and is the last standing: everyone goes back to the waiting room.
		if role == "host":
			for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
				if wizard.brain != null:
					wizard.take_damage(9999)
		await _scene(WAITING_ROOM)
		_check(true, "back in the waiting room after the match")
		if leave:
			await _seconds(1.0)
			_check(Net.roster == [1], "the seat of the one who left is given up (roster %s)" % [Net.roster])
		else:
			await _until(func() -> bool: return Net.peers_here().size() == 1)
		print("%s: %s" % [role, "PASS" if _failures == 0 else "%d FAILED" % _failures])
		await _seconds(1.0)
		get_tree().quit(1 if _failures > 0 else 0)

	## The same world on both machines: the seed, four seats, brains on the host and likenesses of them on the other.
	func _check_world(world: Node, stage: int) -> void:
		var wizards := get_tree().get_nodes_in_group("wizards")
		var names: Array[String] = []
		for wizard: Wizard in wizards:
			names.append(String(wizard.name))
		names.sort()
		print("%s: world %d, seed %d, wizards %s, pages %d" % [role, stage, world.seed_value, names, get_tree().get_nodes_in_group("pages").size()])
		_check(wizards.size() == 4 or stage > 0, "four wizards in the first world (%d)" % wizards.size())
		var brains := 0
		var brain_likenesses := 0
		for wizard: Wizard in wizards:
			if wizard.brain != null:
				brains += 1
			elif not wizard.human:
				brain_likenesses += 1
		if role == "host":
			_check(brains == wizards.size() - 2 and brain_likenesses == 0, "brains play the empty seats here (%d)" % brains)
		else:
			_check(brains == 0 and brain_likenesses == wizards.size() - 2, "the brains' wizards are likenesses here (%d)" % brain_likenesses)
		_check(world.player.ledger == world.ledgers[Net.seat_of(Net.my_id())], "the player holds the ledger of their seat")

	func _snap(name: String) -> void:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, name, role])

	func _check(ok: bool, what: String) -> void:
		print("%s: %s %s" % [role, "ok  " if ok else "FAIL", what])
		if not ok:
			_failures += 1

	func _scene(path: String) -> Node:
		await _until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == path and get_tree().current_scene.is_node_ready())
		return get_tree().current_scene

	func _seconds(seconds: float) -> void:
		await get_tree().create_timer(seconds).timeout

	func _until(condition: Callable) -> void:
		while not condition.call():
			await get_tree().process_frame

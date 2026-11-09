extends Node

## A dedicated server: the game started as its own program with nobody at it (`-- --server`), and one copy that joins it as a client. The client sees the waiting
## room, touches the book, and plays in a world where the server's own wizard (the first seat) and the brains of the empty seats are all played by brains on the
## server. When the client is the last standing, everyone goes back to the waiting room, and the server is waiting there for the next match.
##
##     godot --headless --path . tests/dedicated_check.tscn
## It starts the server itself, joins it, prints PASS or FAIL for each thing, stops the server and exits with code 1 on a failure. It talks over the network, so it runs
## in real time (no --fixed-fps).

const WAITING_ROOM := "res://scenes/lab.tscn"
const WORLD := "res://scenes/world.tscn"
const GIVE_UP := 240.0



func _ready() -> void:
	get_tree().root.add_child.call_deferred(Runner.new())  # (it outlives the scenes it goes through)


class Runner extends Node:
	var _failures := 0
	var _server := -1


	func _ready() -> void:
		get_tree().create_timer(GIVE_UP).timeout.connect(func() -> void:
			print("FAIL  gave up waiting")
			_stop(1))
		var arguments := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--", "--server"])
		if not OS.get_cmdline_user_args().has("external"):  # (`external`: a server already started by hand, to see what it prints)
			OS.set_environment("WIZARD_HURRY", "0.12")  # (worlds that collapse quickly: the server and this program both read it)
			MatchState.hurry = 0.12
			_server = OS.create_process(OS.get_executable_path(), arguments)  # (it keeps this program's environment, so WIZARD_PORT reaches it too)
			_check(_server > 0, "the server program starts")
		await _seconds(8.0)  # it opens its port and loads the waiting room
		_check(Net.join("127.0.0.1") == OK, "the client joins the server's address")
		await Net.roster_changed
		await _until(func() -> bool: return Net.roster.size() >= 2)
		_check(Net.roster[0] == 1 and Net.roster.size() == 2, "the server holds the first seat and the client the second (%s)" % [Net.roster])
		get_tree().change_scene_to_file(WAITING_ROOM)
		var room: Node = await _scene(WAITING_ROOM)
		await _until(func() -> bool: return Net.is_here(1))
		_check(true, "the client sees the server in the waiting room")
		await _seconds(1.0)
		var portal: Node2D = get_tree().get_first_node_in_group("portals")
		room.player.global_position = portal.global_position + Vector2(0, -30)  # (the book is touched at the portal)
		await _until(func() -> bool: return get_tree().current_scene == null or get_tree().current_scene.scene_file_path != WAITING_ROOM)
		await _seconds(1.5)
		var key := InputEventKey.new()  # any key skips the cut-scene
		key.keycode = KEY_SPACE
		key.pressed = true
		Input.parse_input_event(key)
		var world: Node = await _scene(WORLD)
		await _until(func() -> bool: return Net.peers_here().size() == 1)
		await _seconds(3.0)
		var names: Array[String] = []
		for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
			names.append(String(wizard.name))
		_check(names.size() == World.WIZARDS, "all %d wizards are here (%d)" % [World.WIZARDS, names.size()])
		var host_wizard: Wizard = world.get_node_or_null(Wizard.name_for(1))
		_check(host_wizard != null, "the server's wizard is here as a likeness")
		if host_wizard != null:
			var walked := 0.0  # (the road it covers, not how far it ends from where it began: it may go and come back)
			var last := host_wizard.global_position
			for k in 20:
				await _seconds(0.5)
				walked += host_wizard.global_position.distance_to(last)
				last = host_wizard.global_position
			_check(walked > 60.0, "and it plays on its own: it covered %.0f px in ten seconds" % walked)
		await _try_a_page(world, "the first world")
		var first_scene := get_tree().current_scene
		await _until(func() -> bool: return get_tree().current_scene != first_scene or not is_instance_valid(first_scene))  # the portal collapses into the next world
		world = await _scene(WORLD)
		await _until(func() -> bool: return Net.peers_here().size() == 1)
		await _seconds(4.0)
		await _try_a_page(world, "the second world")
		# The client leaves: with nobody left, the server ends the match and waits in the room, where a newcomer finds it.
		Net.leave()
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		await _seconds(8.0)
		_check(Net.join("127.0.0.1") == OK, "a newcomer joins the same server again")
		await _until(func() -> bool: return Net.roster.size() >= 2)
		get_tree().change_scene_to_file(WAITING_ROOM)
		await _scene(WAITING_ROOM)
		await _until(func() -> bool: return Net.is_here(1))
		_check(true, "and finds the server back in the waiting room")
		print("%s: done" % ("FAIL" if _failures > 0 else "PASS"))
		_stop(1 if _failures > 0 else 0)


	## The client walks to a page and reads it: the server (which says who reads which) must answer, the page leave the ground and enter the book.
	func _try_a_page(world: Node, where: String) -> void:
		var target: PagePickup
		for pickup: PagePickup in get_tree().get_nodes_in_group("pages"):
			if not pickup.is_queued_for_deletion() and not pickup is Mirage and pickup.gives(world.player.ledger):
				target = pickup
				break
		if target == null:
			_check(false, "%s: there is a page to read" % where)
			return
		var name_of := String(target.name)
		world.player.global_position = target.global_position + Vector2(0, -20)
		await _seconds(0.5)
		world.read_page(target, world.player)
		await _seconds(2.0)
		var gone := world.get_node_or_null(NodePath(name_of)) == null or world.get_node(NodePath(name_of)).is_queued_for_deletion()
		_check(gone, "%s: the page %s is read and gone from the ground" % [where, name_of])


	func _stop(code: int) -> void:
		if _server > 0:
			OS.kill(_server)
		Net.leave()
		get_tree().quit(code)


	func _scene(path: String) -> Node:
		await _until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == path and get_tree().current_scene.is_node_ready())
		return get_tree().current_scene


	func _seconds(seconds: float) -> void:
		await get_tree().create_timer(seconds).timeout


	func _until(condition: Callable) -> void:
		while not condition.call():
			await get_tree().process_frame


	func _check(ok: bool, message: String) -> void:
		print("%s  %s" % ["PASS" if ok else "FAIL", message])
		if not ok:
			_failures += 1

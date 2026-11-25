extends Node

## A dedicated server: the game started as its own program with nobody at it (`-- --server`), and one copy that joins it as a client. The client sees the waiting
## room, touches the book, and plays in a world where the server's own wizard (the first seat) and the brains of the empty seats are all played by brains on the
## server. When the client is the last standing, everyone goes back to the waiting room, and the server is waiting there for the next match.
##
## The runner starts the server (the game with `-- --server`) beside this copy, and stops it when this one has ended.

const HURRY := 0.4  # (worlds that collapse quickly: the server is told the same by WIZARD_HURRY; the first world lasts 180 s, so this leaves it 72)


func _ready() -> void:
	NetDriver.start(self, Driver.new())


class Driver extends NetDriver:
	## The person only stands there, in a match the brains play in earnest: they are kept on their feet, for one who has fallen reads no pages.
	func _physics_process(_delta: float) -> void:
		var world := get_tree().current_scene as World
		if world != null and world.player != null:
			world.player.max_stamina = Wizard.MAX_STAMINA

	func _play() -> void:
		MatchState.hurry = HURRY
		await _seconds(0.5)  # (the server opens its game as its first scene loads)
		var room: Node = await _into_the_room(2)
		_check(Net.roster[0] == 1 and Net.roster.size() == 2, "the server holds the first seat and the client the second (%s)" % [Net.roster])
		_check(Net.is_here(1), "the client sees the server in the waiting room")
		await _seconds(1.0)
		var world: Node = await _into_the_world(room, 1)
		await _seconds(3.0)
		var names: Array[String] = []
		for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
			names.append(String(wizard.name))
		_check(names.size() == World.WIZARDS, "all %d wizards are here (%d)" % [World.WIZARDS, names.size()])
		var host_wizard: Wizard = world.get_node_or_null(Wizard.name_for(1))
		_check(host_wizard != null, "the server's wizard is here as a likeness")
		if host_wizard != null:
			var walked := 0.0  # (the road it covers, not how far it ends from where it began: it may go and come back)
			var casts := 0  # (and the times it was seen drawing a spell, or its stamina changing, which a spell costs: a wizard that stands and fights plays on its own too, and covers no road)
			var spent := host_wizard.stamina
			var last := host_wizard.global_position
			for k in 20:
				await _seconds(0.5)
				walked += host_wizard.global_position.distance_to(last)
				last = host_wizard.global_position
				casts += 1 if host_wizard.casting or absf(host_wizard.stamina - spent) > 0.5 else 0
				spent = host_wizard.stamina
			_check(walked > 60.0 or casts > 0, "and it plays on its own: it covered %.0f px in ten seconds and was seen casting %d times" % [walked, casts])
		await _try_a_page(world, "the first world")
		var first_scene := get_tree().current_scene
		await _until(func() -> bool: return get_tree().current_scene != first_scene or not is_instance_valid(first_scene), "the first world to collapse")  # the portal collapses into the next world
		world = await _scene(WORLD)
		await _until(func() -> bool: return Net.peers_here().size() == 1, "the server in the second world")
		await _seconds(4.0)
		await _try_a_page(world, "the second world")
		# The client leaves: with nobody left, the server ends the match and waits in the room, where a newcomer finds it.
		Net.leave()
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		await _seconds(8.0)
		await _into_the_room(2)
		_check(Net.is_here(1), "a newcomer finds the server back in the waiting room")


	## The client walks to a page and reads it: the server (which says who reads which) must answer, the page leave the ground and enter the book.
	func _try_a_page(world: Node, where: String) -> void:
		var target: PagePickup
		var name_of := ""
		for attempt in 5:  # (a rival may read the page it was going to while it waits to get there: then it takes another)
			target = null
			for pickup: PagePickup in get_tree().get_nodes_in_group("pages"):
				if not pickup.is_queued_for_deletion() and not pickup is Mirage and pickup.gives(world.player.ledger):
					target = pickup
					break
			if target == null:
				_check(false, "%s: there is a page to read" % where)
				return
			name_of = String(target.name)
			world.player.global_position = target.global_position + Vector2(0, -20)
			await _seconds(0.5)
			if is_instance_valid(target) and not target.is_queued_for_deletion():
				break
			target = null
		if target == null:
			_check(false, "%s: every page it went to was read by someone else first" % where)
			return
		world.read_page(target, world.player)  # (asked once: a request the server drops is a failure to be found, not asked again)
		var waited := 0.0
		while waited < 12.0 and not (world.get_node_or_null(NodePath(name_of)) == null or world.get_node(NodePath(name_of)).is_queued_for_deletion()):
			await _seconds(0.25)
			waited += 0.25
		var gone := world.get_node_or_null(NodePath(name_of)) == null or world.get_node(NodePath(name_of)).is_queued_for_deletion()
		_check(gone, "%s: the page %s is read and gone from the ground" % [where, name_of])










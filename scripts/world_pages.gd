class_name WorldPages
extends RefCounted

## The pages of a world: where they lie (the map's, the clusters the wizards start by, the sky's rising ones), the book a fallen wizard leaves, and the
## host's reminder of which still lie.

## How many tiles apart the pages of a cluster lie, and the farthest from the spawn they may lie.
const CLUSTER_GAP := 3
const CLUSTER_REACH := 30
const PAGES_TOLD_EVERY := 3.0

var _told := 0.0

var world: World


func _init(owner: World) -> void:
	world = owner


## The spellbook of the run: only the starter spells are known, and a page for each of the others lies in a hall of the map.
func lay() -> void:
	world.ledgers = MatchState.ledgers if world.carried else Pages.start_empty(World.WIZARDS)  # nobody starts with a spell: the pages they would have started with lie by their spawn
	MatchState.ledgers = world.ledgers
	world.player.ledger = world.ledgers[world.my_seat()]
	world.spellbook.refresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed_value + 7919  # the pages come from the seed, apart from the rest of the map
	var gate_kinds := []
	for entry in world.gates:
		if not gate_kinds.has(entry["kind"]):
			gate_kinds.append(entry["kind"])
	# What lies in a world was settled when the match began: each world has pages of its own, apart from the ones the wizards were dealt.
	var allotment := MatchState.page_allotment(World.WIZARDS)
	var spare: Array[String] = []
	spare.assign(allotment["spare"])
	var layout := Pages.plan(world.graph, rng, Pages.deal(MatchState.seed_base + 31, World.WIZARDS), allotment["worlds"][MatchState.stage], gate_kinds, spare, world.ledgers if world.carried else Pages.deal(MatchState.seed_base + 31, World.WIZARDS))  # (the pages in the clusters count as held, for the gates' openers)
	if world.flies():
		_lay_sky(layout)
		if not world.carried:
			_lay_clusters(layout.size())
		return
	var count := {}
	for index in layout.size():
		var entry: Dictionary = layout[index]
		var room: int = entry["room"]
		var pickup := PagePickup.new()
		pickup.name = "Page%d" % index  # the same on every machine, so the host can say which was read
		pickup.page = entry["page"]
		if entry.has("castle"):  # up in the castle: a column from its west end, and the floor's height in rows
			var spot: Vector2i = entry["castle"]
			var castle_at: int = entry["castle_x"]
			pickup.position = Vector2((castle_at + spot.x + 0.5) * World.TILE, (WorldGraph.SURFACE_ROW - spot.y) * World.TILE)
			world.add_child(pickup)
			continue
		if entry.has("x"):  # out on the surface, near the start
			var column: int = entry["x"]
			var tree := _tree_at(column)
			if not tree.is_empty():  # on the branch of a great tree
				pickup.position = Vector2((column + 0.5) * World.TILE, world.graph.surface["floor"][column] * float(World.TILE) + 2.0) + JungleTree.perch(tree["size"], tree["mirror"])
				world.add_child(pickup)
				continue
			pickup.position = world.floor_under(Vector2((column + 0.5) * World.TILE, world.graph.surface["floor"][column] * World.TILE - 40.0))
			world.add_child(pickup)
			continue
		var spot := world.stand_at(world.markers[room])
		var k: int = count.get(room, 0)
		count[room] = k + 1
		var lie := spot + Vector2((k - 0.5) * 70.0 if k > 0 else 0.0, 0.0)
		pickup.position = world.floor_under(lie)  # on the floor, wherever the marker's tile ends
		world.add_child(pickup)
	if not world.carried:
		_lay_clusters(layout.size())


## The sky's pages: each starts somewhere in the air and rises through the falling wizards, round and round (FallingPage).
func _lay_sky(layout: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed_value + 7933
	var box := world.fly_box()
	for index in layout.size():
		var pickup := FallingPage.new()
		pickup.name = "Page%d" % index  # the same on every machine, so the host can say which was read
		pickup.page = layout[index]["page"]
		pickup.rate = rng.randf_range(FallingPage.RATE_LEAST, FallingPage.RATE_MOST)
		var shown_at := rng.randf_range(box.position.y + 120.0, box.end.y - 120.0)
		pickup.home = Vector2(rng.randf_range(box.position.x + 600.0, box.end.x - 600.0), shown_at + PagePickup.FLOAT)
		pickup.box = box
		world.scenery.timed.append(pickup)
		world.add_child(pickup)


## In the first world, the pages each wizard would have started with lie together by their spawn, fanned out like cards, a short walk away on level
## ground, so nobody needs a spell to reach them. `first` numbers the pages after the ones the map already has.
func _lay_clusters(first: int) -> void:
	var places := world.places()
	var index := first
	for seat in World.WIZARDS:
		var pages := Pages.cluster_of(MatchState.seed_base, seat, World.WIZARDS)
		if pages.is_empty():
			continue
		if world.flies():
			var floating := FallingPage.new()  # in the sky they hang by the place, and do not drift
			floating.name = "Page%d" % index
			index += 1
			floating.page = pages[0]
			floating.spoils.assign(pages)
			floating.fan = true
			floating.home = places[seat] + Vector2(180.0, PagePickup.FLOAT - 40.0)
			floating.rate = 0.0
			floating.box = world.fly_box()
			world.scenery.timed.append(floating)
			world.add_child(floating)
			continue
		var pickup := PagePickup.new()  # all of a wizard's first pages lie together, fanned out like cards, and one read takes them all
		pickup.name = "Page%d" % index  # the same on every machine, so the host can say which was read
		index += 1
		pickup.page = pages[0]
		pickup.spoils.assign(pages)
		pickup.fan = true
		pickup.position = _cluster_spots(places[seat], 1)[0]
		world.add_child(pickup)


## Where `count` pages may lie by a spawn: on the ground a wizard can walk to without a jump, nearest first, a few tiles apart. A spawn with
## too little room round it gets the rest set down on the last spot, a little to one side of each other.
func _cluster_spots(origin: Vector2, count: int) -> Array[Vector2]:
	var feet := world.floor_under(origin - Vector2(0.0, 8.0))
	var column := floori(origin.x / World.TILE)
	var reachable: Array[Vector2] = []  # the floor at each column a wizard can walk to, nearest first
	for side in [1, -1]:
		var last := feet
		for step in range(1, CLUSTER_REACH):
			var at: int = column + step * side
			var floor_at := world.floor_under(Vector2((at + 0.5) * World.TILE, last.y - 8.0))
			if absf(floor_at.y - last.y) > World.TILE or absf(floor_at.y - feet.y) > World.TILE * 3.0:
				break  # a step too high, or a drop, ends the walk
			if world.in_rock(Vector2(floor_at.x, floor_at.y - 24.0)) or world.in_rock(Vector2(floor_at.x, floor_at.y - 56.0)):
				break  # a wall, or a low ceiling
			if absf(floor_at.y - world.graph.surface["floor"][clampi(at, 0, world.graph.surface["floor"].size() - 1)] * float(World.TILE)) < World.TILE * 2.5 and Pages.in_the_way(world.graph, at):
				break  # a pool, a pit of mud or a thicket
			last = floor_at
			reachable.append(floor_at)
	reachable.sort_custom(func(a: Vector2, b: Vector2) -> bool: return absf(a.x - origin.x) < absf(b.x - origin.x))
	var out: Array[Vector2] = []
	for spot in reachable:
		var gap_ok := true
		for other in out:
			gap_ok = gap_ok and absf(other.x - spot.x) >= CLUSTER_GAP * World.TILE - 1.0
		if gap_ok and absf(spot.x - origin.x) >= (CLUSTER_GAP - 1) * World.TILE:
			out.append(spot)
		if out.size() == count:
			break
	while out.size() < count:  # no room: the rest lie on the spots there are, or on the spawn's own floor
		var base := out[out.size() % maxi(out.size(), 1)] if not out.is_empty() else feet
		out.append(base + Vector2((out.size() % 3 - 1) * 48.0, 0.0))
	return out


func drop(wizard: Wizard) -> void:
	var held: Array[String] = []
	for each: String in wizard.ledger.pages:
		held.append(each)
	if held.is_empty():
		return
	var spot := wizard.global_position + Vector2(0.0, 40.0) if world.flies() else world.on_ridge(wizard.global_position, world.floor_under(wizard.global_position))  # on a ridge, the book lies on it; in the sky it hangs where they fell
	var name := "Spoils" + String(wizard.name)
	lay_spoils(name, held, spot)
	Net.send(world, &"_lay_spoils", [name, held, spot])


## The host says every few seconds which pages still lie, because a page read while a machine was still loading the world is never heard of
## there, and would lie on its screen for ever, out of reach. A machine takes off the ground any page that is not on the list.
func tell_left(delta: float) -> void:
	_told += delta
	if _told < PAGES_TOLD_EVERY or not Net.online():
		return
	_told = 0.0
	var names: Array[String] = []
	for pickup: PagePickup in world.get_tree().get_nodes_in_group("pages"):
		if not pickup is Mirage and not pickup.is_queued_for_deletion():
			names.append(String(pickup.name))
	Net.send(world, &"_pages_left", [names])


## The large jungle tree that stands at this column, or an empty dictionary.
func _tree_at(column: int) -> Dictionary:
	for tree: Dictionary in world.graph.surface["trees"]:
		if tree["column"] == column and tree["size"] >= 2:
			return tree
	return {}


func left(names: Array) -> void:
	for pickup: PagePickup in world.get_tree().get_nodes_in_group("pages"):
		if not pickup is Mirage and not names.has(String(pickup.name)):
			pickup.queue_free()



## A fallen wizard's book lies where it fell.
func lay_spoils(pickup_name: String, held: Array, spot: Vector2) -> void:
	var pickup := PagePickup.new()
	pickup.name = pickup_name
	pickup.page = held[0]
	pickup.spoils.assign(held)
	pickup.position = spot
	world.add_child(pickup)

class_name WorldSeats
extends RefCounted

## The seats of a match: which wizard sits where, who plays it (a person on this machine, a person on another, or a brain) and how the match goes on when one
## leaves or falls. The wizards themselves are in `world.seats`; this works out where they start and watches over them.

var world: World

var _fallen := {}  # on the host: the wizards whose fall has been seen, and whose pages have been dropped


func _init(owner: World) -> void:
	world = owner


## The player's seat in the match. Playing alone it is the first, and brains have the other three; in a network game the people have
## the first seats in the order they joined (see Net.roster), and brains the rest. Each seat has its look, its ledger and its place.
func my_seat() -> int:
	return maxi(Net.seat_of(Net.my_id()), 0) if Net.online() else 0


## Where each seat starts, in the world. Playing alone the player has a place of their own and the others the places farthest from it,
## in an order drawn from the seed; in a network game every seat's place is drawn from the seed, so every machine agrees on them.
func places() -> Array[Vector2]:
	var places := world.spawn_tiles.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed_value + 4421
	var out: Array[Vector2] = []
	if Net.online():
		for k in range(places.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var swap: Vector2i = places[k]
			places[k] = places[j]
			places[j] = swap
		for seat in world.WIZARDS:
			out.append(world.stand_at(places[seat % places.size()]))
		return out
	places.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return absi(a.x - world.start_tile.x) > absi(b.x - world.start_tile.x))
	for k in range(world.WIZARDS - 2, 0, -1):  # which look starts where is drawn from the seed (the nearest place is the player's own, and stays last): the one between the others has the hardest start
		var j := rng.randi_range(0, k)
		var swap: Vector2i = places[k]
		places[k] = places[j]
		places[j] = swap
	out.append(world.stand_at(world.start_tile))
	for i in world.WIZARDS - 1:
		out.append(world.stand_at(places[i]))
	return out


## The other wizards, each at its seat's place holding the pages its seat was dealt: the people on other machines, and brains in the
## seats nobody took. The host plays the brains; every other machine has a likeness of each.
func spawn() -> void:
	var places := places()
	for seat in world.WIZARDS:
		if seat == my_seat():
			world.seats.append(world.player)
			continue
		var state: Dictionary = MatchState.vitals[seat] if world.carried else {"alive": true}
		var person := Net.roster[seat] if Net.online() and seat < Net.roster.size() else -1
		if person == 0 or (person < 0 and not state["alive"]):  # a seat whose person left, or a brain beaten in an earlier world
			world.seats.append(null)
			continue
		var wizard: Wizard
		if person > 0:
			wizard = world.add_person(person, places[seat])
			if not state["alive"]:
				wizard.stay_fallen()  # beaten in an earlier world: it watches, unseen
		elif Net.online() and not Net.is_host():
			wizard = _brains_likeness(seat, places[seat])
		else:
			wizard = world.add_wizard(Net.rival_look(seat), places[seat], "Rival%d" % seat)
			wizard.palette = Net.rival_palette(seat)
			wizard.nav = world.nav
			if state.has("max"):
				wizard.max_stamina = state["max"]
				wizard.stamina = state["stamina"]
		wizard.ledger = world.ledgers[seat]
		world.seats.append(wizard)
	for wizard in world.seats:
		if wizard != world.player:
			world.rivals.append(wizard)
	if Net.online():
		Net.roster_changed.connect(on_roster_changed)


## On a dedicated server nobody is at the machine: its wizard, in the first seat, plays on its own, as the brains of the empty seats do.
func give_player_to_a_brain() -> void:
	world.player.human = false
	world.player.ensure_caster()  # (it casts through a caster of its own, as a brain's wizard does)
	world.player.brain = world.new_brain(world.player)
	world.player.nav = world.nav


## On a machine other than the host: a likeness of the wizard a brain plays in a seat, on the host.
func _brains_likeness(seat: int, feet: Vector2) -> Wizard:
	var wizard: Wizard = world.WIZARD_SCENE.instantiate()
	wizard.name = "Rival%d" % seat
	wizard.peer = 1
	wizard.human = false
	wizard.look = Net.rival_look(seat)
	wizard.palette = Net.rival_palette(seat)
	wizard.position = feet
	world.add_child(wizard)
	wizard.share()
	return wizard


## Someone left the game: their wizard falls where it stands, on every machine.
func on_roster_changed() -> void:
	if Net.dedicated and not world.match_end.won and Net.roster.all(func(peer: int) -> bool: return peer == 0 or peer == Net.my_id()):
		world.match_end.won = true  # the last person has left: the brains would only play on to themselves, so the server goes back to the waiting room for the next people
		world.get_tree().create_timer(2.0).timeout.connect(world.match_end.back_to_room)
		return
	for wizard in world.rivals:
		if is_instance_valid(wizard) and wizard.human and wizard.is_likeness() and not Net.roster.has(wizard.peer) and not wizard.dead:
			wizard.abandon()


## On the host: a wizard that has fallen leaves its whole book where it fell, for anyone to read, on every machine.
func watch_falls() -> void:
	for seat in world.seats.size():
		var wizard := world.seats[seat]
		if not is_instance_valid(wizard) or not wizard.dead or _fallen.has(wizard):
			continue
		_fallen[wizard] = true
		if not world.carried or MatchState.vitals[seat]["alive"]:  # one beaten in an earlier world dropped its book there
			world.pages.drop(wizard)

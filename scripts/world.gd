class_name World
extends "res://scripts/arena.gd"

## A generated world: a web of halls joined by tunnels, built from a seed (see WorldGraph and WorldBuilder).
## Enemies, pages and gates come later. The player
## starts in the start hall and can walk to every other one. The seed is shown on screen as its incantation.

## The seed to build from. The waiting room's portal sets it before the world loads; a world opened directly gets a random one.
static var next_seed := -1

const WIZARDS := 4  # the wizards in a world: the player and three more
const PortalCollapse := preload("res://scripts/portal_collapse.gd")

var seed_value := 0
var ledgers: Array[Ledger] = []  # the pages each wizard holds, the player's first
var graph: WorldGraph
var _markers := {}
var _ponds := []
var _gates := []
var _built: Dictionary  # what the generator made, kept to build the ways again when a gate is cleared
var _since_gates := 0.0
var _castle_stairs := []  # [{"from", "to": the ends of the slope in pixels, "under"}]: its stairs to the cellars
var _weather: Array[Weather] = []
var _gale: MountainGale  # the snowy peaks' wind, when this world has it
var _gates_open := false
const DEEP := Color(0.3, 0.27, 0.42)  # the colour of everything unlit, just under the ground
const BLACK := Color(0.015, 0.015, 0.03)  # and far down: nothing shows without a light
const DARKEN_ROWS := 16.0  # how far under the surface it takes for the light of the day to fade
const BLACKEN_ROWS := 110.0  # and for the dark to become total

var _dark: CanvasModulate
static var random_start := true  # the player starts at any one of the starting places; the showcase and tests turn this off to see the same place each time
var castle_x := -1  # the first column of the first castle on the surface, or -1 when there is none


## The world's tiles, built from the seed. Everything the generator decides comes from this one rng.
func _build_map() -> Variant:
	seed_value = next_seed if next_seed >= 0 else randi() % Incantation.seed_count()
	next_seed = -1
	_carried = MatchState.pending  # a world the last one collapsed into: the match goes on, rather than begins
	MatchState.pending = false
	if not _carried:
		MatchState.begin(seed_value)
	var stage := MatchState.plan()
	WorldGraph.size = Vector2i(stage["width"], MatchState.HEIGHT)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var built := WorldBuilder.make(rng, stage["biome"], stage["caves"])
	graph = built["graph"]
	_markers = built["markers"]
	_ponds = built["ponds"]
	_gates = built["gates"]
	_built = built
	add_to_group(&"world")
	castle_x = built["castle"]
	ArenaGen.world_size = built["size"]
	ArenaGen.sky_xl = built["sky"]["xl"]
	ArenaGen.sky_floor = built["sky"]["floor"] if not built["roofed"] else PackedInt32Array()  # under a roof there is no sky
	ArenaGen.biome_spans = []
	for biome in graph.surface["biomes"]:
		var span := {"a": biome["a"], "b": biome["b"], "tiles": SurfaceGen.LOOKS[biome["name"]]["tiles"]}
		if SurfaceGen.LOOKS[biome["name"]].has("snow"):
			span["snow"] = SurfaceGen.LOOKS[biome["name"]]["snow"]  # above this many rows over the plains, the ground is snow
		ArenaGen.biome_spans.append(span)
	ArenaGen.castle_hall = built["hall"]
	ArenaGen.castle_steps = []
	for run: Dictionary in built["stairs"]:
		ArenaGen.castle_steps.append_array(run["under"])
	_castle_stairs = built["stairs"]
	tiled_ground = true
	_start_tile = built["start"]
	_spawn_tiles = built["spawns"]
	if random_start and not Net.online():
		_start_tile = _spawn_tiles[randi() % _spawn_tiles.size()]  # not seeded, so the same world starts you somewhere new
	var shut := WorldBuilder.shut(built, true)
	nav = WorldNav.new()
	nav.build(shut["cells"], built["size"].y, shut["barred"], _spawn_tiles[0], shut["tolls"], shut["links"], shut["climbs"])
	return built["cells"]


const THORN_CHUNK := 5  # tiles of floor in a thicket of the world
const BACK_TO_ROOM := 10.0  # seconds after a network match is won before everyone is back in the waiting room
var nav: WorldNav  # the ways about the world on foot, with every gate shut
var _start_tile := Vector2i.ZERO
var _spawn_tiles: Array[Vector2i] = []  # the starting places, far apart; the player takes one and a wizard each of the others
var _since_count := 0.0
var _won := false
var _watched := 0  # while out of the match: which of the other wizards the camera follows
var _spectating := false
var _tear: Node2D  # the portal giving way, while it does
var _pulling := false
var _carried := false      # the match goes on from a world that collapsed: its ledgers and wizards come with it
var _stage_time := 0.0     # seconds in this world
var _leaving := false      # the portal has given way
var _collapse_in := -1.0   # seconds until the portal gives way, once it has begun to
var _seats: Array[Wizard] = []  # every wizard of the match by seat (see _my_seat), the player's own among them; null where one was beaten in an earlier world
var _rivals: Array[Wizard] = []  # the same, without the player's own
var _fallen := {}  # on the host: the wizards whose fall has been seen, and whose pages have been dropped
var _backdrops := {}  # place -> Backdrop


## Each biome has a backdrop of its own, all of them in place at once and one shown at a time: walking from one biome to the next
## fades the sky and scenery of the one into the other, as Terraria does.
func _set_up_backdrops() -> void:
	for child in get_children():
		if child is Backdrop:
			child.queue_free()  # the one the arena made, which has no ground of its own to stand on
	var ground_y := float(SurfaceGen.BASE_ROW * TILE)
	for place in ["cemetery", "jungle", "mountains", "ashlands"]:
		var backdrop := Backdrop.new()
		add_child(backdrop)
		move_child(backdrop, 0)
		backdrop.build(place, ground_y)
		backdrop.set_opacity(0.0)
		_backdrops[place] = backdrop
	var here := _backdrop_here()
	_backdrops[here].set_opacity(1.0)
	for i in 2:  # up to two kinds of weather at once: ash and the embers over it
		var weather := Weather.new()
		player.get_node("Camera2D").add_child(weather)
		_weather.append(weather)


## The weather of the biome the wizard stands in, thinning out as they go under the ground.
func _update_weather(under: float) -> void:
	var column := floori(player.global_position.x / TILE)
	var kinds: Array = SurfaceGen.LOOKS[SurfaceGen.biome_at(graph.surface, column)].get("weather", [])
	var strength := clampf(1.0 - (under + 2.0 * TILE) / (6.0 * TILE), 0.0, 1.0)
	if SurfaceGen.biome_at(graph.surface, column) == "mountains" and MountainGale.altitude(player.global_position.y) > 0.45:
		kinds = ["blizzard"]  # up near the summits the snow is a blizzard
	if _gale != null and SurfaceGen.biome_at(graph.surface, column) == "mountains":
		var push := MountainGale.push_at(player.global_position.y, _gale.seconds)
		if absf(push) > 12.0:  # and the wind is seen: streaks of snow blown along, the way it blows
			kinds = [kinds[0] if not kinds.is_empty() else "snow", "gale_east" if push > 0.0 else "gale_west"]
			strength = minf(strength, 1.0)
	for i in _weather.size():
		_weather[i].want_kind = kinds[i] if i < kinds.size() else ""
		_weather[i].want_strength = strength


func _backdrop_here() -> String:
	var column := floori(player.global_position.x / TILE)
	return SurfaceGen.LOOKS[SurfaceGen.biome_at(graph.surface, column)]["backdrop"]


## Fades the backdrop of the biome the wizard stands in up, and the others down.
func _fade_backdrops(delta: float) -> void:
	var here := _backdrop_here()
	for place: String in _backdrops:
		var backdrop: Backdrop = _backdrops[place]
		var amount: float = backdrop.modulate.a if backdrop.visible else 0.0
		backdrop.set_opacity(move_toward(amount, 1.0 if place == here else 0.0, delta * 0.7))


func _begin_encounter(camera: Camera2D) -> void:
	_lay_pages()
	_restore_player()
	player.position = _places()[_my_seat()]
	_safe_spot = player.position
	_spawn_wizards()
	_stay_out()
	_ground.watch([player.position], true)  # the rock round the start is drawn before the first frame
	camera.reset_smoothing()
	_set_up_backdrops()
	hud.set_title("")
	hud.set_pause_note("World: " + Incantation.words_for(seed_value))
	for entry in _ponds:
		var pond := Pond.new()
		pond.lava = entry["lava"]
		pond.width = (entry["b"] - entry["a"] + 1) * float(TILE)
		pond.depth = entry["depth"] * float(TILE) + 16.0
		pond.position = Vector2(entry["a"] * float(TILE), entry["surface"] * float(TILE))
		pond.clip = _ground.air_loops
		add_child(pond)
		if not entry["lava"] and SurfaceGen.biome_at(graph.surface, graph.surface["start"]) == "jungle":  # the jungle's water is full of piranhas
			var shoal := Piranhas.new()
			shoal.water = Rect2(pond.position, Vector2(pond.width, pond.depth))
			shoal.count = maxi(2, int(pond.width / (TILE * 4.0)))
			shoal.bed = graph.surface["floor"].slice(entry["a"], entry["b"] + 1)
			shoal.bed_x = entry["a"] * float(TILE)
			shoal.name = "Shoal%d" % entry["a"]
			add_child(shoal)
	_lay_landmarks()
	_raise_the_dead()
	_plant_graves()
	_grow_trees()
	_raise_the_gale()
	_wash_out_the_colour()
	if not _castle_stairs.is_empty():
		var slopes := StaticBody2D.new()
		slopes.collision_layer = 16  # a one-way platform: walk up it, land on top, and S drops through
		slopes.collision_mask = 0
		for entry: Dictionary in _castle_stairs:
			var slope := CollisionShape2D.new()
			var line := SegmentShape2D.new()
			line.a = entry["from"]
			line.b = entry["to"]
			slope.shape = line
			slope.one_way_collision = true
			slope.one_way_collision_margin = 6.0
			slopes.add_child(slope)
		add_child(slopes)
	for entry in _gates:
		match entry["kind"]:
			"brambles":
				_grow_thorns(entry)
			"ice":
				var plug := IcePlug.new()
				plug.columns = entry["columns"]
				add_child(plug)
				entry["nodes"] = [plug]
			"wall":
				var wall := RockWall.new()
				wall.columns = entry["columns"]
				add_child(wall)
				entry["nodes"] = [wall]
			"dark":
				var bed := SpikeBed.new()
				bed.strips = entry["strips"]
				add_child(bed)
			"gas":
				_spread_gas(entry)
			"sentinel":
				var statue := Sentinel.new()
				statue.position = Vector2(Vector2i(entry["stands"]) * TILE) + Vector2(TILE * 0.5, 0)
				add_child(statue)
				entry["post"] = statue
			"piranhas":
				var shoal := Piranhas.new()
				var pit: Rect2i = entry["pit"]
				shoal.water = Rect2(pit.position * TILE, Vector2(pit.size * TILE))
				shoal.count = pit.size.x / 3
				add_child(shoal)
				entry["nodes"] = [shoal]  # killed to a fish, the pit is open
	_name_gates()
	_dark = CanvasModulate.new()  # under the ground it is dark; only fire and the flare light the way
	_dark.add_to_group("darkness")
	add_child(_dark)
	get_tree().node_added.connect(_on_node_added)


## The landmarks of an open biome: the craters of the ashlands' volcanoes, the jungle's pits of mud and thickets of thorns.
func _lay_landmarks() -> void:
	var t := float(TILE)
	var floors: PackedInt32Array = graph.surface["floor"]
	for crater: Dictionary in graph.surface["craters"]:
		var eruption := Eruption.new()
		eruption.name = "Crater%d" % crater["x"]  # the same on every machine, so the host can tell the others when it wakes
		eruption.position = Vector2((crater["x"] + 0.5) * t, crater["row"] * t)
		add_child(eruption)
	for pit: Dictionary in graph.surface["mud"]:
		var mud := Mudslide.new()
		var middle: int = (pit["a"] + pit["b"]) / 2
		mud.width = (pit["b"] - pit["a"] + 1) * t
		mud.position = Vector2((pit["a"] + pit["b"] + 1) * 0.5 * t, floors[middle] * t)
		var heights := PackedFloat32Array()
		for i in Mudslide.SAMPLES:
			var column := clampi(pit["a"] + roundi(float(pit["b"] - pit["a"]) * i / (Mudslide.SAMPLES - 1)), 0, floors.size() - 1)
			heights.append(floors[column] * t - mud.position.y)
		mud.planted_ground = heights
		mud.modulate = Color(0.36, 0.42, 0.26)  # dark green-brown jungle mud, not the sand of the spell
		add_child(mud)
	for thicket: Dictionary in graph.surface["thorns"]:
		_grow_thorns({"floors": floors.slice(thicket["a"], thicket["b"] + 1), "first": thicket["a"]})


var _dead: Array[Mob] = []  # the roaming mobs (the graveyard's dead, the castle's giant), in the order the seed raised them: the host's move, the others' show
var _dead_sent := 0.0
const GRAVES := ["grave_1", "grave_2", "grave_3", "grave_4"]
## The graveyard's tombstones: one now and then along the whole ground, from the seed, leaning a little. They are only to be seen.
func _plant_graves() -> void:
	if SurfaceGen.biome_at(graph.surface, graph.surface["start"]) != "graveyard":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 1291
	var floors: PackedInt32Array = graph.surface["floor"]
	var column := SurfaceGen.MARGIN + 6
	while column < floors.size() - SurfaceGen.MARGIN - 6:
		var grave := Sprite2D.new()
		grave.texture = load("res://art/props/%s.png" % GRAVES[rng.randi() % GRAVES.size()])
		grave.offset = Vector2(0, -grave.texture.get_height() * 0.5 + 3.0)  # it stands on the ground
		grave.flip_h = rng.randf() < 0.5
		grave.rotation = rng.randf_range(-0.06, 0.06)
		grave.position = Vector2((column + 0.5) * TILE, floors[column] * float(TILE) + 2.0)
		grave.z_index = -1
		add_child(grave)
		column += rng.randi_range(3, 9)


## The jungle's great trees: one now and then along the ground, from the seed, where it is level and clear of the pits, the pools and the
## places the wizards start from. The large ones have a branch with a vine to climb to it.
func _grow_trees() -> void:
	var floors: PackedInt32Array = graph.surface["floor"]
	for entry: Dictionary in graph.surface["trees"]:
		var column: int = entry["column"]
		var tree := JungleTree.new()
		tree.size = entry["size"]
		tree.mirror = entry["mirror"]
		tree.vine_ground = float(floors[column + JungleTree.layout(tree.size, tree.mirror)["vine"]] - floors[column]) * TILE
		tree.position = Vector2((column + 0.5) * TILE, floors[column] * float(TILE) + 2.0)
		add_child(tree)


## The snowy peaks have wind that grows toward the summits, and clouds of snow drifting past.
func _raise_the_gale() -> void:
	if SurfaceGen.biome_at(graph.surface, graph.surface["start"]) != "mountains":
		return
	_gale = MountainGale.new()
	add_child(_gale)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 2713
	var width := WorldGraph.size.x * float(TILE)
	for k in WorldGraph.size.x / 45:
		var cloud := SnowCloud.new()
		cloud.position = Vector2(rng.randf_range(0.0, width), (SurfaceGen.BASE_ROW - rng.randf_range(10.0, 56.0)) * float(TILE))
		cloud.drift = rng.randf_range(18.0, 46.0)
		cloud.left = -300.0
		cloud.right = width + 300.0
		add_child(cloud)


## The graveyard is seen in grey: a layer over the world, under the interface, that takes the colour out of it.
func _wash_out_the_colour() -> void:
	if SurfaceGen.biome_at(graph.surface, graph.surface["start"]) != "graveyard":
		return
	var layer := CanvasLayer.new()
	layer.layer = 2
	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/grayscale.gdshader")
	wash.material = material
	layer.add_child(wash)
	add_child(layer)


const DEAD_PER_COLUMNS := 90  # the graveyard has a skeleton for this many columns of its width
const GIANT_ROOMS := [20, 66, 105, 120]  # columns from a castle's west end to the middle of a ground-floor room with open floor
const GIANT_PER_COLUMNS := 300  # the castle world has a giant for this many columns of its width
const DEAD_KEEP_AWAY := 45    # columns from every starting place that none rise
## On the host, tells the others a few times a second where each of the dead is, which way it faces and whether it is drawing back to strike.
func _share_the_dead(delta: float) -> void:
	if _dead.is_empty() or not Net.online() or not Net.is_host():
		return
	_dead_sent += delta
	if _dead_sent < 0.05:
		return
	_dead_sent = 0.0
	var places := PackedVector2Array()
	var faces := PackedFloat32Array()
	var swings := PackedByteArray()
	for mob in _dead:
		var here := is_instance_valid(mob) and not mob.is_dead()
		places.append(mob.global_position if here else Vector2.ZERO)
		faces.append(mob.facing if here else 1.0)
		swings.append(1 if here and mob.is_drawing_back() else 0)
	Net.send(self, &"_dead_at", [places, faces, swings])


@rpc("authority", "call_remote", "unreliable")
func _dead_at(places: PackedVector2Array, faces: PackedFloat32Array, swings: PackedByteArray) -> void:
	for k in mini(places.size(), _dead.size()):
		var mob := _dead[k]
		if is_instance_valid(mob) and not mob.is_dead():
			mob.net_position = places[k]
			mob.net_facing = faces[k]
			mob.net_swing = swings[k] == 1


## Some biomes have things that roam: the graveyard's dead walk it (skeletons), and the castle world has a giant that wanders between the
## castles. They amble about until the player comes near, then give chase. They rise from the ground at places the seed picks, and (like
## all of a world's mobs) only trouble the player of the machine they stand on.
func _raise_the_dead() -> void:
	var biome := SurfaceGen.biome_at(graph.surface, graph.surface["start"])
	if biome == "graveyard":
		_raise_roamers("basic", WorldGraph.size.x / DEAD_PER_COLUMNS, 4409)
	elif biome == "castle":
		_raise_roamers("giant", maxi(2, WorldGraph.size.x / GIANT_PER_COLUMNS), 6143)


func _raise_roamers(kind: String, wanted: int, salt: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + salt
	var castles: Array = graph.surface["castles"]
	var tries := 0
	while wanted > 0 and tries < 400:
		tries += 1
		var column := rng.randi_range(SurfaceGen.MARGIN + 10, WorldGraph.size.x - SurfaceGen.MARGIN - 10)
		if not castles.is_empty():  # in the castle world they walk the ground floors, in a room with a clear floor
			column = castles[rng.randi_range(0, castles.size() - 1)] + GIANT_ROOMS[rng.randi_range(0, GIANT_ROOMS.size() - 1)]
		var near := false
		for spawn in _spawn_tiles:
			near = near or absi(spawn.x - column) < DEAD_KEEP_AWAY
		if near:
			continue
		var mob: Mob = _add_mob(kind, _floor_under(Vector2((column + 0.5) * TILE, graph.surface["floor"][column] * TILE - 40.0)))
		mob.name = "Dead%d" % _dead.size()  # the same on every machine, so the host's can tell the others' puppets what it does
		mob.roams = true
		mob.puppet = not Net.is_host()
		_dead.append(mob)
		wanted -= 1


## Thorns over a stretch of a passage's floor, grown in thickets a few tiles long, so fire burns one thicket at a time and a way
## can be burnt through them. They are the thorns of the Bramble spell.
func _grow_thorns(entry: Dictionary) -> void:
	entry["nodes"] = []
	entry["per"] = THORN_CHUNK
	var floors: PackedInt32Array = entry["floors"]
	var first: int = entry["first"]
	var t := float(TILE)
	var chunk := THORN_CHUNK
	for start in range(0, floors.size(), chunk):
		var points := PackedVector2Array()
		var x: float = (first + start) * t
		var end: float = (first + mini(start + chunk, floors.size())) * t
		while x < end:
			var column := clampi(int(floor(x / t)) - first, 0, floors.size() - 1)
			points.append(Vector2(x, floors[column] * t))
			x += Bramble.SPACING
		var thorns := Bramble.new()
		thorns.planted_ground = points
		add_child(thorns)
		entry["nodes"].append(thorns)


## Banks of gas along a passage, each from the floor to the roof.
func _spread_gas(entry: Dictionary) -> void:
	entry["nodes"] = []
	entry["per"] = WorldBuilder.GAS_BANK
	for bank: Dictionary in entry["banks"]:
		var gas := GasBank.new()
		gas.column = bank["x"]
		gas.floors = bank["floors"]
		gas.tops = bank["tops"]
		add_child(gas)
		entry["nodes"].append(gas)


## Each world of a match is a scene of its own in a network game, so nothing about one is sent to a machine still in the last.
func _scene_name() -> String:
	return "world%d" % MatchState.stage


## The player's seat in the match. Playing alone it is the first, and brains have the other three; in a network game the people have
## the first seats in the order they joined (see Net.roster), and brains the rest. Each seat has its look, its ledger and its place.
func _my_seat() -> int:
	return maxi(Net.seat_of(Net.my_id()), 0) if Net.online() else 0


## Where each seat starts, in the world. Playing alone the player has a place of their own and the others the places farthest from it,
## in an order drawn from the seed; in a network game every seat's place is drawn from the seed, so every machine agrees on them.
func _places() -> Array[Vector2]:
	var places := _spawn_tiles.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 4421
	var out: Array[Vector2] = []
	if Net.online():
		for k in range(places.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var swap: Vector2i = places[k]
			places[k] = places[j]
			places[j] = swap
		for seat in WIZARDS:
			out.append(_stand_at(places[seat % places.size()]))
		return out
	places.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return absi(a.x - _start_tile.x) > absi(b.x - _start_tile.x))
	for k in range(WIZARDS - 2, 0, -1):  # which look starts where is drawn from the seed (the nearest place is the player's own, and stays last): the one between the others has the hardest start
		var j := rng.randi_range(0, k)
		var swap: Vector2i = places[k]
		places[k] = places[j]
		places[j] = swap
	out.append(_stand_at(_start_tile))
	for i in WIZARDS - 1:
		out.append(_stand_at(places[i]))
	return out


## The other wizards, each at its seat's place holding the pages its seat was dealt: the people on other machines, and brains in the
## seats nobody took. The host plays the brains; every other machine has a likeness of each.
func _spawn_wizards() -> void:
	var places := _places()
	for seat in WIZARDS:
		if seat == _my_seat():
			_seats.append(player)
			continue
		var state: Dictionary = MatchState.vitals[seat] if _carried else {"alive": true}
		var person := Net.roster[seat] if Net.online() and seat < Net.roster.size() else -1
		if person == 0 or (person < 0 and not state["alive"]):  # a seat whose person left, or a brain beaten in an earlier world
			_seats.append(null)
			continue
		var wizard: Wizard
		if person > 0:
			wizard = _add_person(person, places[seat])
			if not state["alive"]:
				wizard.stay_fallen()  # beaten in an earlier world: it watches, unseen
		elif Net.online() and not Net.is_host():
			wizard = _add_brains_likeness(seat, places[seat])
		else:
			wizard = _add_wizard(Net.LOOKS[seat], places[seat], "Rival%d" % seat)
			wizard.nav = nav
			if state.has("max"):
				wizard.max_stamina = state["max"]
				wizard.stamina = state["stamina"]
		wizard.ledger = ledgers[seat]
		_seats.append(wizard)
	for wizard in _seats:
		if wizard != player:
			_rivals.append(wizard)
	if Net.online():
		Net.roster_changed.connect(_on_roster_changed)


## On a machine other than the host: a likeness of the wizard a brain plays in a seat, on the host.
func _add_brains_likeness(seat: int, feet: Vector2) -> Wizard:
	var wizard: Wizard = WIZARD_SCENE.instantiate()
	wizard.name = "Rival%d" % seat
	wizard.peer = 1
	wizard.human = false
	wizard.look = Net.LOOKS[seat]
	wizard.position = feet
	add_child(wizard)
	wizard.share()
	return wizard


## Someone left the game: their wizard falls where it stands, on every machine.
func _on_roster_changed() -> void:
	for wizard in _rivals:
		if is_instance_valid(wizard) and wizard.human and wizard.is_likeness() and not Net.roster.has(wizard.peer) and not wizard.dead:
			wizard.abandon()


## On the host: a wizard that has fallen leaves its whole book where it fell, for anyone to read, on every machine.
func _watch_falls() -> void:
	for seat in _seats.size():
		var wizard := _seats[seat]
		if not is_instance_valid(wizard) or not wizard.dead or _fallen.has(wizard):
			continue
		_fallen[wizard] = true
		if not _carried or MatchState.vitals[seat]["alive"]:  # one beaten in an earlier world dropped its book there
			_drop_pages(wizard)


func _drop_pages(wizard: Wizard) -> void:
	var held: Array[String] = []
	for each: String in wizard.ledger.pages:
		held.append(each)
	if held.is_empty():
		return
	var spot := _floor_under(wizard.global_position)
	var name := "Spoils" + String(wizard.name)
	_lay_spoils(name, held, spot)
	Net.send(self, &"_lay_spoils", [name, held, spot])


## A fallen wizard's book lies where it fell.
@rpc("authority", "call_remote", "reliable")
func _lay_spoils(pickup_name: String, held: Array, spot: Vector2) -> void:
	var pickup := PagePickup.new()
	pickup.name = pickup_name
	pickup.page = held[0]
	pickup.spoils.assign(held)
	pickup.position = spot
	add_child(pickup)


## The world position of the floor of a tile, at its middle.
func _stand_at(tile: Vector2i) -> Vector2:
	return Vector2((tile.x + 0.5) * TILE, (tile.y + 1) * TILE)


var _safe_spot := Vector2.ZERO  # the last place the wizard stood on firm ground
var _buried := 0.0              # how long the wizard has been inside rock


## True when a point is inside rock or outside the world. The outlines that make the rock solid have no inside, so a body that
## gets in cannot be found by a physics query: the tiles are asked instead.
func _in_rock(point: Vector2) -> bool:
	var size := ArenaGen.world_size
	var cell := Vector2i(floori(point.x / TILE), floori(point.y / TILE))
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return true
	var material: int = _cells.material(cell)
	return material == ArenaGen.GROUND or material == ArenaGen.STONE


## A point inside the rock is lifted out of it first, so a spell drawn into a hill lands on top of it.
func _surface_under(point: Vector2) -> Vector2:
	if not _in_rock(point):
		return super._surface_under(point)
	return SpellTargets.solid_below(get_world_2d(), _lifted_out_of_rock(point) + Vector2(0.0, -8.0))


## A point inside rock moved straight up until it is in the open.
func _lifted_out_of_rock(point: Vector2) -> Vector2:
	var clear := point
	for step in 400:
		if not _in_rock(clear):
			break
		clear.y -= 8.0
	return clear


func _body_in_rock(at: Vector2) -> bool:
	for lift in [-24.0, -48.0]:  # not lower: on a slope the tiles stand a little above the smooth ground
		if _in_rock(at + Vector2(0.0, lift)):
			return true
	return false


## A teleport (Blink, Shadow Step) stops short of any rock: the path is walked back from its end to the first clear spot.
func _out_of_rock(start: Vector2, end: Vector2) -> Vector2:
	var steps := maxi(1, int(start.distance_to(end) / 8.0))
	for i in range(steps, -1, -1):
		var at := start.lerp(end, float(i) / steps)
		if not _body_in_rock(at):
			return at
	return start


## If the wizard ever ends up inside rock, or falls out of the world, they are put back on the last firm ground.
func _process(delta: float) -> void:
	super(delta)
	_ground.watch([player.global_position])  # the rock is drawn only round the wizard
	_fade_backdrops(delta)
	var column := floori(player.global_position.x / TILE) - ArenaGen.sky_xl
	var ground := ArenaGen.sky_floor[clampi(column, 0, ArenaGen.sky_floor.size() - 1)] if not ArenaGen.sky_floor.is_empty() else WorldGraph.SURFACE_ROW
	var under := player.global_position.y - (ground + 2) * TILE  # how far below the ground overhead
	var depth := clampf(under / (DARKEN_ROWS * TILE), 0.0, 1.0)
	var far := clampf((under - DARKEN_ROWS * TILE) / ((BLACKEN_ROWS - DARKEN_ROWS) * TILE), 0.0, 1.0)
	var day: Color = SurfaceGen.LOOKS[SurfaceGen.biome_at(graph.surface, column + ArenaGen.sky_xl)]["tint"]
	_dark.color = day.lerp(DEEP, depth).lerp(BLACK, far)
	_update_weather(under)
	_share_the_dead(delta)
	_count_wizards(delta)
	if Net.is_host():
		_watch_falls()
	_watch_portal(delta)
	_watch_gates(delta)
	if player.dead:
		_follow_watched()
		return
	if _pulling:
		return  # drawn up into the portal: the ground has no say
	if _body_in_rock(player.global_position) or player.global_position.y > ArenaGen.world_size.y * TILE:
		_buried += delta
		if _buried > 0.2:
			player.global_position = _safe_spot
			player.velocity = Vector2.ZERO
			player.reset_physics_interpolation()
			_buried = 0.0
	else:
		_buried = 0.0
		if player.is_on_floor():
			_safe_spot = player.global_position


func _make_light(radius: float, color: Color, energy: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = Fx.tex("light_01")
	light.texture_scale = radius * 2.0 / Fx.TEX_SIZE
	light.color = color
	light.energy = energy
	light.shadow_enabled = false
	return light


## Every fire lights the dark round it while it lasts, and lava glows.
func _on_node_added(node: Node) -> void:
	if node is Gateway or node is Pond or node is Hazard or node is Bonfire or node is Projectile or node is Firewall or node is FireBreath or node is LavaBall:
		_light_when_ready.call_deferred(node)


func _light_when_ready(node: Node) -> void:
	if is_instance_valid(node) and node is Gateway:
		node.add_child(_make_light(220.0, node.tint, 1.2))  # a portal glows in the dark in its own colour
		return
	if not is_instance_valid(node) or not node.is_in_group("fires"):
		return
	if node is Pond:
		var pond: Pond = node
		var glow := _make_light(maxf(pond.width, 160.0), Color(1.0, 0.5, 0.2), 0.9)
		glow.position = Vector2(pond.width * 0.5, 0.0)
		node.add_child(glow)
	else:
		node.add_child(_make_light(260.0, Color(1.0, 0.6, 0.25), 1.1))


## What the player has left of their stamina, from the world before.
func _restore_player() -> void:
	if not _carried:
		return
	var state: Dictionary = MatchState.vitals[_my_seat()]
	player.max_stamina = state["max"]
	player.stamina = state["stamina"]
	_fade_from_black()


## A wizard beaten in an earlier world is still out in this one, and watches.
func _stay_out() -> void:
	if _carried and not MatchState.vitals[_my_seat()]["alive"]:
		player.max_stamina = 1.0
		player.take_damage(1)


## The world comes out of the dark, after a collapse.
func _fade_from_black() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	add_child(layer)
	var tween := black.create_tween()
	tween.tween_property(black, "color:a", 0.0, 1.2)
	tween.tween_callback(layer.queue_free)


## Counts down to the collapse of the portal: the warning, the shaking, and then the new world.
func _watch_portal(delta: float) -> void:
	var seconds: float = MatchState.plan()["seconds"] * MatchState.hurry
	if seconds <= 0.0 or (player.dead and not _spectating):
		return
	_stage_time += delta
	if _collapse_in < 0.0 and _stage_time >= seconds - MatchState.WARNING and Net.is_host():  # in a network game the host's clock is the one that counts
		_begin_collapse()
		Net.send(self, &"_begin_collapse")
	if _collapse_in < 0.0:
		return
	_collapse_in -= delta
	GameCamera.shake_scene(get_tree(), 0.03 + 0.06 * (1.0 - _collapse_in / MatchState.WARNING))
	if not _pulling and _collapse_in <= PortalCollapse.PULL:
		_pulling = true
		caster.set_casting_enabled(false)
		ritual.cancel()
		_tear.pull(SpellTargets.wizards(get_tree()))  # everyone still standing
	if _collapse_in <= 0.0 and not _leaving:
		_collapse()



## The warning: the portal is growing unstable, and gives way in a little while.
@rpc("authority", "call_remote", "reliable")
func _begin_collapse() -> void:
	if _collapse_in >= 0.0:
		return
	_collapse_in = MatchState.WARNING
	hud.banner("The portal is growing unstable")
	Sfx.play("thunder", player.center(), -4.0)
	_tear = PortalCollapse.new()
	_tear.position = Vector2(ArenaGen.world_size.x * TILE * 0.5, 8.0 * TILE)  # high in the middle of the world
	add_child(_tear)


## The portal gives way: everyone who is left is thrown into the next world, smaller than this one.
## For the F1 panel: leaves for a world of the match now, as the collapse would (the one stood in too: it is built again).
func go_to_stage(at: int) -> void:
	if _leaving:
		return
	MatchState.stage = at - 1  # the collapse moves on to the next
	_collapse()


func _collapse() -> void:
	_leaving = true
	var state: Array[Dictionary] = []
	for wizard in _seats:
		if wizard == player:
			state.append({"alive": not player.dead, "max": player.max_stamina, "stamina": player.stamina})
		elif is_instance_valid(wizard) and not wizard.dead:
			state.append({"alive": true, "max": wizard.max_stamina, "stamina": wizard.stamina})
		else:
			state.append({"alive": false})
	next_seed = MatchState.advance(ledgers, state, Incantation.seed_count())
	_leave_network_scene()
	Sfx.play("portal_enter", player.center(), -2.0)
	var layer := CanvasLayer.new()
	layer.layer = 100
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	add_child(layer)
	var tween := black.create_tween()
	tween.tween_property(black, "color:a", 1.0, 0.7)
	tween.tween_callback(func() -> void:
		Loading.quiet = true
		get_tree().change_scene_to_file(Loading.SCREEN))


## Every half second: a gate whose ice, wall, thorns or gas are all gone is open, and the wizards' ways are built again without it.
func _watch_gates(delta: float) -> void:
	_since_gates += delta
	if _since_gates < 0.5:
		return
	_since_gates = 0.0
	var changed := false
	for entry in _gates:
		if entry.get("open", false) or not entry.has("nodes"):
			continue
		var gone: Array[bool] = []
		for node in entry["nodes"]:  # (untyped: it may be a freed object)
			gone.append(not is_instance_valid(node) or node.is_queued_for_deletion())
		if gone != entry.get("gone", []):
			entry["gone"] = gone
			changed = true
		if not gone.has(false):
			entry["open"] = true
	if changed:
		var shut := WorldBuilder.shut(_built, true)
		nav.build(shut["cells"], _built["size"].y, shut["barred"], _spawn_tiles[0], shut["tolls"], shut["links"], shut["climbs"])
		if Net.online() and Net.is_host():
			Net.send(self, &"_gates_cleared", [_cleared_gate_names()])


## Every piece of a gate has the same name on every machine, so the host can say which are gone.
func _name_gates() -> void:
	for g in _gates.size():
		var nodes: Array = _gates[g].get("nodes", [])
		for k in nodes.size():
			nodes[k].name = "Gate%d_%d" % [g, k]


## The names of the pieces of gates that are gone, here.
func _cleared_gate_names() -> Array[String]:
	var out: Array[String] = []
	for g in _gates.size():
		var nodes: Array = _gates[g].get("nodes", [])
		for k in nodes.size():
			if not is_instance_valid(nodes[k]) or nodes[k].is_queued_for_deletion():
				out.append("Gate%d_%d" % [g, k])
	return out


## In a network game each machine runs the gates for itself, so a spell that clears one on the host's might just miss on another's. The
## host's are the ones that count: what is gone there goes here too.
@rpc("authority", "call_remote", "reliable")
func _gates_cleared(names: Array) -> void:
	for gate_name: String in names:
		var piece := get_node_or_null(NodePath(gate_name))
		if piece != null and not piece.is_queued_for_deletion():
			piece.queue_free()


## The gates that spells can clear and have not yet: {"kind", "outside": a floor tile just short of it, "target": a point in pixels to strike}.
func closed_gates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in _gates:
		if entry.get("open", false) or not entry.has("nodes"):
			continue
		out.append({"kind": entry["kind"], "outside": entry["outside"], "target": gate_target(entry), "entry": entry})
	return out


## The gates that a spell lets a wizard past, and does not clear: {"kind", "key" (see WorldNav.toll_at), "span": the top of a pit, a wall or a stretch of gas in pixels, "post": a sentinel}.
func crossings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in _gates:
		if entry["kind"] not in WorldBuilder.CROSSINGS:
			continue
		var found := {"kind": entry["kind"], "key": WorldBuilder.toll_key(entry), "post": entry.get("post")}
		if entry.has("pit") or entry["kind"] in ["chasm", "flood"]:
			var rect: Rect2i = entry["solve"][0]["rect"]
			found["span"] = Rect2(Vector2(rect.position * TILE), Vector2(rect.size * TILE))
		elif entry["kind"] == "gas":
			var stretch: Array = entry["blocks"]
			var first_tile: Vector2i = stretch[0]
			found["span"] = Rect2(Vector2(first_tile * TILE), Vector2(stretch.size() * TILE, TILE))
		elif entry["kind"] == "wall":
			var columns: Array = entry["columns"]
			found["span"] = Rect2(Vector2(columns[0]["x"] * TILE, columns[0]["top"] * TILE), Vector2(columns.size() * TILE, (columns[0]["bottom"] - columns[0]["top"]) * TILE))
		out.append(found)
	return out


## The point of a gate to strike: the part of it that is nearest the side one comes by, of what is left of it.
func gate_target(entry: Dictionary) -> Vector2:
	var t := float(TILE)
	var outside: Vector2i = entry["outside"]
	match entry["kind"]:
		"brambles":
			var first: int = entry["first"]
			var floors: PackedInt32Array = entry["floors"]
			var best := -1  # the thicket nearest the way in, of those still standing
			for k in entry["nodes"].size():
				var node = entry["nodes"][k]
				if is_instance_valid(node) and not node.is_queued_for_deletion():
					var middle := mini(k * THORN_CHUNK + THORN_CHUNK / 2, floors.size() - 1)
					var kept := mini(best * THORN_CHUNK + THORN_CHUNK / 2, floors.size() - 1)
					if best < 0 or absi(first + middle - outside.x) < absi(first + kept - outside.x):
						best = k
			var column := mini(maxi(best, 0) * THORN_CHUNK + THORN_CHUNK / 2, floors.size() - 1)
			return Vector2((first + column + 0.5) * t, floors[column] * t - 17.0)
		"gas":
			var best := -1
			for k in entry["banks"].size():
				var node = entry["nodes"][k]
				if not is_instance_valid(node) or node.is_queued_for_deletion():
					continue
				if best < 0 or absi(entry["banks"][k]["x"] - outside.x) < absi(entry["banks"][best]["x"] - outside.x):
					best = k
			var bank: Dictionary = entry["banks"][maxi(best, 0)]
			return Vector2((bank["x"] + 0.5) * t, (bank["floors"][0] + bank["tops"][0]) * 0.5 * t)
	if entry["kind"] == "piranhas":  # the water over the fish that is nearest the way in
		if not is_instance_valid(entry["nodes"][0]):  # shocked to the last fish
			return Vector2((outside.x + 0.5) * t, outside.y * t)
		var shoal: Piranhas = entry["nodes"][0]
		return Vector2(shoal.fish_x_near(outside.x * t), (entry["pit"] as Rect2i).position.y * t + 8.0)
	var best: Dictionary = entry["columns"][0]  # ice and wall: a column of it
	for column: Dictionary in entry["columns"]:
		if absi(column["x"] - outside.x) < absi(best["x"] - outside.x):
			best = column
	return Vector2((best["x"] + 0.5) * t, (best["top"] + best["bottom"]) * 0.5 * t)


## Out of the match: while other wizards still live the match goes on, and the camera follows one of them. Otherwise the run is over.
func _on_player_died() -> void:
	if _living().is_empty():
		_end_run()
		return
	caster.set_casting_enabled(false)
	ritual.cancel()
	Sfx.play("game_over")
	_spectating = true
	player.collision_layer = 0
	player.collision_mask = 0
	player.hide()
	hud.banner("", "Click to watch another wizard")


## The wizards still in the match, other than the player.
func _living() -> Array[Wizard]:
	var out: Array[Wizard] = []
	for rival in _rivals:
		if is_instance_valid(rival) and not rival.dead:
			out.append(rival)
	return out


## The camera goes where the watched wizard is: the body of the player, hidden, is moved there.
func _follow_watched() -> void:
	if not _spectating:
		return
	var living := _living()
	if living.is_empty():
		_spectating = false
		_end_run()  # the last of the rivals fell too: nobody is left to watch
		return
	_watched = _watched % living.size()
	player.global_position = living[_watched].global_position
	player.velocity = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if _spectating and click and click.pressed:
		_watched += 1  # the next one


func _count_wizards(delta: float) -> void:
	_since_count += delta
	if _since_count < 0.5 or _won:
		return
	_since_count = 0.0
	var standing := SpellTargets.wizards(get_tree())
	if standing.size() == 1 and standing[0] == player:
		_won = true
		hud.banner("Last wizard standing", "You win")
		Sfx.play("ritual_ok", player.center())
	if standing.size() <= 1 and Net.online() and Net.is_host():
		_won = true
		get_tree().create_timer(BACK_TO_ROOM).timeout.connect(_back_to_room)  # the match is over: everyone goes back to the waiting room


## The end of a network match: everyone is back in the waiting room, for the next one.
@rpc("authority", "call_remote", "reliable")
func _back_to_room() -> void:
	if not is_inside_tree():
		return
	if Net.is_host():
		Net.send(self, &"_back_to_room")
	_leave_network_scene()
	World.next_seed = -1
	var layer := CanvasLayer.new()
	layer.layer = 100
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	add_child(layer)
	var tween := black.create_tween()
	tween.tween_property(black, "color:a", 1.0, 0.8)
	tween.tween_callback(get_tree().change_scene_to_file.bind("res://scenes/lab.tscn"))


## A Rift sets the wizard down in another hall, picked by chance, and none behind a gate.
func _rift_spot(from: Vector2) -> Vector2:
	var spots: Array[Vector2] = []
	for room in graph.rooms:
		if room["lock"] != -1 and not _gates_open:
			continue
		var spot := _stand_at(_markers[room["id"]])
		if spot.distance_to(from) > 400.0:
			spots.append(spot)
	return spots[randi() % spots.size()] if not spots.is_empty() else from


## The spellbook of the run: only the starter spells are known, and a page for each of the others lies in a hall of the map.
func _lay_pages() -> void:
	ledgers = MatchState.ledgers if _carried else Pages.deal(seed_value + 31, WIZARDS)  # what each wizard starts with comes from the seed too
	MatchState.ledgers = ledgers
	player.ledger = ledgers[_my_seat()]
	spellbook.refresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7919  # the pages come from the seed, apart from the rest of the map
	var layout := Pages.plan(graph, rng, ledgers)
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
			pickup.position = Vector2((castle_at + spot.x + 0.5) * TILE, (WorldGraph.SURFACE_ROW - spot.y) * TILE)
			add_child(pickup)
			continue
		if entry.has("x"):  # out on the surface, near the start
			var column: int = entry["x"]
			var tree := _tree_at(column)
			if not tree.is_empty():  # on the branch of a great tree
				pickup.position = Vector2((column + 0.5) * TILE, graph.surface["floor"][column] * float(TILE) + 2.0) + JungleTree.perch(tree["size"], tree["mirror"])
				add_child(pickup)
				continue
			pickup.position = _floor_under(Vector2((column + 0.5) * TILE, graph.surface["floor"][column] * TILE - 40.0))
			add_child(pickup)
			continue
		var spot := _stand_at(_markers[room])
		var k: int = count.get(room, 0)
		count[room] = k + 1
		var lie := spot + Vector2((k - 0.5) * 70.0 if k > 0 else 0.0, 0.0)
		pickup.position = _floor_under(lie)  # on the floor, wherever the marker's tile ends
		add_child(pickup)


## The large jungle tree that stands at this column, or an empty dictionary.
func _tree_at(column: int) -> Dictionary:
	for tree: Dictionary in graph.surface["trees"]:
		if tree["column"] == column and tree["size"] >= 2:
			return tree
	return {}


## The top of the floor under a point (out of the rock first when it is in it), asked of the tiles, which are there before the ground is built.
func _floor_under(point: Vector2) -> Vector2:
	var x := point.x
	var row := floori((point.y - 1.0) / TILE)
	while row > 0 and _in_rock(Vector2(x, (row + 0.5) * TILE)):
		row -= 1
	while row < ArenaGen.world_size.y - 1 and not _in_rock(Vector2(x, (row + 1.5) * TILE)):
		row += 1
	return Vector2(x, (row + 1) * TILE)


## The kinds of gate this world has, for the F1 panel.
func gate_kinds() -> Array:
	var kinds := []
	for entry in _gates:
		if not kinds.has(entry["kind"]):
			kinds.append(entry["kind"])
	return kinds


var _tour := {}  # kind -> how many times the panel has gone to a gate of that kind, so each press goes to the next one

## Sets the wizard down on the floor just outside a gate of this kind, on the way in from the open side. Each press goes to the next.
func go_to_gate(kind: String) -> void:
	var found := []
	for entry in _gates:
		if entry["kind"] == kind:
			found.append(entry)
	if found.is_empty():
		return
	var at: Vector2i = found[_tour.get(kind, 0) % found.size()]["outside"]
	_tour[kind] = _tour.get(kind, 0) + 1
	player.global_position = Vector2((at.x + 0.5) * float(TILE), at.y * float(TILE) - 4.0)
	player.velocity = Vector2.ZERO
	_safe_spot = player.global_position
	_ground.watch([player.global_position], true)
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if camera != null:
		camera.reset_smoothing()


## The Rift may now set the wizard down in the locked areas. Spells are what get a wizard in on foot: the F1 panel does this.
func open_gates() -> void:
	_gates_open = true

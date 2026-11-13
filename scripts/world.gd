class_name World
extends Arena

## A generated world: a web of halls joined by tunnels, built from a seed (see WorldGraph and WorldBuilder).
## Enemies, pages and gates come later. The player
## starts in the start hall and can walk to every other one. The seed is shown on screen as its incantation.

## The seed to build from. The waiting room's portal sets it before the world loads; a world opened directly gets a random one.
static var next_seed := -1

const WIZARDS := WorldGraph.PLAYERS  # the wizards in a world: the player and the rest
const PortalCollapse := preload("res://scripts/portal_collapse.gd")

var seed_value := 0
var ledgers: Array[Ledger] = []  # the pages each wizard holds, the player's first
var graph: WorldGraph
var markers := {}
var _ponds := []
var gates := []
const NAV_DELAY := 0.4  # seconds after a pit is dug before the wizards' map of the ways is made again
var _nav_waiting := false
var _dug_tiles := {}  # the tiles of the ground that pits have taken away, so the map of the ways can be made again without them
var _built: Dictionary  # what the generator made, kept to build the ways again when a gate is cleared
var _planks := []  # the castle's swinging stairs: [{"hinge", "ends", "ways"}]
var _weather: Array[Weather] = []
const DEEP := Color(0.3, 0.27, 0.42)  # the colour of everything unlit, just under the ground
const BLACK := Color(0.015, 0.015, 0.03)  # and far down: nothing shows without a light
const DARKEN_ROWS := 16.0  # how far under the surface it takes for the light of the day to fade
const BLACKEN_ROWS := 110.0  # and for the dark to become total

var _dark: CanvasModulate
static var random_start := true  # the player starts at any one of the starting places; the showcase and tests turn this off to see the same place each time
static var arrive_by_portal := true  # the first world is entered by falling out of a portal; tests that need the wizards standing on their places turn this off
var castle_x := -1  # the first column of the first castle on the surface, or -1 when there is none


## The world's tiles, built from the seed. Everything the generator decides comes from this one rng.
func _build_map() -> Variant:
	seed_value = next_seed if next_seed >= 0 else randi() % Incantation.seed_count()
	next_seed = -1
	carried = MatchState.pending  # a world the last one collapsed into: the match goes on, rather than begins
	MatchState.pending = false
	if not carried:
		MatchState.begin(seed_value)
		Library.record_match_begun()
	var stage := MatchState.plan()
	Library.record_world_entered(stage["biome"])
	WorldGraph.size = Vector2i(stage["width"], MatchState.HEIGHT)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var built := WorldBuilder.make(rng, stage["biome"], stage["caves"])
	graph = built["graph"]
	markers = built["markers"]
	_ponds = built["ponds"]
	gates = built["gates"]
	_built = built
	add_to_group(&"world")
	castle_x = built["castle"]
	ArenaGen.world_size = built["size"]
	scenery.sea_plan = built["surface"]["sea"]
	var air: Dictionary = built["surface"]["air"]
	ArenaGen.air_rows = Vector2i(air["top"], air["bottom"]) if not air.is_empty() else Vector2i.ZERO
	ArenaGen.sky_xl = built["sky"]["xl"]
	ArenaGen.sky_floor = built["sky"]["roof_top"] if built["roofed"] else built["sky"]["floor"]  # over the great cavern lies the sky, past its roof
	ArenaGen.biome_spans = []
	for biome in graph.surface["biomes"]:
		var span := {"a": biome["a"], "b": biome["b"], "tiles": SurfaceGen.LOOKS[biome["name"]]["tiles"]}
		if SurfaceGen.LOOKS[biome["name"]].has("snow"):
			span["snow"] = SurfaceGen.LOOKS[biome["name"]]["snow"]  # above this many rows over the plains, the ground is snow
		ArenaGen.biome_spans.append(span)
	ArenaGen.castle_hall = built["hall"]
	_planks = built["planks"]
	tiled_ground = true
	_start_tile = built["start"]
	spawn_tiles = built["spawns"]
	if random_start and not Net.online():
		_start_tile = spawn_tiles[randi() % spawn_tiles.size()]  # not seeded, so the same world starts you somewhere new
	var shut := WorldBuilder.shut(built, true)
	nav = WorldNav.new()
	nav.build(shut["cells"], built["size"].y, shut["barred"], spawn_tiles[0], shut["tolls"], shut["links"], shut["climbs"])
	return built["cells"]


var nav: WorldNav  # the ways about the world on foot, with every gate shut
var _start_tile := Vector2i.ZERO
var spawn_tiles: Array[Vector2i] = []  # the starting places, far apart; the player takes one and a wizard each of the others
var _tear: Node2D  # the portal giving way, while it does
var _pulling := false
var carried := false      # the match goes on from a world that collapsed: its ledgers and wizards come with it
var _stage_time := 0.0     # seconds in this world
var leaving := false      # the portal has given way
var _collapse_in := -1.0   # seconds until the portal gives way, once it has begun to
var _seats: Array[Wizard] = []  # every wizard of the match by seat (see my_seat), the player's own among them; null where one was beaten in an earlier world
var rivals: Array[Wizard] = []  # the same, without the player's own
var _fallen := {}  # on the host: the wizards whose fall has been seen, and whose pages have been dropped
var _backdrops := {}  # place -> Backdrop


## Each biome has a backdrop of its own, all of them in place at once and one shown at a time: walking from one biome to the next
## fades the sky and scenery of the one into the other, as Terraria does.
func _set_up_backdrops() -> void:
	for child in get_children():
		if child is Backdrop:
			child.queue_free()  # the one the arena made, which has no ground of its own to stand on
	var ground_y := float(SurfaceGen.BASE_ROW * TILE)
	for place in ["cemetery", "jungle", "mountains", "ashlands", "sky", "ocean"]:
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
	if SurfaceGen.biome_at(graph.surface, column) == "sky":
		strength = 1.0  # (there is no ground to be under)
	if SurfaceGen.biome_at(graph.surface, column) == "mountains" and MountainGale.altitude(player.global_position.y) > 0.45:
		kinds = ["blizzard"]  # up near the summits the snow is a blizzard
	if scenery.squall != null:
		scenery.squall.seconds = _stage_time
		if scenery.squall.level() > 0.05 and not kinds.is_empty():
			kinds = kinds.duplicate()
			kinds[0] = "downpour" if SurfaceGen.biome_at(graph.surface, column) == "jungle" else "ash_storm"  # the storm is what falls, in place of the usual
			strength = maxf(strength, 0.0) * scenery.squall.level()
	for node in scenery.timed:
		if is_instance_valid(node):
			node.seconds = _stage_time
	if scenery.gale != null and SurfaceGen.biome_at(graph.surface, column) == "mountains":
		var push := MountainGale.push_at(player.global_position.y, scenery.gale.seconds)
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
	if not scenery.sea_plan.is_empty():  # the ocean: the view rests lower, so that the sea floor and the wrecks on it are on screen from mid-water (it does not move from place to place)
		(camera as GameCamera).set_rest_offset(Vector2(0.0, SEA_VIEW))
	pages.lay()
	_restore_player()
	player.flying = flies()
	player.fly_box = fly_box()
	player.position = places()[my_seat()]
	safe_spot = player.position
	_spawn_wizards()
	if Net.dedicated:
		_give_player_to_a_brain()
	if not carried and arrive_by_portal and not flies():
		for wizard in _seats:
			if wizard != null:
				_drop_from_portal(wizard)
	_stay_out()
	_ground.watch([player.position], true)  # the rock round the start is drawn before the first frame
	camera.reset_smoothing()
	_set_up_backdrops()
	hud.set_title("")
	hud.set_pause_note("World: " + Incantation.words_for(seed_value))
	_ground.changed.connect(_on_ground_dug)
	for entry in _ponds:
		var pond := Pond.new()
		pond.lava = entry["lava"]
		pond.width = (entry["b"] - entry["a"] + 1) * float(TILE)
		pond.depth = entry["depth"] * float(TILE) + 16.0
		pond.position = Vector2(entry["a"] * float(TILE), entry["surface"] * float(TILE))
		pond.clip = _ground.air_loops
		pond.ground = _ground
		add_child(pond)
		if not entry["lava"] and SurfaceGen.biome_at(graph.surface, graph.surface["start"]) == "jungle":  # the jungle's water is full of piranhas
			var shoal := Piranhas.new()
			shoal.water = Rect2(pond.position, Vector2(pond.width, pond.depth))
			shoal.pond = pond
			shoal.count = maxi(2, int(pond.width / (TILE * 4.0)))
			shoal.bed = graph.surface["floor"].slice(entry["a"], entry["b"] + 1)
			shoal.bed_x = entry["a"] * float(TILE)
			shoal.name = "Shoal%d" % entry["a"]
			add_child(shoal)
	scenery.lay_landmarks()
	creatures.raise()
	scenery.plant_graves()
	scenery.grow_trees()
	scenery.raise_the_gale()
	scenery.raise_biome_life()
	scenery.wash_out_the_colour()
	grade_biome = SurfaceGen.biome_at(graph.surface, graph.surface["start"])
	add_child(Grade.for_biome(grade_biome))
	if MatchState.stage == 0:
		MatchStats.begin(player)  # a new match: the story of it starts here
	else:
		MatchStats.carry_on(player)
	for index in _planks.size():
		var swing := SwingStair.new()
		swing.hinge = _planks[index]["hinge"]
		swing.ends.assign(_planks[index]["ends"])
		swing.ways = _planks[index]["ways"]
		swing.seed_value = seed_value + 71 + index
		swing.stone = earth_texture()  # the stairs are of the same stone as the castle
		add_child(swing)
	for entry in gates:
		match entry["kind"]:
			"brambles":
				scenery.grow_thorns(entry)
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
				bed.rock = earth_texture()
				add_child(bed)
			"gas":
				scenery.spread_gas(entry)
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
	gate_work.name_pieces()
	_dark = CanvasModulate.new()  # under the ground it is dark; only fire and the flare light the way
	_dark.add_to_group("darkness")
	add_child(_dark)
	get_tree().node_added.connect(_on_node_added)


var creatures := WorldCreatures.new(self)
var scenery := WorldScenery.new(self)
var pages := WorldPages.new(self)
var gate_work := WorldGates.new(self)
var match_end := MatchEnd.new(self)
const SEA_VIEW := 30.0      # where the view rests in the ocean, against the feet (elsewhere it is 150 px over them): far enough down to see the floor


@rpc("authority", "call_remote", "unreliable")
func _dead_at(places: PackedVector2Array, faces: PackedFloat32Array, swings: PackedByteArray) -> void:
	creatures.receive(places, faces, swings)


## Each world of a match is a scene of its own in a network game, so nothing about one is sent to a machine still in the last.
func _scene_name() -> String:
	return "world%d" % MatchState.stage


## The player's seat in the match. Playing alone it is the first, and brains have the other three; in a network game the people have
## the first seats in the order they joined (see Net.roster), and brains the rest. Each seat has its look, its ledger and its place.
func my_seat() -> int:
	return maxi(Net.seat_of(Net.my_id()), 0) if Net.online() else 0


## True in the sky world, where no one stands: every wizard flies.
func flies() -> bool:
	return graph != null and not graph.surface["air"].is_empty()


## The room a wizard of the sky may fly in, in pixels.
func fly_box() -> Rect2:
	if not flies():
		return Rect2()
	var air: Dictionary = graph.surface["air"]
	return Rect2(air["first"] * float(TILE), air["top"] * float(TILE), (air["last"] - air["first"] + 1) * float(TILE), (air["bottom"] - air["top"]) * float(TILE))


func _new_brain(body: Wizard) -> WizardBrain:
	return SkyBrain.new(body) if flies() else WizardBrain.new(body)


## Where each seat starts, in the world. Playing alone the player has a place of their own and the others the places farthest from it,
## in an order drawn from the seed; in a network game every seat's place is drawn from the seed, so every machine agrees on them.
func places() -> Array[Vector2]:
	var places := spawn_tiles.duplicate()
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
			out.append(stand_at(places[seat % places.size()]))
		return out
	places.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return absi(a.x - _start_tile.x) > absi(b.x - _start_tile.x))
	for k in range(WIZARDS - 2, 0, -1):  # which look starts where is drawn from the seed (the nearest place is the player's own, and stays last): the one between the others has the hardest start
		var j := rng.randi_range(0, k)
		var swap: Vector2i = places[k]
		places[k] = places[j]
		places[j] = swap
	out.append(stand_at(_start_tile))
	for i in WIZARDS - 1:
		out.append(stand_at(places[i]))
	return out


## The other wizards, each at its seat's place holding the pages its seat was dealt: the people on other machines, and brains in the
## seats nobody took. The host plays the brains; every other machine has a likeness of each.
func _spawn_wizards() -> void:
	var places := places()
	for seat in WIZARDS:
		if seat == my_seat():
			_seats.append(player)
			continue
		var state: Dictionary = MatchState.vitals[seat] if carried else {"alive": true}
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
			wizard = _add_wizard(Net.rival_look(seat), places[seat], "Rival%d" % seat)
			wizard.palette = Net.rival_palette(seat)
			wizard.nav = nav
			if state.has("max"):
				wizard.max_stamina = state["max"]
				wizard.stamina = state["stamina"]
		wizard.ledger = ledgers[seat]
		_seats.append(wizard)
	for wizard in _seats:
		if wizard != player:
			rivals.append(wizard)
	if Net.online():
		Net.roster_changed.connect(_on_roster_changed)


## On a dedicated server nobody is at the machine: its wizard, in the first seat, plays on its own, as the brains of the empty seats do.
func _give_player_to_a_brain() -> void:
	player.human = false
	player.ensure_caster()  # (it casts through a caster of its own, as a brain's wizard does)
	player.brain = _new_brain(player)
	player.nav = nav


## On a machine other than the host: a likeness of the wizard a brain plays in a seat, on the host.
func _add_brains_likeness(seat: int, feet: Vector2) -> Wizard:
	var wizard: Wizard = WIZARD_SCENE.instantiate()
	wizard.name = "Rival%d" % seat
	wizard.peer = 1
	wizard.human = false
	wizard.look = Net.rival_look(seat)
	wizard.palette = Net.rival_palette(seat)
	wizard.position = feet
	add_child(wizard)
	wizard.share()
	return wizard


## Someone left the game: their wizard falls where it stands, on every machine.
func _on_roster_changed() -> void:
	if Net.dedicated and not match_end.won and Net.roster.all(func(peer: int) -> bool: return peer == 0 or peer == Net.my_id()):
		match_end.won = true  # the last person has left: the brains would only play on to themselves, so the server goes back to the waiting room for the next people
		get_tree().create_timer(2.0).timeout.connect(_back_to_room)
		return
	for wizard in rivals:
		if is_instance_valid(wizard) and wizard.human and wizard.is_likeness() and not Net.roster.has(wizard.peer) and not wizard.dead:
			wizard.abandon()


## On the host: a wizard that has fallen leaves its whole book where it fell, for anyone to read, on every machine.
func _watch_falls() -> void:
	for seat in _seats.size():
		var wizard := _seats[seat]
		if not is_instance_valid(wizard) or not wizard.dead or _fallen.has(wizard):
			continue
		_fallen[wizard] = true
		if not carried or MatchState.vitals[seat]["alive"]:  # one beaten in an earlier world dropped its book there
			pages.drop(wizard)


@rpc("authority", "call_remote", "reliable")
func _pages_left(names: Array) -> void:
	pages.left(names)


## A fallen wizard's book lies where it fell.
@rpc("authority", "call_remote", "reliable")
func _lay_spoils(pickup_name: String, held: Array, spot: Vector2) -> void:
	pages.lay_spoils(pickup_name, held, spot)


## The first world is entered by falling out of a portal that opens in the air over where the wizard stands, as high as there is clear air for.
func _drop_from_portal(wizard: Node2D) -> void:
	var feet := wizard.global_position
	var height := 0.0
	while height < DROP_HEIGHT and not in_rock(feet + Vector2(0.0, -height - 16.0 - TILE)) and not in_rock(feet + Vector2(0.0, -height - 16.0 - TILE) + Vector2(-20.0, 0.0)) and not in_rock(feet + Vector2(0.0, -height - 16.0 - TILE) + Vector2(20.0, 0.0)):
		height += 16.0
	if height < 48.0:
		return  # no room to fall in: the wizard simply stands there
	wizard.global_position = feet + Vector2(0.0, -height)
	wizard.velocity = Vector2.ZERO
	var arrival := ArrivalPortal.new()
	arrival.position = feet + Vector2(0.0, -height - 30.0)
	add_child(arrival)


## The world position of the floor of a tile, at its middle.
func stand_at(tile: Vector2i) -> Vector2:
	if flies():  # no ground: a wizard starts in the air, at a height of its place's own
		var air: Dictionary = graph.surface["air"]
		var along := 0.3 + 0.4 * fposmod(float(tile.x) * 0.37, 1.0)
		return Vector2((tile.x + 0.5) * TILE, lerpf(air["top"], air["bottom"], along) * TILE)
	if not scenery.sea_plan.is_empty():  # the ocean: a wizard starts on the driftwood floating over its place (see WorldScenery.lay_sea), not on the sea floor; or on the island, if it is one
		return Vector2((tile.x + 0.5) * TILE, minf(float(scenery.sea_plan["row"]), tile.y + 1.0) * TILE)
	return Vector2((tile.x + 0.5) * TILE, (tile.y + 1) * TILE)


const DROP_HEIGHT := 200.0  # how far over the ground a wizard comes out of the portal at most
var safe_spot := Vector2.ZERO  # the last place the wizard stood on firm ground
var _buried := 0.0              # how long the wizard has been inside rock


## True when a point is inside rock or outside the world. The outlines that make the rock solid have no inside, so a body that
## gets in cannot be found by a physics query: the tiles are asked instead.
func in_rock(point: Vector2) -> bool:
	var size := ArenaGen.world_size
	var cell := Vector2i(floori(point.x / TILE), floori(point.y / TILE))
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return true
	var material: int = _cells.material(cell)
	if material != ArenaGen.GROUND and material != ArenaGen.STONE:
		return false
	return not _ground.is_dug(point) or _ground.solid_at(point)  # the tiles do not know about a pit that was dug


## A point inside the rock is lifted out of it first, so a spell drawn into a hill lands on top of it.
func _surface_under(point: Vector2) -> Vector2:
	if not in_rock(point):
		return super._surface_under(point)
	return SpellTargets.solid_below(get_world_2d(), lifted_out_of_rock(point) + Vector2(0.0, -8.0))


## A point inside rock moved straight up until it is in the open.
func lifted_out_of_rock(point: Vector2) -> Vector2:
	var clear := point
	for step in 400:
		if not in_rock(clear):
			break
		clear.y -= 8.0
	return clear


func _body_in_rock(at: Vector2) -> bool:
	for lift in [-24.0, -48.0]:  # not lower: on a slope the tiles stand a little above the smooth ground
		if in_rock(at + Vector2(0.0, lift)):
			return true
	return false


## A teleport (Shadow Step) stops short of any rock: the path is walked back from its end to the first clear spot.
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
	var watched: Array[Vector2] = [player.global_position]  # the rock is drawn only round the wizard,
	for watcher: Node2D in get_tree().get_nodes_in_group("ground_watchers"):
		watched.append(watcher.global_position)  # and round a ball of fire that has rolled away, or the view of a Scrying Eye
	_ground.watch(watched)
	_fade_backdrops(delta)
	var column := floori(player.global_position.x / TILE) - ArenaGen.sky_xl
	var ground := ArenaGen.sky_floor[clampi(column, 0, ArenaGen.sky_floor.size() - 1)] if not ArenaGen.sky_floor.is_empty() else WorldGraph.SURFACE_ROW
	var under := player.global_position.y - (ground + 2) * TILE  # how far below the ground overhead
	var depth := clampf(under / (DARKEN_ROWS * TILE), 0.0, 1.0)
	var far := clampf((under - DARKEN_ROWS * TILE) / ((BLACKEN_ROWS - DARKEN_ROWS) * TILE), 0.0, 1.0)
	var day: Color = SurfaceGen.LOOKS[SurfaceGen.biome_at(graph.surface, column + ArenaGen.sky_xl)]["tint"]
	_dark.color = day.lerp(DEEP, depth).lerp(BLACK, far)
	_update_weather(under)
	creatures.share(delta)
	match_end.count_wizards(delta)
	MatchStats.tick(delta)
	if Net.is_host():
		_watch_falls()
		pages.tell_left(delta)
	_watch_portal(delta)
	gate_work.watch(delta)
	if player.dead:
		match_end.follow_watched()
		return
	if _pulling:
		return  # drawn up into the portal: the ground has no say
	if _body_in_rock(player.global_position) or player.global_position.y > ArenaGen.world_size.y * TILE:
		_buried += delta
		if _buried > 0.2:
			player.global_position = safe_spot
			player.velocity = Vector2.ZERO
			player.reset_physics_interpolation()
			_buried = 0.0
	else:
		_buried = 0.0
		if player.is_on_floor():
			safe_spot = player.global_position


## How bright an unlit place is, 0 (black) to 1, as it would look on the screen of someone standing there: the same tint _process gives the
## person's screen for where they stand (dim just under the ground, black far down). A brain's eyes use it (see Eyes).
func light_level_at(point: Vector2) -> float:
	var column := floori(point.x / TILE) - ArenaGen.sky_xl
	var ground := ArenaGen.sky_floor[clampi(column, 0, ArenaGen.sky_floor.size() - 1)] if not ArenaGen.sky_floor.is_empty() else WorldGraph.SURFACE_ROW
	var under := point.y - (ground + 2) * TILE
	var depth := clampf(under / (DARKEN_ROWS * TILE), 0.0, 1.0)
	var far := clampf((under - DARKEN_ROWS * TILE) / ((BLACKEN_ROWS - DARKEN_ROWS) * TILE), 0.0, 1.0)
	var day: Color = SurfaceGen.LOOKS[SurfaceGen.biome_at(graph.surface, column + ArenaGen.sky_xl)]["tint"]
	return day.lerp(DEEP, depth).lerp(BLACK, far).get_luminance()


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
	if node is Pond or node is Hazard or node is Bonfire or node is Projectile or node is Firewall or node is LavaBall or node is FlamingSphere:
		_light_when_ready.call_deferred(node)


func _light_when_ready(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_in_group("fires"):
		return
	if node is Pond:
		var pond: Pond = node
		var glow := _make_light(maxf(pond.width, 160.0), Color(1.0, 0.5, 0.2), 0.9)
		glow.position = Vector2(pond.width * 0.5, 0.0)
		node.add_child(glow)
	else:
		var radius := 120.0 if node is LavaBall else (180.0 if node is Hazard else 260.0)  # a ball in flight is a small thing, and there are many in an eruption
		node.add_child(_make_light(radius, Color(1.0, 0.6, 0.25), 1.1))


## What the player has left of their stamina, from the world before.
func _restore_player() -> void:
	if not carried:
		return
	var state: Dictionary = MatchState.vitals[my_seat()]
	player.max_stamina = state["max"]
	player.stamina = state["stamina"]
	_fade_from_black()


## A wizard beaten in an earlier world is still out in this one, and watches.
func _stay_out() -> void:
	if carried and not MatchState.vitals[my_seat()]["alive"]:
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
	if seconds <= 0.0 or (player.dead and not match_end.spectating and not Net.dedicated):  # (a server's own wizard may fall, and the clock goes on for the people on other machines)
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
		_tear.pull(SpellTargets.wizards(get_tree()))  # everyone still standing
	if _collapse_in <= 0.0 and not leaving:
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
	if leaving:
		return
	MatchState.stage = at - 1  # the collapse moves on to the next
	_collapse()


## For the F1 panel: leaves for a world of any biome now, whether or not this match's seed would deal it, keeping this world's place in the match.
func go_to_biome(biome: String) -> void:
	if leaving:
		return
	go_to_stage(MatchState.stage)
	MatchState.forced_biome = biome


func _collapse() -> void:
	leaving = true
	var state: Array[Dictionary] = []
	for wizard in _seats:
		if is_instance_valid(wizard):
			wizard.end_wild()  # the wolf does not travel: the wizard's own stamina is what is carried on
		if wizard == player:
			state.append({"alive": not player.dead, "max": player.max_stamina, "stamina": player.stamina})
		elif is_instance_valid(wizard) and not wizard.dead:
			state.append({"alive": true, "max": wizard.max_stamina, "stamina": wizard.stamina})
		else:
			state.append({"alive": false})
	next_seed = MatchState.advance(ledgers, state, Incantation.seed_count())
	leave_network_scene()
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


## The wizards' map of the ways, built again from the world as it is now: the gates that are still shut, and the ground as it has been dug.
func build_nav() -> void:
	var shut := WorldBuilder.shut(_built, true)
	var cells: TileGrid = shut["cells"]
	for tile: Vector2i in _dug_tiles:
		cells.erase(tile)
	nav.build(cells, _built["size"].y, shut["barred"], spawn_tiles[0], shut["tolls"], shut["links"], shut["climbs"])


## The ground has been dug (a Sinkhole): the tiles it took away are open air to the wizards' map, which is made again.
func _on_ground_dug(area: Rect2) -> void:
	var tile_size := float(TILE)
	var cells: TileGrid = _built["cells"]
	var lost := false
	for ty in range(floori(area.position.y / tile_size), ceili(area.end.y / tile_size)):
		for tx in range(floori(area.position.x / tile_size), ceili(area.end.x / tile_size)):
			var tile := Vector2i(tx, ty)
			if _dug_tiles.has(tile) or not cells.has(tile):
				continue
			var corner := Vector2(tile) * tile_size
			var open := true
			for offset in [Vector2(2, 2), Vector2(tile_size - 2.0, 2), Vector2(2, tile_size - 2.0), Vector2(tile_size - 2.0, tile_size - 2.0), Vector2(tile_size * 0.5, tile_size * 0.5)]:
				open = open and not _ground.solid_at(corner + offset)
			if open:
				_dug_tiles[tile] = true
				lost = true
	if lost and not _nav_waiting:  # a moment later, and once for pits dug together: making the map takes a tenth of a second
		_nav_waiting = true
		get_tree().create_timer(NAV_DELAY).timeout.connect(func() -> void:
			_nav_waiting = false
			build_nav())


@rpc("authority", "call_remote", "reliable")
func _gates_cleared(names: Array) -> void:
	gate_work.receive_cleared(names)


## The gates that spells can clear and have not yet (see WorldGates.closed).
func closed_gates() -> Array[Dictionary]:
	return gate_work.closed()


## The gates that a spell lets a wizard past, and does not clear (see WorldGates.crossings).
func crossings() -> Array[Dictionary]:
	return gate_work.crossings()


## The point of a gate to strike (see WorldGates.target).
func gate_target(entry: Dictionary) -> Vector2:
	return gate_work.target(entry)


## The kinds of gate this world has, for the F1 panel.
func gate_kinds() -> Array:
	return gate_work.kinds()


## The F1 panel's way to a gate of this kind.
func go_to_gate(kind: String) -> void:
	gate_work.go_to(kind)


## The Rift may now set the wizard down in the locked areas: the F1 panel does this.
func open_gates() -> void:
	gate_work.open_all()


## The wizards still in the match, other than the player.
func living() -> Array[Wizard]:
	var out: Array[Wizard] = []
	for rival in rivals:
		if is_instance_valid(rival) and not rival.dead:
			out.append(rival)
	return out


## Out of the match: while other wizards still live the match goes on, and the camera follows one of them (see MatchEnd.on_player_died).
func _on_player_died() -> void:
	match_end.on_player_died()


## The F1 panel's way to a won match.
func debug_win() -> void:
	match_end.debug_win()


## The F1 panel's way to a lost match.
func debug_lose() -> void:
	match_end.debug_lose()


## The F1 panel's way to the ending: the player's own wizard has won.
func go_to_epilogue() -> void:
	match_end.go_to_epilogue()


func _unhandled_input(event: InputEvent) -> void:
	match_end.input(event)


## The match is won: on the host and then on every other machine, the winner is shown putting the book back.
@rpc("authority", "call_remote", "reliable")
func _end_with_epilogue(look: String, palette: int) -> void:
	match_end.end_with_epilogue(look, palette)


## The end of a network match: everyone is back in the waiting room, for the next one.
@rpc("authority", "call_remote", "reliable")
func _back_to_room() -> void:
	match_end.back_to_room()


## A Rift sets the wizard down in another hall, picked by chance, and none behind a gate.
func _rift_spot(from: Vector2) -> Vector2:
	var spots: Array[Vector2] = []
	for room in graph.rooms:
		if room["lock"] != -1 and not gate_work.opened:
			continue
		var spot := stand_at(markers[room["id"]])
		if spot.distance_to(from) > 400.0:
			spots.append(spot)
	return spots[randi() % spots.size()] if not spots.is_empty() else from




## The top of the floor under a point (out of the rock first when it is in it), asked of the tiles, which are there before the ground is built.
func floor_under(point: Vector2) -> Vector2:
	var x := point.x
	var row := floori((point.y - 1.0) / TILE)
	while row > 0 and in_rock(Vector2(x, (row + 0.5) * TILE)):
		row -= 1
	while row < ArenaGen.world_size.y - 1 and not in_rock(Vector2(x, (row + 1.5) * TILE)):
		row += 1
	return Vector2(x, (row + 1) * TILE)




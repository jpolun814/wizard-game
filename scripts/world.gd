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
var _markers := {}
var _ponds := []
var _gates := []
const NAV_DELAY := 0.4  # seconds after a pit is dug before the wizards' map of the ways is made again
var _nav_waiting := false
const PAGES_TOLD_EVERY := 3.0
var _pages_told := 0.0
var _dug_tiles := {}  # the tiles of the ground that pits have taken away, so the map of the ways can be made again without them
var _built: Dictionary  # what the generator made, kept to build the ways again when a gate is cleared
var _since_gates := 0.0
var _planks := []  # the castle's swinging stairs: [{"hinge", "ends", "ways"}]
var _weather: Array[Weather] = []
var _gale: MountainGale  # the snowy peaks' wind, when this world has it
var _squall: Squall  # the jungle's downpours or the ashlands' ash storms, when this world has them
var _sea: Dictionary  # the ocean's sea, wrecks and islands (SurfaceGen._sea_of), or empty
var _timed: Array[Node] = []  # the avalanche and the lava lakes' swells: each is told the world's age every frame
var _gates_open := false
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
	_carried = MatchState.pending  # a world the last one collapsed into: the match goes on, rather than begins
	MatchState.pending = false
	if not _carried:
		MatchState.begin(seed_value)
		Library.record_match_begun()
	var stage := MatchState.plan()
	Library.record_world_entered(stage["biome"])
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
	_sea = built["surface"]["sea"]
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


const THORN_CHUNK := 5  # tiles of floor in a thicket of the world
const EPILOGUE_AFTER := 4.0  # seconds after a match is won, in a game on this machine alone, before the winner is shown putting the book back (when the person won, after they have put their stats away)
const STATS_AFTER := 3.0  # seconds after the person wins before their stats come up on their own
const BACK_TO_ROOM := 10.0  # seconds after a network match is won before everyone is back in the waiting room
var nav: WorldNav  # the ways about the world on foot, with every gate shut
var _start_tile := Vector2i.ZERO
var spawn_tiles: Array[Vector2i] = []  # the starting places, far apart; the player takes one and a wizard each of the others
var _since_count := 0.0
var _won := false
var _win_stats_due := false  # the person has won and their stats have not come up yet
var _watched := 0  # while out of the match: which of the other wizards the camera follows
var _spectating := false
var _tear: Node2D  # the portal giving way, while it does
var _pulling := false
var _carried := false      # the match goes on from a world that collapsed: its ledgers and wizards come with it
var _stage_time := 0.0     # seconds in this world
var _leaving := false      # the portal has given way
var _collapse_in := -1.0   # seconds until the portal gives way, once it has begun to
var _seats: Array[Wizard] = []  # every wizard of the match by seat (see _my_seat), the player's own among them; null where one was beaten in an earlier world
var _stats: StatsScreen  # what is shown when the person falls
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
	if _squall != null:
		_squall.seconds = _stage_time
		if _squall.level() > 0.05 and not kinds.is_empty():
			kinds = kinds.duplicate()
			kinds[0] = "downpour" if SurfaceGen.biome_at(graph.surface, column) == "jungle" else "ash_storm"  # the storm is what falls, in place of the usual
			strength = maxf(strength, 0.0) * _squall.level()
	for node in _timed:
		if is_instance_valid(node):
			node.seconds = _stage_time
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
	if not _sea.is_empty():  # the ocean: the view rests lower, so that the sea floor and the wrecks on it are on screen from mid-water (it does not move from place to place)
		(camera as GameCamera).set_rest_offset(Vector2(0.0, SEA_VIEW))
	_lay_pages()
	_restore_player()
	player.flying = _flies()
	player.fly_box = _fly_box()
	player.position = _places()[_my_seat()]
	_safe_spot = player.position
	_spawn_wizards()
	if Net.dedicated:
		_give_player_to_a_brain()
	if not _carried and arrive_by_portal and not _flies():
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
	_lay_landmarks()
	creatures.raise()
	_plant_graves()
	_grow_trees()
	_raise_the_gale()
	_raise_biome_life()
	_wash_out_the_colour()
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
				bed.rock = earth_texture()
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
		eruption.ground = _ground
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
			var x := mud.position.x + lerpf(-mud.width * 0.5, mud.width * 0.5, float(i) / (Mudslide.SAMPLES - 1))
			heights.append(_ground.surface_near(x, floors[column] * t) - mud.position.y)  # the ground as drawn, which is rounded off, not the row's own top
		mud.planted_ground = heights
		mud.modulate = Color(0.36, 0.42, 0.26)  # dark green-brown jungle mud, not the sand of the spell
		add_child(mud)
	for thicket: Dictionary in graph.surface["thorns"]:
		_grow_thorns({"floors": floors.slice(thicket["a"], thicket["b"] + 1), "first": thicket["a"]})


var creatures := WorldCreatures.new(self)
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
		var lowest := floors[column]
		for c in range(column - JungleTree.FOOTPRINT, column + JungleTree.FOOTPRINT + 1):
			lowest = maxi(lowest, floors[c])
		tree.drop = float(lowest - floors[column]) * TILE  # where the ground falls away under its roots, they go on down to it
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


## What lives in each biome besides the landmarks: the graveyard's low mist, bats and crypts; the jungle's rope bridges, light and birds,
## and its downpours; the peaks' avalanches and sheets of ice; the ashlands' swelling lava, ash storms and falling embers.
func _raise_biome_life() -> void:
	var biome := SurfaceGen.biome_at(graph.surface, graph.surface["start"])
	var floors: PackedInt32Array = graph.surface["floor"]
	var tile := float(TILE)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 8101
	match biome:
		"graveyard":
			var mist := MistBank.new()
			mist.floors = floors
			mist.seed_value = seed_value + 17
			add_child(mist)
			var bats := CritterFlock.new()
			bats.bats = true
			bats.span = Vector2(SurfaceGen.MARGIN * tile, (WorldGraph.size.x - SurfaceGen.MARGIN) * tile)
			bats.sky = SurfaceGen.BASE_ROW * tile
			bats.seed_value = seed_value + 23
			add_child(bats)
			for column: int in graph.surface["crypts"]:
				var crypt := Crypt.new()
				crypt.position = Vector2((column + 0.5) * tile, floors[column] * tile + 2.0)
				add_child(crypt)
				var guard: Mob = add_mob("basic", floor_under(Vector2((column + 4.5) * tile, floors[column] * tile - 40.0)))
				guard.max_hp = WorldCreatures.DEAD_HEALTH
				guard.hp = WorldCreatures.DEAD_HEALTH
				creatures.enlist(guard)  # kept in step across the network like the roaming dead
		"jungle":
			var perches: Array[Vector2] = []
			var trees: Array = graph.surface["trees"]
			for k in trees.size():
				var tree: Dictionary = trees[k]
				var column: int = tree["column"]
				perches.append(Vector2((column + 0.5) * tile, floors[column] * tile - 230.0 * tree["size"] * 0.9))
				if k % 3 == 1:
					var shaft := LightShaft.new()
					shaft.position = Vector2((column + 0.5) * tile + 70.0, floors[column] * tile - 260.0)
					shaft.phase = k
					add_child(shaft)
			var birds := CritterFlock.new()
			birds.perches = perches
			birds.seed_value = seed_value + 29
			add_child(birds)
			for bridge: Dictionary in JungleTree.bridges(trees, floors):
				var span := CanopyBridge.new()
				span.width = (bridge["last"] - bridge["first"] + 1) * tile
				span.position = Vector2(bridge["first"] * tile, floors[bridge["tree"]] * tile + 2.0 - JungleTree.LEDGES[JungleTree.VINE_LEDGE][0] * float(_tree_size(bridge["tree"])))
				add_child(span)
			_squall = Squall.new()
			_squall.rain = true
			_squall.period = 75.0
			_squall.length = 20.0
			_squall.delay = 28.0
			_squall.tint = Color(0.02, 0.06, 0.08)
			_squall.strength = 0.45
			add_child(_squall)
		"mountains":
			var slide := Avalanche.new()
			slide.floors = floors
			slide.seed_value = seed_value + 41
			add_child(slide)
			_timed.append(slide)
			var ridges := MountainRidges.new()  # a second range behind the ground, to climb over and drop down from
			ridges.floors = floors
			ridges.seed_value = seed_value + 53
			ridges.tile = tile
			ridges.earth = _ground.earth_texture  # the same rock as the ground in front, and its lip
			ridges.lip = _ground.lip
			ridges.snow = _ground.snow_pack
			ridges.snow_lip = _ground.snow_lip
			ridges.snow_line = float(WorldGraph.SURFACE_ROW - int(SurfaceGen.LOOKS["mountains"]["snow"])) * float(tile)
			add_child(ridges)
			var column := SurfaceGen.MARGIN + 20
			while column < floors.size() - SurfaceGen.MARGIN - 20:  # sheets of ice on the level stretches
				var run := 1
				while column + run < floors.size() and floors[column + run] == floors[column]:
					run += 1
				if run >= 8 and rng.randf() < 0.6:
					var sheet := IceSheet.new()
					sheet.width = (run - 2) * tile
					sheet.position = Vector2((column + 1) * tile, floors[column] * tile)
					add_child(sheet)
				column += run
		"ocean":
			_lay_sea()
		"sky":
			_raise_clouds()
		"portals":
			var field := PortalField.new()
			field.seed_value = seed_value + 71
			field.floors = floors
			field.tile = tile
			field.margin = SurfaceGen.MARGIN + 12
			add_child(field)
			_timed.append(field)
		"underground":
			var cave := CaveLife.new()
			cave.floors = floors  # (a roofed world keeps no sky of its own: its roof is worked out from the ground)
			cave.seed_value = seed_value + 61
			cave.player = player
			cave.earth = earth_texture()
			add_child(cave)
			_timed.append(cave)
		"ashlands":
			_squall = Squall.new()
			_squall.period = 70.0
			_squall.length = 18.0
			_squall.delay = 30.0
			_squall.tint = Color(0.1, 0.05, 0.03)
			_squall.strength = 0.38
			add_child(_squall)
			var embers := EmberRain.new()
			embers.squall = _squall
			embers.seed_value = seed_value + 53
			embers.player = player
			embers.floors = floors
			add_child(embers)
			for pond: Node in get_children():
				if pond is Pond and pond.lava:
					var surge := LavaSurge.new()
					surge.width = pond.width
					surge.phase = fmod(pond.position.x * 0.013, 13.0)
					surge.position = pond.position
					add_child(surge)
					_timed.append(surge)


const SEA_LENGTH := 1536.0  # how long each length of the sea is
const START_RAFT := 160.0   # how wide the driftwood a wizard starts on is
const SEA_VIEW := 30.0      # where the view rests in the ocean, against the feet (elsewhere it is 150 px over them): far enough down to see the floor


## The ocean: the sea over the whole world (a deep Pond), driftwood floating on it, kelp and wrecks on its floor.
func _lay_sea() -> void:
	var tile := float(TILE)
	var floors: PackedInt32Array = graph.surface["floor"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 8209
	var whole: float = ArenaGen.world_size.x * tile
	var left := 0.0
	while left < whole:  # the sea is laid in lengths, so that only the ones in view are drawn
		var sea := Pond.new()
		sea.deep = true
		sea.width = minf(SEA_LENGTH, whole - left)
		sea.depth = _sea["depth"] * tile + 16.0
		sea.position = Vector2(left, _sea["row"] * tile)
		sea.clip = _ground.air_loops
		add_child(sea)
		left += SEA_LENGTH
	var wrecks: Array = _sea["wrecks"]
	for k in wrecks.size():
		var at_column: int = wrecks[k]
		var wreck := Wreck.new()
		wreck.seed_value = seed_value + 83 + k
		wreck.clip = _ground.air_loops
		wreck.position = Vector2((at_column + 0.5) * tile, floors[at_column] * tile)
		add_child(wreck)
	var starts: Array = graph.surface["starts"].duplicate()  # where nothing else floats: the starting places, and the rafts
	for spawn in spawn_tiles:  # each wizard starts on a raft of driftwood over its place, out at sea
		if spawn.y + 1 <= int(_sea["row"]):
			continue  # (a place on an island stands on the island)
		var raft := Driftwood.new()
		raft.width = START_RAFT
		raft.phase = rng.randf() * TAU
		raft.position = _stand_at(spawn)
		add_child(raft)
		starts.append(spawn.x)
	var column := SurfaceGen.MARGIN + 20
	while column < floors.size() - SurfaceGen.MARGIN - 20:  # driftwood on the waterline over the deep, kelp on the floor below it
		var step := rng.randi_range(9, 16)
		if floors[column] >= int(_sea["row"]) + SurfaceGen.SEA_DEPTH_LEAST - 4:
			var clear := true
			for spot in starts + wrecks:
				clear = clear and absi(column - int(spot)) > 10
			if clear:
				if rng.randf() < 0.55:
					var wood := Driftwood.new()
					wood.width = 96.0 if rng.randf() < 0.6 else 128.0
					wood.phase = rng.randf() * TAU
					wood.position = Vector2((column + 0.5) * tile, _sea["row"] * tile)
					add_child(wood)
				else:
					var kelp := KelpPatch.new()
					kelp.seed_value = seed_value + column
					for s in rng.randi_range(5, 9):
						var at: int = clampi(column + s, 0, floors.size() - 1)
						kelp.bases.append(Vector2((at + 0.5) * tile + rng.randf_range(-6.0, 6.0), floors[at] * tile))
					add_child(kelp)
		column += step


## The sky: clouds that rise past the wizards, and thunderclouds among them.
func _raise_clouds() -> void:
	var box := _fly_box()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 8221
	var span := Rect2(box.position.x, box.position.y - 400.0, box.size.x, box.size.y + 800.0)
	var plain := maxi(8, int(box.size.x / 450.0))  # (owner, 2026-11-12: more of them)
	var storms := maxi(3, int(box.size.x / 2000.0))
	for k in plain + storms:
		var cloud := SkyCloud.new()
		cloud.storm = k >= plain
		cloud.kind = rng.randi_range(0, 2)
		cloud.seed_value = seed_value * 13 + k
		cloud.span = span
		cloud.home = Vector2(rng.randf_range(span.position.x, span.end.x), rng.randf_range(span.position.y, span.end.y))
		cloud.rise = rng.randf_range(25.0, 45.0) if cloud.storm else rng.randf_range(25.0, 70.0)
		cloud.side = rng.randf_range(-12.0, 12.0)
		cloud.period = rng.randf_range(5.0, 8.0)
		cloud.phase = rng.randf_range(0.0, cloud.period)
		_timed.append(cloud)
		add_child(cloud)


## How large the great tree standing in a column is (1 to 3 times its picture).
func _tree_size(column: int) -> int:
	for tree: Dictionary in graph.surface["trees"]:
		if tree["column"] == column:
			return tree["size"]
	return 2


## The graveyard is seen in grey: a layer over the world, under the interface, that takes the colour out of it.
func _wash_out_the_colour() -> void:
	if SurfaceGen.biome_at(graph.surface, graph.surface["start"]) != "graveyard":
		return
	greyed = true  # (the Scrying Eye's window is washed out too)
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


@rpc("authority", "call_remote", "unreliable")
func _dead_at(places: PackedVector2Array, faces: PackedFloat32Array, swings: PackedByteArray) -> void:
	creatures.receive(places, faces, swings)


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
			points.append(Vector2(x, _ground.surface_near(x, floors[column] * t)))
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


## True in the sky world, where no one stands: every wizard flies.
func _flies() -> bool:
	return graph != null and not graph.surface["air"].is_empty()


## The room a wizard of the sky may fly in, in pixels.
func _fly_box() -> Rect2:
	if not _flies():
		return Rect2()
	var air: Dictionary = graph.surface["air"]
	return Rect2(air["first"] * float(TILE), air["top"] * float(TILE), (air["last"] - air["first"] + 1) * float(TILE), (air["bottom"] - air["top"]) * float(TILE))


func _new_brain(body: Wizard) -> WizardBrain:
	return SkyBrain.new(body) if _flies() else WizardBrain.new(body)


## Where each seat starts, in the world. Playing alone the player has a place of their own and the others the places farthest from it,
## in an order drawn from the seed; in a network game every seat's place is drawn from the seed, so every machine agrees on them.
func _places() -> Array[Vector2]:
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
			_rivals.append(wizard)
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
	if Net.dedicated and not _won and Net.roster.all(func(peer: int) -> bool: return peer == 0 or peer == Net.my_id()):
		_won = true  # the last person has left: the brains would only play on to themselves, so the server goes back to the waiting room for the next people
		get_tree().create_timer(2.0).timeout.connect(_back_to_room)
		return
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
	var spot := wizard.global_position + Vector2(0.0, 40.0) if _flies() else on_ridge(wizard.global_position, floor_under(wizard.global_position))  # on a ridge, the book lies on it; in the sky it hangs where they fell
	var name := "Spoils" + String(wizard.name)
	_lay_spoils(name, held, spot)
	Net.send(self, &"_lay_spoils", [name, held, spot])


## The host says every few seconds which pages still lie, because a page read while a machine was still loading the world is never heard of
## there, and would lie on its screen for ever, out of reach. A machine takes off the ground any page that is not on the list.
func _tell_pages_left(delta: float) -> void:
	_pages_told += delta
	if _pages_told < PAGES_TOLD_EVERY or not Net.online():
		return
	_pages_told = 0.0
	var names: Array[String] = []
	for pickup: PagePickup in get_tree().get_nodes_in_group("pages"):
		if not pickup is Mirage and not pickup.is_queued_for_deletion():
			names.append(String(pickup.name))
	Net.send(self, &"_pages_left", [names])


@rpc("authority", "call_remote", "reliable")
func _pages_left(names: Array) -> void:
	for pickup: PagePickup in get_tree().get_nodes_in_group("pages"):
		if not pickup is Mirage and not names.has(String(pickup.name)):
			pickup.queue_free()


## A fallen wizard's book lies where it fell.
@rpc("authority", "call_remote", "reliable")
func _lay_spoils(pickup_name: String, held: Array, spot: Vector2) -> void:
	var pickup := PagePickup.new()
	pickup.name = pickup_name
	pickup.page = held[0]
	pickup.spoils.assign(held)
	pickup.position = spot
	add_child(pickup)


## The first world is entered by falling out of a portal that opens in the air over where the wizard stands, as high as there is clear air for.
func _drop_from_portal(wizard: Node2D) -> void:
	var feet := wizard.global_position
	var height := 0.0
	while height < DROP_HEIGHT and not _in_rock(feet + Vector2(0.0, -height - 16.0 - TILE)) and not _in_rock(feet + Vector2(0.0, -height - 16.0 - TILE) + Vector2(-20.0, 0.0)) and not _in_rock(feet + Vector2(0.0, -height - 16.0 - TILE) + Vector2(20.0, 0.0)):
		height += 16.0
	if height < 48.0:
		return  # no room to fall in: the wizard simply stands there
	wizard.global_position = feet + Vector2(0.0, -height)
	wizard.velocity = Vector2.ZERO
	var arrival := ArrivalPortal.new()
	arrival.position = feet + Vector2(0.0, -height - 30.0)
	add_child(arrival)


## The world position of the floor of a tile, at its middle.
func _stand_at(tile: Vector2i) -> Vector2:
	if _flies():  # no ground: a wizard starts in the air, at a height of its place's own
		var air: Dictionary = graph.surface["air"]
		var along := 0.3 + 0.4 * fposmod(float(tile.x) * 0.37, 1.0)
		return Vector2((tile.x + 0.5) * TILE, lerpf(air["top"], air["bottom"], along) * TILE)
	if not _sea.is_empty():  # the ocean: a wizard starts on the driftwood floating over its place (see _lay_sea), not on the sea floor; or on the island, if it is one
		return Vector2((tile.x + 0.5) * TILE, minf(float(_sea["row"]), tile.y + 1.0) * TILE)
	return Vector2((tile.x + 0.5) * TILE, (tile.y + 1) * TILE)


const DROP_HEIGHT := 200.0  # how far over the ground a wizard comes out of the portal at most
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
	if material != ArenaGen.GROUND and material != ArenaGen.STONE:
		return false
	return not _ground.is_dug(point) or _ground.solid_at(point)  # the tiles do not know about a pit that was dug


## A point inside the rock is lifted out of it first, so a spell drawn into a hill lands on top of it.
func _surface_under(point: Vector2) -> Vector2:
	if not _in_rock(point):
		return super._surface_under(point)
	return SpellTargets.solid_below(get_world_2d(), lifted_out_of_rock(point) + Vector2(0.0, -8.0))


## A point inside rock moved straight up until it is in the open.
func lifted_out_of_rock(point: Vector2) -> Vector2:
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
	_count_wizards(delta)
	MatchStats.tick(delta)
	if Net.is_host():
		_watch_falls()
		_tell_pages_left(delta)
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
	if seconds <= 0.0 or (player.dead and not _spectating and not Net.dedicated):  # (a server's own wizard may fall, and the clock goes on for the people on other machines)
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


## For the F1 panel: leaves for a world of any biome now, whether or not this match's seed would deal it, keeping this world's place in the match.
func go_to_biome(biome: String) -> void:
	if _leaving:
		return
	go_to_stage(MatchState.stage)
	MatchState.forced_biome = biome


func _collapse() -> void:
	_leaving = true
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
		_build_nav()
		if Net.online() and Net.is_host():
			Net.send(self, &"_gates_cleared", [_cleared_gate_names()])


## The wizards' map of the ways, built again from the world as it is now: the gates that are still shut, and the ground as it has been dug.
func _build_nav() -> void:
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
			_build_nav())


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
	if Net.dedicated:
		return  # nobody is here to watch the others, or to see the stats: the match goes on for the people on other machines
	PlayRecorder.finish(get_tree())  # (in a network match the person's play is sent to the machine that keeps the game)
	_record_match(_living().size() + 1)
	_show_stats()
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


## The match goes into the Chronicle, once: where the person came, and what they did.
func _record_match(place: int) -> void:
	if MatchStats.recorded:
		return
	MatchStats.recorded = true
	Library.record_match_end(MatchStats.summary(place, _rivals.size() + 1))
	Library.flush()


## The story of the match so far, over the screen: where the person came, and charts of what they did.
func _show_stats() -> void:
	if is_instance_valid(_stats):
		return
	_stats = StatsScreen.new()
	hud.add_child(_stats)
	hud.offer_stats()
	if not hud.stats_requested.is_connected(_look_at_stats):
		hud.stats_requested.connect(_look_at_stats)
	_stats.show_stats(_living().size() + 1, _rivals.size() + 1, not _living().is_empty())


## A few seconds after the person wins, their stats come up on their own, and the ending waits for them to be put away. (The crystal ball on the screen is
## only for one who has fallen and wants to look again while the match goes on.)
func _show_win_stats() -> void:
	_win_stats_due = false
	if _leaving:
		return
	if not is_instance_valid(_stats):
		_stats = StatsScreen.new()
		hud.add_child(_stats)
	hud.move_child(_stats, -1)
	_stats.show_stats(1, _rivals.size() + 1, false)


## The F1 panel's way to a won match: every other wizard falls, and the match ends as it does when the last of them is beaten.
func debug_win() -> void:
	for rival in _living():
		rival.take_damage(100000)


## The F1 panel's way to a lost match: the person falls, as when beaten.
func debug_lose() -> void:
	if not player.dead:
		player.take_damage(100000)


## The person asks to see their stats again, once the match is over for them.
func _look_at_stats() -> void:
	if not is_instance_valid(_stats):
		_stats = StatsScreen.new()
		hud.add_child(_stats)
	hud.move_child(_stats, -1)  # over everything else on the layer
	_stats.show_stats(_living().size() + 1, _rivals.size() + 1, not _living().is_empty())


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
	if standing.size() == 1 and standing[0] == player and not Net.dedicated:
		_won = true
		hud.banner("Last wizard standing", "You win")
		Library.record_win(player.ledger.pages.keys())
		MatchStats.finish()  # the clock stops where the match was won
		PlayRecorder.finish(get_tree())
		_record_match(1)
		_win_stats_due = true
		get_tree().create_timer(STATS_AFTER).timeout.connect(_show_win_stats)
		Library.flush()
		Sfx.play("ritual_ok", player.center())
	if standing.size() == 1 and Library.real_match() and (Net.is_host() or not Net.online()):
		_won = true
		var champion: Wizard = standing[0]
		get_tree().create_timer(EPILOGUE_AFTER).timeout.connect(_epilogue_when_stats_are_away.bind(champion.look, champion.palette))  # the winner is shown putting the book back, on every machine
	elif standing.size() <= 1 and Net.online() and Net.is_host():
		_won = true
		get_tree().create_timer(BACK_TO_ROOM).timeout.connect(_back_to_room)  # no winner, or a test: everyone just goes back to the waiting room


## The ending waits while the person is reading their stats, so it never cuts in on them.
func _epilogue_when_stats_are_away(look: String, palette: int) -> void:
	if _win_stats_due or (is_instance_valid(_stats) and _stats.visible):
		get_tree().create_timer(0.5).timeout.connect(_epilogue_when_stats_are_away.bind(look, palette))
		return
	_end_with_epilogue(look, palette)


## The match is won: on the host and then on every other machine, the winner is shown putting the book back.
@rpc("authority", "call_remote", "reliable")
func _end_with_epilogue(look: String, palette: int) -> void:
	if not is_inside_tree():
		return
	if Net.is_host():
		Net.send(self, &"_end_with_epilogue", [look, palette])
	if GameSettings.skip_ending():
		_fade_to_room()  # this machine's player would rather not watch it
		return
	_roll_the_epilogue(look, palette)


## The F1 panel's way to the ending: the player's own wizard has won.
func go_to_epilogue() -> void:
	if _leaving:
		return
	_roll_the_epilogue(player.look, player.palette)


## The screen goes black, and the epilogue plays in the waiting room's place.
func _roll_the_epilogue(look: String, palette: int) -> void:
	_leaving = true
	_leave_network_scene()
	Epilogue.winner_look = look
	Epilogue.winner_palette = palette
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
	tween.tween_callback(get_tree().change_scene_to_file.bind("res://scenes/epilogue.tscn"))


## The end of a network match: everyone is back in the waiting room, for the next one.
@rpc("authority", "call_remote", "reliable")
func _back_to_room() -> void:
	if not is_inside_tree():
		return
	if Net.is_host():
		Net.send(self, &"_back_to_room")
	_fade_to_room()


## The screen goes black, and then it is the waiting room again.
func _fade_to_room() -> void:
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
	ledgers = MatchState.ledgers if _carried else Pages.start_empty(WIZARDS)  # nobody starts with a spell: the pages they would have started with lie by their spawn
	MatchState.ledgers = ledgers
	player.ledger = ledgers[_my_seat()]
	spellbook.refresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7919  # the pages come from the seed, apart from the rest of the map
	var gate_kinds := []
	for entry in _gates:
		if not gate_kinds.has(entry["kind"]):
			gate_kinds.append(entry["kind"])
	# What lies in a world was settled when the match began: each world has pages of its own, apart from the ones the wizards were dealt.
	var allotment := MatchState.page_allotment(WIZARDS)
	var spare: Array[String] = []
	spare.assign(allotment["spare"])
	var layout := Pages.plan(graph, rng, Pages.deal(MatchState.seed_base + 31, WIZARDS), allotment["worlds"][MatchState.stage], gate_kinds, spare, ledgers if _carried else Pages.deal(MatchState.seed_base + 31, WIZARDS))  # (the pages in the clusters count as held, for the gates' openers)
	if _flies():
		_lay_sky_pages(layout)
		if not _carried:
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
			pickup.position = floor_under(Vector2((column + 0.5) * TILE, graph.surface["floor"][column] * TILE - 40.0))
			add_child(pickup)
			continue
		var spot := _stand_at(_markers[room])
		var k: int = count.get(room, 0)
		count[room] = k + 1
		var lie := spot + Vector2((k - 0.5) * 70.0 if k > 0 else 0.0, 0.0)
		pickup.position = floor_under(lie)  # on the floor, wherever the marker's tile ends
		add_child(pickup)
	if not _carried:
		_lay_clusters(layout.size())


## The sky's pages: each starts somewhere in the air and rises through the falling wizards, round and round (FallingPage).
func _lay_sky_pages(layout: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7933
	var box := _fly_box()
	for index in layout.size():
		var pickup := FallingPage.new()
		pickup.name = "Page%d" % index  # the same on every machine, so the host can say which was read
		pickup.page = layout[index]["page"]
		pickup.rate = rng.randf_range(FallingPage.RATE_LEAST, FallingPage.RATE_MOST)
		var shown_at := rng.randf_range(box.position.y + 120.0, box.end.y - 120.0)
		pickup.home = Vector2(rng.randf_range(box.position.x + 600.0, box.end.x - 600.0), shown_at + PagePickup.FLOAT)
		pickup.box = box
		_timed.append(pickup)
		add_child(pickup)


## How many tiles apart the pages of a cluster lie, and the farthest from the spawn they may lie.
const CLUSTER_GAP := 3
const CLUSTER_REACH := 30


## In the first world, the pages each wizard would have started with lie together by their spawn, fanned out like cards, a short walk away on level
## ground, so nobody needs a spell to reach them. `first` numbers the pages after the ones the map already has.
func _lay_clusters(first: int) -> void:
	var places := _places()
	var index := first
	for seat in WIZARDS:
		var pages := Pages.cluster_of(MatchState.seed_base, seat, WIZARDS)
		if pages.is_empty():
			continue
		if _flies():
			var floating := FallingPage.new()  # in the sky they hang by the place, and do not drift
			floating.name = "Page%d" % index
			index += 1
			floating.page = pages[0]
			floating.spoils.assign(pages)
			floating.fan = true
			floating.home = places[seat] + Vector2(180.0, PagePickup.FLOAT - 40.0)
			floating.rate = 0.0
			floating.box = _fly_box()
			_timed.append(floating)
			add_child(floating)
			continue
		var pickup := PagePickup.new()  # all of a wizard's first pages lie together, fanned out like cards, and one read takes them all
		pickup.name = "Page%d" % index  # the same on every machine, so the host can say which was read
		index += 1
		pickup.page = pages[0]
		pickup.spoils.assign(pages)
		pickup.fan = true
		pickup.position = _cluster_spots(places[seat], 1)[0]
		add_child(pickup)


## Where `count` pages may lie by a spawn: on the ground a wizard can walk to without a jump, nearest first, a few tiles apart. A spawn with
## too little room round it gets the rest set down on the last spot, a little to one side of each other.
func _cluster_spots(origin: Vector2, count: int) -> Array[Vector2]:
	var feet := floor_under(origin - Vector2(0.0, 8.0))
	var column := floori(origin.x / TILE)
	var reachable: Array[Vector2] = []  # the floor at each column a wizard can walk to, nearest first
	for side in [1, -1]:
		var last := feet
		for step in range(1, CLUSTER_REACH):
			var at: int = column + step * side
			var floor_at := floor_under(Vector2((at + 0.5) * TILE, last.y - 8.0))
			if absf(floor_at.y - last.y) > TILE or absf(floor_at.y - feet.y) > TILE * 3.0:
				break  # a step too high, or a drop, ends the walk
			if _in_rock(Vector2(floor_at.x, floor_at.y - 24.0)) or _in_rock(Vector2(floor_at.x, floor_at.y - 56.0)):
				break  # a wall, or a low ceiling
			if absf(floor_at.y - graph.surface["floor"][clampi(at, 0, graph.surface["floor"].size() - 1)] * float(TILE)) < TILE * 2.5 and Pages.in_the_way(graph, at):
				break  # a pool, a pit of mud or a thicket
			last = floor_at
			reachable.append(floor_at)
	reachable.sort_custom(func(a: Vector2, b: Vector2) -> bool: return absf(a.x - origin.x) < absf(b.x - origin.x))
	var out: Array[Vector2] = []
	for spot in reachable:
		var gap_ok := true
		for other in out:
			gap_ok = gap_ok and absf(other.x - spot.x) >= CLUSTER_GAP * TILE - 1.0
		if gap_ok and absf(spot.x - origin.x) >= (CLUSTER_GAP - 1) * TILE:
			out.append(spot)
		if out.size() == count:
			break
	while out.size() < count:  # no room: the rest lie on the spots there are, or on the spawn's own floor
		var base := out[out.size() % maxi(out.size(), 1)] if not out.is_empty() else feet
		out.append(base + Vector2((out.size() % 3 - 1) * 48.0, 0.0))
	return out


## The large jungle tree that stands at this column, or an empty dictionary.
func _tree_at(column: int) -> Dictionary:
	for tree: Dictionary in graph.surface["trees"]:
		if tree["column"] == column and tree["size"] >= 2:
			return tree
	return {}


## The top of the floor under a point (out of the rock first when it is in it), asked of the tiles, which are there before the ground is built.
func floor_under(point: Vector2) -> Vector2:
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

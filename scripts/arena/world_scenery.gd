class_name WorldScenery
extends RefCounted

## What a world is dressed with: the landmarks of its biome, its living scenery (mist, bats, rope bridges, avalanches, lava that swells and the rest),
## the sea, the clouds of the sky, the thickets of thorns and banks of gas along its passages. Each biome has a function of its own.

const GRAVES := ["grave_1", "grave_2", "grave_3", "grave_4"]
const SEA_LENGTH := 1536.0  # how long each length of the sea is
const START_RAFT := 160.0   # how wide the driftwood a wizard starts on is
const THORN_CHUNK := 5  # tiles of floor in a thicket of the world

var gale: MountainGale  # the snowy peaks' wind, when this world has it
var squall: Squall  # the jungle's downpours or the ashlands' ash storms, when this world has them
var sea_plan: Dictionary  # the ocean's sea, wrecks and islands (SurfaceGen._sea_of), or empty
var timed: Array[Node] = []  # the avalanche and the lava lakes' swells: each is told the world's age every frame

var world: World


func _init(owner: World) -> void:
	world = owner


## What lives in each biome besides the landmarks: the graveyard's low mist, bats and crypts; the jungle's rope bridges, light and birds,
## and its downpours; the peaks' avalanches and sheets of ice; the ashlands' swelling lava, ash storms and falling embers.
func raise_biome_life() -> void:
	match SurfaceGen.biome_at(world.graph.surface, world.graph.surface["start"]):
		"graveyard":
			_life_graveyard()
		"jungle":
			_life_jungle()
		"mountains":
			_life_mountains()
		"ocean":
			_life_ocean()
		"sky":
			_life_sky()
		"portals":
			_life_portals()
		"underground":
			_life_underground()
		"ashlands":
			_life_ashlands()


func _life_graveyard() -> void:
	var floors: PackedInt32Array = world.graph.surface["floor"]
	var tile := float(World.TILE)
	var mist := MistBank.new()
	mist.floors = floors
	mist.seed_value = world.seed_value + 17
	world.add_child(mist)
	var bats := CritterFlock.new()
	bats.bats = true
	bats.span = Vector2(SurfaceGen.MARGIN * tile, (WorldGraph.size.x - SurfaceGen.MARGIN) * tile)
	bats.sky = SurfaceGen.BASE_ROW * tile
	bats.seed_value = world.seed_value + 23
	world.add_child(bats)
	for column: int in world.graph.surface["crypts"]:
		var crypt := Crypt.new()
		crypt.position = Vector2((column + 0.5) * tile, floors[column] * tile + 2.0)
		world.add_child(crypt)
		var guard: Mob = world.add_mob("basic", world.floor_under(Vector2((column + 4.5) * tile, floors[column] * tile - 40.0)))
		guard.max_hp = WorldCreatures.DEAD_HEALTH
		guard.hp = WorldCreatures.DEAD_HEALTH
		world.creatures.enlist(guard)  # kept in step across the network like the roaming dead


func _life_jungle() -> void:
	var floors: PackedInt32Array = world.graph.surface["floor"]
	var tile := float(World.TILE)
	var perches: Array[Vector2] = []
	var trees: Array = world.graph.surface["trees"]
	for k in trees.size():
		var tree: Dictionary = trees[k]
		var column: int = tree["column"]
		perches.append(Vector2((column + 0.5) * tile, floors[column] * tile - 230.0 * tree["size"] * 0.9))
		if k % 3 == 1:
			var shaft := LightShaft.new()
			shaft.position = Vector2((column + 0.5) * tile + 70.0, floors[column] * tile - 260.0)
			shaft.phase = k
			world.add_child(shaft)
	var birds := CritterFlock.new()
	birds.perches = perches
	birds.seed_value = world.seed_value + 29
	world.add_child(birds)
	for bridge: Dictionary in JungleTree.bridges(trees, floors):
		var span := CanopyBridge.new()
		span.width = (bridge["last"] - bridge["first"] + 1) * tile
		span.position = Vector2(bridge["first"] * tile, floors[bridge["tree"]] * tile + 2.0 - JungleTree.LEDGES[JungleTree.VINE_LEDGE][0] * float(tree_size(bridge["tree"])))
		world.add_child(span)
	squall = Squall.new()
	squall.rain = true
	squall.period = 75.0
	squall.length = 20.0
	squall.delay = 28.0
	squall.tint = Color(0.02, 0.06, 0.08)
	squall.strength = 0.45
	world.add_child(squall)


func _life_mountains() -> void:
	var floors: PackedInt32Array = world.graph.surface["floor"]
	var tile := float(World.TILE)
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed_value + 8101
	var slide := Avalanche.new()
	slide.floors = floors
	slide.seed_value = world.seed_value + 41
	world.add_child(slide)
	timed.append(slide)
	var ridges := MountainRidges.new()  # a second range behind the ground, to climb over and drop down from
	ridges.floors = floors
	ridges.seed_value = world.seed_value + 53
	ridges.tile = tile
	ridges.earth = world.terrain().earth_texture  # the same rock as the ground in front, and its lip
	ridges.lip = world.terrain().lip
	ridges.snow = world.terrain().snow_pack
	ridges.snow_lip = world.terrain().snow_lip
	ridges.snow_line = float(WorldGraph.SURFACE_ROW - int(SurfaceGen.LOOKS["mountains"]["snow"])) * float(tile)
	world.add_child(ridges)
	var column := SurfaceGen.MARGIN + 20
	while column < floors.size() - SurfaceGen.MARGIN - 20:  # sheets of ice on the level stretches
		var run := 1
		while column + run < floors.size() and floors[column + run] == floors[column]:
			run += 1
		if run >= 8 and rng.randf() < 0.6:
			var sheet := IceSheet.new()
			sheet.width = (run - 2) * tile
			sheet.position = Vector2((column + 1) * tile, floors[column] * tile)
			world.add_child(sheet)
		column += run


func _life_ocean() -> void:
	lay_sea()


func _life_sky() -> void:
	raise_clouds()


func _life_portals() -> void:
	var floors: PackedInt32Array = world.graph.surface["floor"]
	var tile := float(World.TILE)
	var field := PortalField.new()
	field.seed_value = world.seed_value + 71
	field.floors = floors
	field.tile = tile
	field.margin = SurfaceGen.MARGIN + 12
	world.add_child(field)
	timed.append(field)


func _life_underground() -> void:
	var floors: PackedInt32Array = world.graph.surface["floor"]
	var cave := CaveLife.new()
	cave.floors = floors  # (a roofed world keeps no sky of its own: its roof is worked out from the ground)
	cave.seed_value = world.seed_value + 61
	cave.player = world.player
	cave.earth = world.earth_texture()
	world.add_child(cave)
	timed.append(cave)


func _life_ashlands() -> void:
	var floors: PackedInt32Array = world.graph.surface["floor"]
	squall = Squall.new()
	squall.period = 70.0
	squall.length = 18.0
	squall.delay = 30.0
	squall.tint = Color(0.1, 0.05, 0.03)
	squall.strength = 0.38
	world.add_child(squall)
	var embers := EmberRain.new()
	embers.squall = squall
	embers.seed_value = world.seed_value + 53
	embers.player = world.player
	embers.floors = floors
	world.add_child(embers)
	for pond: Node in world.get_children():
		if pond is Pond and pond.lava:
			var surge := LavaSurge.new()
			surge.width = pond.width
			surge.phase = fmod(pond.position.x * 0.013, 13.0)
			surge.position = pond.position
			world.add_child(surge)
			timed.append(surge)


## The landmarks of an open biome: the craters of the ashlands' volcanoes, the jungle's pits of mud and thickets of thorns.
func lay_landmarks() -> void:
	var t := float(World.TILE)
	var floors: PackedInt32Array = world.graph.surface["floor"]
	for crater: Dictionary in world.graph.surface["craters"]:
		var eruption := Eruption.new()
		eruption.ground = world.terrain()
		eruption.name = "Crater%d" % crater["x"]  # the same on every machine, so the host can tell the others when it wakes
		eruption.position = Vector2((crater["x"] + 0.5) * t, crater["row"] * t)
		world.add_child(eruption)
	for pit: Dictionary in world.graph.surface["mud"]:
		var mud := Mudslide.new()
		var middle: int = (pit["a"] + pit["b"]) / 2
		mud.width = (pit["b"] - pit["a"] + 1) * t
		mud.position = Vector2((pit["a"] + pit["b"] + 1) * 0.5 * t, floors[middle] * t)
		var heights := PackedFloat32Array()
		for i in Mudslide.SAMPLES:
			var column := clampi(pit["a"] + roundi(float(pit["b"] - pit["a"]) * i / (Mudslide.SAMPLES - 1)), 0, floors.size() - 1)
			var x := mud.position.x + lerpf(-mud.width * 0.5, mud.width * 0.5, float(i) / (Mudslide.SAMPLES - 1))
			heights.append(world.terrain().surface_near(x, floors[column] * t) - mud.position.y)  # the ground as drawn, which is rounded off, not the row's own top
		mud.planted_ground = heights
		mud.modulate = Color(0.36, 0.42, 0.26)  # dark green-brown jungle mud, not the sand of the spell
		world.add_child(mud)
	for thicket: Dictionary in world.graph.surface["thorns"]:
		grow_thorns({"floors": floors.slice(thicket["a"], thicket["b"] + 1), "first": thicket["a"]})


## The graveyard's tombstones: one now and then along the whole ground, from the seed, leaning a little. They are only to be seen.
func plant_graves() -> void:
	if SurfaceGen.biome_at(world.graph.surface, world.graph.surface["start"]) != "graveyard":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed_value + 1291
	var floors: PackedInt32Array = world.graph.surface["floor"]
	var column := SurfaceGen.MARGIN + 6
	while column < floors.size() - SurfaceGen.MARGIN - 6:
		var grave := Sprite2D.new()
		grave.texture = load("res://art/props/%s.png" % GRAVES[rng.randi() % GRAVES.size()])
		grave.offset = Vector2(0, -grave.texture.get_height() * 0.5 + 3.0)  # it stands on the ground
		grave.flip_h = rng.randf() < 0.5
		grave.rotation = rng.randf_range(-0.06, 0.06)
		grave.position = Vector2((column + 0.5) * World.TILE, floors[column] * float(World.TILE) + 2.0)
		grave.z_index = -1
		world.add_child(grave)
		column += rng.randi_range(3, 9)


## The jungle's great trees: one now and then along the ground, from the seed, where it is level and clear of the pits, the pools and the
## places the wizards start from. The large ones have a branch with a vine to climb to it.
func grow_trees() -> void:
	var floors: PackedInt32Array = world.graph.surface["floor"]
	for entry: Dictionary in world.graph.surface["trees"]:
		var column: int = entry["column"]
		var tree := JungleTree.new()
		tree.size = entry["size"]
		tree.mirror = entry["mirror"]
		tree.vine_ground = float(floors[column + JungleTree.layout(tree.size, tree.mirror)["vine"]] - floors[column]) * World.TILE
		tree.position = Vector2((column + 0.5) * World.TILE, floors[column] * float(World.TILE) + 2.0)
		var lowest := floors[column]
		for c in range(column - JungleTree.FOOTPRINT, column + JungleTree.FOOTPRINT + 1):
			lowest = maxi(lowest, floors[c])
		tree.drop = float(lowest - floors[column]) * World.TILE  # where the ground falls away under its roots, they go on down to it
		world.add_child(tree)


## The snowy peaks have wind that grows toward the summits, and clouds of snow drifting past.
func raise_the_gale() -> void:
	if SurfaceGen.biome_at(world.graph.surface, world.graph.surface["start"]) != "mountains":
		return
	gale = MountainGale.new()
	world.add_child(gale)
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed_value + 2713
	var width := WorldGraph.size.x * float(World.TILE)
	for k in WorldGraph.size.x / 45:
		var cloud := SnowCloud.new()
		cloud.position = Vector2(rng.randf_range(0.0, width), (SurfaceGen.BASE_ROW - rng.randf_range(10.0, 56.0)) * float(World.TILE))
		cloud.drift = rng.randf_range(18.0, 46.0)
		cloud.left = -300.0
		cloud.right = width + 300.0
		world.add_child(cloud)


## The ocean: the sea over the whole world (a deep Pond), driftwood floating on it, kelp and wrecks on its floor.
func lay_sea() -> void:
	var tile := float(World.TILE)
	var floors: PackedInt32Array = world.graph.surface["floor"]
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed_value + 8209
	var whole: float = ArenaGen.world_size.x * tile
	var left := 0.0
	while left < whole:  # the sea is laid in lengths, so that only the ones in view are drawn
		var sea := Pond.new()
		sea.deep = true
		sea.width = minf(SEA_LENGTH, whole - left)
		sea.depth = sea_plan["depth"] * tile + 16.0
		sea.position = Vector2(left, sea_plan["row"] * tile)
		sea.clip = world.terrain().air_loops
		world.add_child(sea)
		left += SEA_LENGTH
	var wrecks: Array = sea_plan["wrecks"]
	for k in wrecks.size():
		var at_column: int = wrecks[k]
		var wreck := Wreck.new()
		wreck.seed_value = world.seed_value + 83 + k
		wreck.clip = world.terrain().air_loops
		wreck.position = Vector2((at_column + 0.5) * tile, floors[at_column] * tile)
		world.add_child(wreck)
	var starts: Array = world.graph.surface["starts"].duplicate()  # where nothing else floats: the starting places, and the rafts
	for spawn in world.spawn_tiles:  # each wizard starts on a raft of driftwood over its place, out at sea
		if spawn.y + 1 <= int(sea_plan["row"]):
			continue  # (a place on an island stands on the island)
		var raft := Driftwood.new()
		raft.width = START_RAFT
		raft.phase = rng.randf() * TAU
		raft.position = world.stand_at(spawn)
		world.add_child(raft)
		starts.append(spawn.x)
	var column := SurfaceGen.MARGIN + 20
	while column < floors.size() - SurfaceGen.MARGIN - 20:  # driftwood on the waterline over the deep, kelp on the floor below it
		var step := rng.randi_range(9, 16)
		if floors[column] >= int(sea_plan["row"]) + SurfaceGen.SEA_DEPTH_LEAST - 4:
			var clear := true
			for spot in starts + wrecks:
				clear = clear and absi(column - int(spot)) > 10
			if clear:
				if rng.randf() < 0.55:
					var wood := Driftwood.new()
					wood.width = 96.0 if rng.randf() < 0.6 else 128.0
					wood.phase = rng.randf() * TAU
					wood.position = Vector2((column + 0.5) * tile, sea_plan["row"] * tile)
					world.add_child(wood)
				else:
					var kelp := KelpPatch.new()
					kelp.seed_value = world.seed_value + column
					for s in rng.randi_range(5, 9):
						var at: int = clampi(column + s, 0, floors.size() - 1)
						kelp.bases.append(Vector2((at + 0.5) * tile + rng.randf_range(-6.0, 6.0), floors[at] * tile))
					world.add_child(kelp)
		column += step


## The sky: clouds that rise past the wizards, and thunderclouds among them.
func raise_clouds() -> void:
	var box := world.fly_box()
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed_value + 8221
	var span := Rect2(box.position.x, box.position.y - 400.0, box.size.x, box.size.y + 800.0)
	var plain := maxi(8, int(box.size.x / 450.0))  # (owner, 2026-11-12: more of them)
	var storms := maxi(3, int(box.size.x / 2000.0))
	for k in plain + storms:
		var cloud := SkyCloud.new()
		cloud.storm = k >= plain
		cloud.kind = rng.randi_range(0, 2)
		cloud.seed_value = world.seed_value * 13 + k
		cloud.span = span
		cloud.home = Vector2(rng.randf_range(span.position.x, span.end.x), rng.randf_range(span.position.y, span.end.y))
		cloud.rise = rng.randf_range(25.0, 45.0) if cloud.storm else rng.randf_range(25.0, 70.0)
		cloud.side = rng.randf_range(-12.0, 12.0)
		cloud.period = rng.randf_range(5.0, 8.0)
		cloud.phase = rng.randf_range(0.0, cloud.period)
		timed.append(cloud)
		world.add_child(cloud)


## How large the great tree standing in a column is (1 to 3 times its picture).
func tree_size(column: int) -> int:
	for tree: Dictionary in world.graph.surface["trees"]:
		if tree["column"] == column:
			return tree["size"]
	return 2


## The graveyard is seen in gray: a layer over the world, under the interface, that takes the color out of it.
func wash_out_the_color() -> void:
	if SurfaceGen.biome_at(world.graph.surface, world.graph.surface["start"]) != "graveyard":
		return
	world.grayed = true  # (the Scrying Eye's window is washed out too)
	var layer := CanvasLayer.new()
	layer.layer = 2
	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/ui/grayscale.gdshader")
	wash.material = material
	layer.add_child(wash)
	world.add_child(layer)


## Thorns over a stretch of a passage's floor, grown in thickets a few tiles long, so fire burns one thicket at a time and a way
## can be burnt through them. They are the thorns of the Bramble spell.
func grow_thorns(entry: Dictionary) -> void:
	entry["nodes"] = []
	entry["per"] = THORN_CHUNK
	var floors: PackedInt32Array = entry["floors"]
	var first: int = entry["first"]
	var t := float(World.TILE)
	var chunk := THORN_CHUNK
	for start in range(0, floors.size(), chunk):
		var points := PackedVector2Array()
		var x: float = (first + start) * t
		var end: float = (first + mini(start + chunk, floors.size())) * t
		while x < end:
			var column := clampi(int(floor(x / t)) - first, 0, floors.size() - 1)
			points.append(Vector2(x, world.terrain().surface_near(x, floors[column] * t)))
			x += Bramble.SPACING
		var thorns := Bramble.new()
		thorns.planted_ground = points
		world.add_child(thorns)
		entry["nodes"].append(thorns)


## Banks of gas along a passage, each from the floor to the roof.
func spread_gas(entry: Dictionary) -> void:
	entry["nodes"] = []
	entry["per"] = WorldBuilder.GAS_BANK
	for bank: Dictionary in entry["banks"]:
		var gas := GasBank.new()
		gas.column = bank["x"]
		gas.floors = bank["floors"]
		gas.tops = bank["tops"]
		world.add_child(gas)
		entry["nodes"].append(gas)

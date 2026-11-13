class_name WorldCreatures
extends RefCounted

## The things that roam a world: the graveyard's dead walk it (skeletons), and the castle world has knights on guard and a giant that wanders between
## the castles. They amble about until a wizard comes near, then give chase. They rise from the ground at places the seed picks, and (like all of a
## world's mobs) only trouble the player of the machine they stand on. The host moves them and tells the others where they are.

const DEAD_HEALTH := 15  # what one of the graveyard's skeletons has: a spell or two puts it down
const DEAD_PER_COLUMNS := 90  # the graveyard has a skeleton for this many columns of its width
const GIANT_ROOMS := [7, 24, 33, 50, 59, 76]  # columns from a castle's west end to the middle of a ground-floor room with open floor
const UPPER_KNIGHT_PER_COLUMNS := 160  # and fewer on the floors above, one for this many columns
const KNIGHT_PER_COLUMNS := 80  # the castle world has a knight on guard for this many columns of its width
const GIANT_PER_COLUMNS := 300  # the castle world has a giant for this many columns of its width
const DEAD_KEEP_AWAY := 45  # columns from every starting place that none rise

var dead: Array[Mob] = []  # the roaming mobs, in the order the seed raised them: the host's move, the others' show
var world: World

var _sent := 0.0


func _init(owner: World) -> void:
	world = owner


## A roaming mob joins the dead: it is named the same on every machine (so that the host's can tell the others' puppets what it does) and is kept
## in step across the network.
func enlist(mob: Mob) -> void:
	mob.name = "Dead%d" % dead.size()
	mob.shared = true
	mob.puppet = not Net.is_host()
	dead.append(mob)


## On the host, tells the others a few times a second where each of the dead is, which way it faces and whether it is drawing back to strike.
func share(delta: float) -> void:
	if dead.is_empty() or not Net.online() or not Net.is_host():
		return
	_sent += delta
	if _sent < 0.05:
		return
	_sent = 0.0
	var places := PackedVector2Array()
	var faces := PackedFloat32Array()
	var swings := PackedByteArray()
	for mob in dead:
		var here := is_instance_valid(mob) and not mob.is_dead()
		places.append(mob.global_position if here else Vector2.ZERO)
		faces.append(mob.facing if here else 1.0)
		swings.append(1 if here and mob.is_drawing_back() else 0)
	Net.send(world, &"_dead_at", [places, faces, swings])


## What the host says of the dead: each is put where the host's one is, and faces and strikes as it does.
func receive(places: PackedVector2Array, faces: PackedFloat32Array, swings: PackedByteArray) -> void:
	for k in mini(places.size(), dead.size()):
		var mob := dead[k]
		if is_instance_valid(mob) and not mob.is_dead() and places[k] != Vector2.ZERO:  # (nothing at the origin means the host's one is gone)
			mob.net_position = places[k]
			mob.net_facing = faces[k]
			mob.net_swing = swings[k] == 1


## The biome's roamers rise: skeletons in the graveyard, giants and knights in the castle world.
func raise() -> void:
	var biome := SurfaceGen.biome_at(world.graph.surface, world.graph.surface["start"])
	if biome == "graveyard":
		_raise_roamers("basic", WorldGraph.size.x / DEAD_PER_COLUMNS, 4409)
	elif biome == "castle":
		_raise_roamers("giant", maxi(2, WorldGraph.size.x / GIANT_PER_COLUMNS), 6143)
		_raise_roamers("knight", maxi(4, WorldGraph.size.x / KNIGHT_PER_COLUMNS), 7919)
		_raise_upper_knights(maxi(2, WorldGraph.size.x / UPPER_KNIGHT_PER_COLUMNS), 7933)


## Knights on guard on the upper floors of the castles, each a few columns from a spot where a page may lie (one of Pages.CASTLE_SPOTS above the ground).
func _raise_upper_knights(wanted: int, salt: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed_value + salt
	var castles: Array = world.graph.surface["castles"]
	var spots: Array[Vector2i] = []
	for spot: Vector2i in Pages.CASTLE_SPOTS:
		if spot.y > 0:
			spots.append(spot)
	if castles.is_empty() or spots.is_empty():
		return
	for i in wanted:
		var spot: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
		var castle_at: int = castles[rng.randi_range(0, castles.size() - 1)]
		var up := Vector2((castle_at + spot.x + 3.5) * World.TILE, (WorldGraph.SURFACE_ROW - spot.y) * World.TILE - 40.0)
		var mob: Mob = world.add_mob("knight", world.floor_under(up))
		mob.guards = true
		mob.post_x = mob.global_position.x
		enlist(mob)


func _raise_roamers(kind: String, wanted: int, salt: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed_value + salt
	var castles: Array = world.graph.surface["castles"]
	var tries := 0
	while wanted > 0 and tries < 400:
		tries += 1
		var column := rng.randi_range(SurfaceGen.MARGIN + 10, WorldGraph.size.x - SurfaceGen.MARGIN - 10)
		if not castles.is_empty():  # in the castle world they walk the ground floors, in a room with a clear floor
			column = castles[rng.randi_range(0, castles.size() - 1)] + GIANT_ROOMS[rng.randi_range(0, GIANT_ROOMS.size() - 1)]
		var near := false
		for spawn in world.spawn_tiles:
			near = near or absi(spawn.x - column) < DEAD_KEEP_AWAY
		if near:
			continue
		var mob: Mob = world.add_mob(kind, world.floor_under(Vector2((column + 0.5) * World.TILE, world.graph.surface["floor"][column] * World.TILE - 40.0)))
		if kind == "basic":
			mob.max_hp = DEAD_HEALTH
			mob.hp = DEAD_HEALTH
		if kind == "knight":
			mob.guards = true
			mob.post_x = mob.global_position.x
		else:
			mob.roams = true
		enlist(mob)
		wanted -= 1

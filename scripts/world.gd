class_name World
extends "res://scripts/arena.gd"

## A generated world: a web of halls joined by tunnels, built from a seed (see WorldGraph and WorldBuilder).
## This first version is only the ground to walk through; enemies, pages, gates and the boss come later. The player
## starts in the start hall and can walk to every other one. The seed is shown on screen as its incantation.

## The seed to build from. The waiting room's portal sets it before the world loads; a world opened directly gets a random one.
static var next_seed := -1

var seed_value := 0
var graph: WorldGraph
var _markers := {}
var _ponds := []
var castle_x := -1  # the first column of the castle on the surface, or -1 when there is none


## The world's tiles, built from the seed. Everything the generator decides comes from this one rng.
func _build_map() -> Dictionary:
	seed_value = next_seed if next_seed >= 0 else randi() % Incantation.seed_count()
	next_seed = -1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	graph = WorldGraph.build(rng)
	var built := WorldBuilder.build(graph, rng)
	_markers = built["markers"]
	_ponds = built["ponds"]
	castle_x = built["castle"]
	ArenaGen.world_size = built["size"]
	ArenaGen.sky_xl = built["sky"]["xl"]
	ArenaGen.sky_floor = built["sky"]["floor"]
	tiled_ground = true
	_start_tile = built["start"]
	return built["cells"]


var _start_tile := Vector2i.ZERO


func _where_are_we() -> Dictionary:
	return {"level": 0, "wave": 0, "count": 0, "biome": "cemetery"}


func _begin_encounter(camera: Camera2D) -> void:
	player.position = _stand_at(_start_tile)
	_safe_spot = player.position
	camera.reset_smoothing()
	player.focus = "wand"
	_director = WaveDirector.new()  # there are no waves yet; the director only has to exist
	_director.arena = self
	_director.set_process(false)
	add_child(_director)
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
	hud.banner("A new world", Incantation.words_for(seed_value))


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
	var material: int = _cells.get(cell, -1)
	return material == ArenaGen.GROUND or material == ArenaGen.STONE


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
	if player.dead:
		return
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

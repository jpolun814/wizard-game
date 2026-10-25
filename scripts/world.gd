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
const DEEP := Color(0.3, 0.27, 0.42)  # the colour of everything unlit, just under the ground
const BLACK := Color(0.015, 0.015, 0.03)  # and far down: nothing shows without a light
const DARKEN_ROWS := 16.0  # how far under the surface it takes for the light of the day to fade
const BLACKEN_ROWS := 110.0  # and for the dark to become total

var _dark: CanvasModulate
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
	ArenaGen.castle_hall = built["hall"]
	tiled_ground = true
	_start_tile = built["start"]
	return built["cells"]


var _start_tile := Vector2i.ZERO


func _begin_encounter(camera: Camera2D) -> void:
	player.position = _stand_at(_start_tile)
	_safe_spot = player.position
	camera.reset_smoothing()
	player.focus = "wand"
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
	_dark = CanvasModulate.new()  # under the ground it is dark; only fire and the flare light the way
	_dark.add_to_group("darkness")
	add_child(_dark)
	get_tree().node_added.connect(_on_node_added)
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
	var depth := clampf((player.global_position.y - (WorldGraph.SURFACE_ROW + 2) * TILE) / (DARKEN_ROWS * TILE), 0.0, 1.0)
	var far := clampf((player.global_position.y - (WorldGraph.SURFACE_ROW + 2) * TILE - DARKEN_ROWS * TILE) / ((BLACKEN_ROWS - DARKEN_ROWS) * TILE), 0.0, 1.0)
	_dark.color = Color.WHITE.lerp(DEEP, depth).lerp(BLACK, far)
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
	if node is Pond or node is Hazard or node is Projectile or node is Firewall or node is FireBreath or node is LavaBall:
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
		node.add_child(_make_light(260.0, Color(1.0, 0.6, 0.25), 1.1))


## A Rift sets the wizard down in another hall, picked by chance: not the boss's, and none behind a gate (there are no gates yet).
func _rift_spot(from: Vector2) -> Vector2:
	var spots: Array[Vector2] = []
	for room in graph.rooms:
		if room["id"] == graph.boss:
			continue
		var spot := _stand_at(_markers[room["id"]])
		if spot.distance_to(from) > 400.0:
			spots.append(spot)
	return spots[randi() % spots.size()] if not spots.is_empty() else from

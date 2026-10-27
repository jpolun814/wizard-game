class_name World
extends "res://scripts/arena.gd"

## A generated world: a web of halls joined by tunnels, built from a seed (see WorldGraph and WorldBuilder).
## Enemies, pages and gates come later. The player
## starts in the start hall and can walk to every other one. The seed is shown on screen as its incantation.

## The seed to build from. The waiting room's portal sets it before the world loads; a world opened directly gets a random one.
static var next_seed := -1

var seed_value := 0
var graph: WorldGraph
var _markers := {}
var _ponds := []
var _gates := []
var _castle_doors := []  # [{"x", "floor"}]: where the castle's wooden doors stand
var _weather: Array[Weather] = []
var _gates_open := false
const DEEP := Color(0.3, 0.27, 0.42)  # the colour of everything unlit, just under the ground
const BLACK := Color(0.015, 0.015, 0.03)  # and far down: nothing shows without a light
const DARKEN_ROWS := 16.0  # how far under the surface it takes for the light of the day to fade
const BLACKEN_ROWS := 110.0  # and for the dark to become total

var _dark: CanvasModulate
static var random_start := true  # the start is anywhere on the surface; the showcase and tests turn this off to see the same place each time
var castle_x := -1  # the first column of the castle on the surface, or -1 when there is none


## The world's tiles, built from the seed. Everything the generator decides comes from this one rng.
func _build_map() -> Variant:
	seed_value = next_seed if next_seed >= 0 else randi() % Incantation.seed_count()
	next_seed = -1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	graph = WorldGraph.build(rng)
	var built := WorldBuilder.build(graph, rng)
	_markers = built["markers"]
	_ponds = built["ponds"]
	_gates = built["gates"]
	castle_x = built["castle"]
	ArenaGen.world_size = built["size"]
	ArenaGen.sky_xl = built["sky"]["xl"]
	ArenaGen.sky_floor = built["sky"]["floor"]
	ArenaGen.biome_spans = []
	for biome in graph.surface["biomes"]:
		var span := {"a": biome["a"], "b": biome["b"], "tiles": SurfaceGen.LOOKS[biome["name"]]["tiles"]}
		if SurfaceGen.LOOKS[biome["name"]].has("snow"):
			span["snow"] = SurfaceGen.LOOKS[biome["name"]]["snow"]  # above this many rows over the plains, the ground is snow
		ArenaGen.biome_spans.append(span)
	ArenaGen.castle_hall = built["hall"]
	_castle_doors = built["doors"]
	tiled_ground = true
	_start_tile = built["start"]
	if random_start:
		_start_tile = _random_surface_tile(built["cells"], built["ponds"], built["sky"], _start_tile)
	return built["cells"]


const THORN_CHUNK := 5  # tiles of floor in a thicket of the world
var _start_tile := Vector2i.ZERO
var _backdrops := {}  # place -> Backdrop


## Each biome has a backdrop of its own, all of them in place at once and one shown at a time: walking from one biome to the next
## fades the sky and scenery of the one into the other, as Terraria does.
func _set_up_backdrops() -> void:
	for child in get_children():
		if child is Backdrop:
			child.queue_free()  # the one the arena made, which has no ground of its own to stand on
	var ground_y := float(SurfaceGen.BASE_ROW * TILE)
	for place in ["cemetery", "swamp", "mountains", "tundra", "ashlands"]:
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


## A spot on the surface to be dropped at, anywhere along the top of the world: level ground clear of the water, lava, castle and
## the mouths of the ways down. The built start is the fallback. This is not seeded, so the same world starts you somewhere new.
func _random_surface_tile(cells: Variant, ponds: Array, sky: Dictionary, fallback: Vector2i) -> Vector2i:
	var floor_rows: PackedInt32Array = sky["floor"]
	var first: int = sky["xl"]
	for attempt in 200:
		var i := randi_range(8, floor_rows.size() - 9)
		var level := floor_rows[i]
		var fits := true
		for k in range(i - 4, i + 5):
			if floor_rows[k] != level or cells.has(Vector2i(first + k, level - 1)) or not cells.has(Vector2i(first + k, level)):
				fits = false
				break
		var x := first + i
		if castle_x >= 0 and x > castle_x - 8 and x < castle_x + SurfaceGen.CASTLE_WIDTH + 8:
			fits = false
		for pond in ponds:
			if x >= pond["a"] - SurfaceGen.POOL_PAD - 6 and x <= pond["b"] + SurfaceGen.POOL_PAD + 6:
				fits = false
		if fits:
			return Vector2i(x, level - 1)
	return fallback


func _begin_encounter(camera: Camera2D) -> void:
	_lay_pages()
	player.position = _stand_at(_start_tile)
	_safe_spot = player.position
	_ground.watch([player.position], true)  # the rock round the start is drawn before the first frame
	camera.reset_smoothing()
	_set_up_backdrops()
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
	for entry: Dictionary in _castle_doors:
		var door := CastleDoor.new()
		door.position = Vector2(entry["x"] * float(TILE), entry["floor"] * float(TILE))
		add_child(door)
	for entry in _gates:
		match entry["kind"]:
			"brambles":
				_grow_thorns(entry)
			"ice":
				var plug := IcePlug.new()
				plug.columns = entry["columns"]
				add_child(plug)
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
			"piranhas":
				var shoal := Piranhas.new()
				var pit: Rect2i = entry["pit"]
				shoal.water = Rect2(pit.position * TILE, Vector2(pit.size * TILE))
				shoal.count = pit.size.x / 3
				add_child(shoal)
	_dark = CanvasModulate.new()  # under the ground it is dark; only fire and the flare light the way
	_dark.add_to_group("darkness")
	add_child(_dark)
	get_tree().node_added.connect(_on_node_added)


## Thorns over a stretch of a passage's floor, grown in thickets a few tiles long, so fire burns one thicket at a time and a way
## can be burnt through them. They are the thorns of the Bramble spell.
func _grow_thorns(entry: Dictionary) -> void:
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


## Banks of gas along a passage, each from the floor to the roof.
func _spread_gas(entry: Dictionary) -> void:
	var t := float(TILE)
	for bank: Dictionary in entry["banks"]:
		var gas := GasBank.new()
		gas.column = bank["x"]
		gas.floors = bank["floors"]
		gas.tops = bank["tops"]
		add_child(gas)


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
	if node is Gateway or node is Pond or node is Hazard or node is Projectile or node is Firewall or node is FireBreath or node is LavaBall:
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


## A Rift sets the wizard down in another hall, picked by chance: not the boss's, and none behind a gate.
func _rift_spot(from: Vector2) -> Vector2:
	var spots: Array[Vector2] = []
	for room in graph.rooms:
		if room["id"] == graph.boss or (room["lock"] != -1 and not _gates_open):
			continue
		var spot := _stand_at(_markers[room["id"]])
		if spot.distance_to(from) > 400.0:
			spots.append(spot)
	return spots[randi() % spots.size()] if not spots.is_empty() else from


## The spellbook of the run: only the starter spells are known, and a page for each of the others lies in a hall of the map.
func _lay_pages() -> void:
	Pages.begin()
	spellbook.refresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7919  # the pages come from the seed, apart from the rest of the map
	var layout := Pages.plan(graph, rng)
	Pages.stash.assign(layout["stash"])
	var count := {}
	for entry: Dictionary in layout["placed"]:
		var room: int = entry["room"]
		var spot := _stand_at(_markers[room])
		var k: int = count.get(room, 0)
		count[room] = k + 1
		var pickup := PagePickup.new()
		pickup.page = entry["page"]
		pickup.position = spot + Vector2((k - 0.5) * 70.0 if k > 0 else 0.0, 0.0)
		add_child(pickup)


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

class_name WorldGates
extends RefCounted

## The gates of a world (ice, walls, thorns, gas, pits, floods, piranhas, sentinels): the pieces each is made of, when one is open, which the wizards may
## ask about (the brains plan their way past them), and the host's word on which pieces are gone. The list of gates itself is `world.gates`.

var opened := false  # the Rift may set a wizard down behind a gate (the F1 panel opens them)

var world: World

var _since := 0.0
var _tour := {}  # kind -> how many times the panel has gone to a gate of that kind, so each press goes to the next one


func _init(owner: World) -> void:
	world = owner


## Every half second: a gate whose ice, wall, thorns or gas are all gone is open, and the wizards' ways are built again without it.
func watch(delta: float) -> void:
	_since += delta
	if _since < 0.5:
		return
	_since = 0.0
	var changed := false
	for entry in world.gates:
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
		world.build_nav()
		if Net.online() and Net.is_host():
			Net.send(world, &"_gates_cleared", [cleared_names()])


## Makes what each gate of the list is made of and puts it in the world, then names the pieces.
func raise_pieces() -> void:
	for entry in world.gates:
		match entry["kind"]:
			"brambles":
				world.scenery.grow_thorns(entry)
			"ice":
				var plug := IcePlug.new()
				plug.columns = entry["columns"]
				world.add_child(plug)
				entry["nodes"] = [plug]
			"wall":
				var wall := RockWall.new()
				wall.columns = entry["columns"]
				world.add_child(wall)
				entry["nodes"] = [wall]
			"dark":
				var bed := SpikeBed.new()
				bed.strips = entry["strips"]
				bed.rock = world.earth_texture()
				world.add_child(bed)
			"gas":
				world.scenery.spread_gas(entry)
			"sentinel":
				var statue := Sentinel.new()
				statue.position = Vector2(Vector2i(entry["stands"]) * World.TILE) + Vector2(World.TILE * 0.5, 0)
				world.add_child(statue)
				entry["post"] = statue
			"piranhas":
				var shoal := Piranhas.new()
				var pit: Rect2i = entry["pit"]
				shoal.water = Rect2(pit.position * World.TILE, Vector2(pit.size * World.TILE))
				shoal.count = pit.size.x / 3
				world.add_child(shoal)
				entry["nodes"] = [shoal]  # killed to a fish, the pit is open
	name_pieces()


## Every piece of a gate has the same name on every machine, so the host can say which are gone.
func name_pieces() -> void:
	for g in world.gates.size():
		var nodes: Array = world.gates[g].get("nodes", [])
		for k in nodes.size():
			nodes[k].name = "Gate%d_%d" % [g, k]


## The names of the pieces of world.gates that are gone, here.
func cleared_names() -> Array[String]:
	var out: Array[String] = []
	for g in world.gates.size():
		var nodes: Array = world.gates[g].get("nodes", [])
		for k in nodes.size():
			if not is_instance_valid(nodes[k]) or nodes[k].is_queued_for_deletion():
				out.append("Gate%d_%d" % [g, k])
	return out


## In a network game each machine runs the world.gates for itself, so a spell that clears one on the host's might just miss on another's. The
## host's are the ones that count: what is gone there goes here too.
func receive_cleared(names: Array) -> void:
	for gate_name: String in names:
		var piece := world.get_node_or_null(NodePath(gate_name))
		if piece != null and not piece.is_queued_for_deletion():
			piece.queue_free()


## The world.gates that spells can clear and have not yet: {"kind", "outside": a floor tile just short of it, "target": a point in pixels to strike}.
func closed() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in world.gates:
		if entry.get("open", false) or not entry.has("nodes"):
			continue
		out.append({"kind": entry["kind"], "outside": entry["outside"], "target": target(entry), "entry": entry})
	return out


## The world.gates that a spell lets a wizard past, and does not clear: {"kind", "key" (see WorldNav.toll_at), "span": the top of a pit, a wall or a stretch of gas in pixels, "post": a sentinel}.
func crossings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in world.gates:
		if entry["kind"] not in WorldBuilder.CROSSINGS:
			continue
		var found := {"kind": entry["kind"], "key": WorldBuilder.toll_key(entry), "post": entry.get("post")}
		if entry.has("pit") or entry["kind"] in ["chasm", "flood"]:
			var rect: Rect2i = entry["solve"][0]["rect"]
			found["span"] = Rect2(Vector2(rect.position * World.TILE), Vector2(rect.size * World.TILE))
		elif entry["kind"] == "gas":
			var stretch: Array = entry["blocks"]
			var first_tile: Vector2i = stretch[0]
			found["span"] = Rect2(Vector2(first_tile * World.TILE), Vector2(stretch.size() * World.TILE, World.TILE))
		elif entry["kind"] == "wall":
			var columns: Array = entry["columns"]
			found["span"] = Rect2(Vector2(columns[0]["x"] * World.TILE, columns[0]["top"] * World.TILE), Vector2(columns.size() * World.TILE, (columns[0]["bottom"] - columns[0]["top"]) * World.TILE))
		out.append(found)
	return out


## The point of a gate to strike: the part of it that is nearest the side one comes by, of what is left of it.
func target(entry: Dictionary) -> Vector2:
	var t := float(World.TILE)
	var outside: Vector2i = entry["outside"]
	match entry["kind"]:
		"brambles":
			var first: int = entry["first"]
			var floors: PackedInt32Array = entry["floors"]
			var best := -1  # the thicket nearest the way in, of those still standing
			for k in entry["nodes"].size():
				var node = entry["nodes"][k]
				if is_instance_valid(node) and not node.is_queued_for_deletion():
					var middle := mini(k * WorldScenery.THORN_CHUNK + WorldScenery.THORN_CHUNK / 2, floors.size() - 1)
					var kept := mini(best * WorldScenery.THORN_CHUNK + WorldScenery.THORN_CHUNK / 2, floors.size() - 1)
					if best < 0 or absi(first + middle - outside.x) < absi(first + kept - outside.x):
						best = k
			var column := mini(maxi(best, 0) * WorldScenery.THORN_CHUNK + WorldScenery.THORN_CHUNK / 2, floors.size() - 1)
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


## The kinds of gate this world has, for the F1 panel.
func kinds() -> Array:
	var kinds := []
	for entry in world.gates:
		if not kinds.has(entry["kind"]):
			kinds.append(entry["kind"])
	return kinds


## Sets the wizard down on the floor just outside a gate of this kind, on the way in from the open side. Each press goes to the next.
func go_to(kind: String) -> void:
	var found := []
	for entry in world.gates:
		if entry["kind"] == kind:
			found.append(entry)
	if found.is_empty():
		return
	var at: Vector2i = found[_tour.get(kind, 0) % found.size()]["outside"]
	_tour[kind] = _tour.get(kind, 0) + 1
	world.player.global_position = Vector2((at.x + 0.5) * float(World.TILE), at.y * float(World.TILE) - 4.0)
	world.player.velocity = Vector2.ZERO
	world.safe_spot = world.player.global_position
	world.terrain().watch([world.player.global_position], true)
	var camera: Camera2D = world.player.get_node_or_null("Camera2D")
	if camera != null:
		camera.reset_smoothing()


## The Rift may now set the wizard down in the locked areas. Spells are what get a wizard in on foot: the F1 panel does this.
func open_all() -> void:
	opened = true

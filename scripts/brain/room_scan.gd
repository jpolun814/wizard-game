class_name RoomScan
extends RefCounted

## What a wizard can make out of a room it has not been told about: the ground (a map of the ways), and, standing on it, what bars the way and what spell
## answers it. It reads only the ground and the things in the room (thorns, gas, walls, water, eyes), so any room built from the same parts is understood the
## same way. It hands the brain what a match's world does (see World.closed_gates and World.crossings), so the brain plays a room as it plays a world.

const SHEER := 5        # rows: a step up this high in one column is a face no jump climbs
const PIT_DEPTH := 3    # rows below both rims: a pit
const STRONG := 1000    # health: so much that no one trades blows with it
const THICKET_GAP := 3  # columns: thorns closer than this are one thicket

var origin := Vector2i.ZERO
var grid: TileGrid
var barred := {}          # tiles (in the grid's own numbering) no one stands in
var tolls := {}           # key -> tiles
var links := []
var crossings: Array[Dictionary] = []   # {"kind", "key", "span": Rect2, "post"}
var gates: Array[Dictionary] = []       # {"kind", "outside": the tile beside the thing, on the near side, "nodes": [..], "first", "last"}
var signature := ""       # changes when something that bars the way has gone


## Reads a room: its ground (a Dictionary of cells), and what stands in the tree.
static func read(tree: SceneTree, cells: Dictionary, start: Vector2i) -> RoomScan:
	var scan := RoomScan.new()
	scan._read(tree, cells, start)
	return scan


func _read(tree: SceneTree, cells: Dictionary, start: Vector2i) -> void:
	var low := Vector2i(1 << 30, 1 << 30)
	var high := Vector2i(-(1 << 30), -(1 << 30))
	for cell: Vector2i in cells:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	origin = low
	grid = TileGrid.new(high - low + Vector2i(1, 1))
	for cell: Vector2i in cells:
		grid.put(cell - low, cells[cell])
	var first := low.x + 1
	var last := high.x - 1
	var floors := {}  # column -> the row of its floor
	for col in range(first, last + 1):
		floors[col] = roundi(ArenaGen.surface_y(cells, col) / float(ArenaGen.TILE))
	var plain := WorldNav.new()  # the room with nothing in it but its ground: which places a wizard can walk between
	plain.origin = origin
	plain.build(grid, grid.size.y)
	_things(tree, floors)
	_faces_and_pits(tree, floors, plain)
	_shoals(tree, floors)
	_finish(floors)
	var parts: Array[String] = []
	for gate in gates:
		if not gate.has("mob"):  # (a creature is not part of the map: it comes and goes)
			parts.append("%s %d %d %d" % [gate["kind"], gate["first"], gate["last"], gate["nodes"].size()])
	signature = "|".join(parts) + "/%d/%d" % [crossings.size(), barred.size()]


## Thorns, gas, walls and eyes: what the room has put in the way.
func _things(tree: SceneTree, floors: Dictionary) -> void:
	var thorns := {}  # column -> the thorns standing there
	for node: Node in tree.get_nodes_in_group("danger"):
		if node is Bramble and not node.planted_ground.is_empty():
			for point: Vector2 in node.planted_ground:
				var col := floori(point.x / float(ArenaGen.TILE))
				if not thorns.has(col):
					thorns[col] = []
				if not (node in thorns[col]):
					thorns[col].append(node)
	var cols: Array = thorns.keys()
	cols.sort()
	var run: Array = []
	for col: int in cols:
		if not run.is_empty() and col - run[-1] > THICKET_GAP:
			_thicket(run, thorns, floors)
			run = []
		run.append(col)
	if not run.is_empty():
		_thicket(run, thorns, floors)
	for node: Node in tree.get_nodes_in_group("clouds"):
		if node is GasBank and not node.is_queued_for_deletion():
			_gas_bank(node, floors)
	for node: Node in tree.get_nodes_in_group("breakables"):
		if node is RockWall and not node.is_queued_for_deletion():
			_wall(node, floors)
	var shooters: Array = tree.get_nodes_in_group("sentinels").duplicate()
	for node: Node in tree.get_nodes_in_group("mobs"):
		if node is Mob and node.kind == "turret" and not node.is_dead():
			shooters.append(node)
	_watchers(shooters, floors)
	for node: Node in tree.get_nodes_in_group("mobs"):
		if node is Mob and not node.is_dead() and not node.is_fainted() and node.KINDS[node.kind].role in ["melee", "ranged"] and node.kind != "turret":
			var col := floori(node.global_position.x / float(ArenaGen.TILE))
			var strong: bool = node.max_hp >= STRONG
			gates.append({"kind": "giant" if strong else "creature", "outside": Vector2i(col - 3, roundi(node.global_position.y / float(ArenaGen.TILE))), "nodes": [node], "mob": node, "first": col, "last": col})


func _floor_tile(col: int, floors: Dictionary) -> Vector2i:
	return Vector2i(col, int(floors.get(col, 0)) - 1)


## A thicket is cleared by fire, and barred until then.
func _thicket(run: Array, thorns: Dictionary, floors: Dictionary) -> void:
	var nodes: Array = []
	for col: int in run:
		for node in thorns[col]:
			if not (node in nodes):
				nodes.append(node)
		barred[_floor_tile(col, floors) - origin] = true
		barred[_floor_tile(col, floors) + Vector2i(0, -1) - origin] = true
	gates.append({"kind": "brambles", "outside": _floor_tile(run[0] - 1, floors) + Vector2i(0, 1), "nodes": nodes, "first": run[0], "last": run[-1]})


## Gas is cleared by fire or wind; it can also be walked through with the breath held (a crossing). Banks lying together are one gate.
func _gas_bank(node: GasBank, floors: Dictionary) -> void:
	var first := floori(node.box.position.x / float(ArenaGen.TILE))
	var last := floori((node.box.end.x - 1.0) / float(ArenaGen.TILE))
	var gate: Dictionary = {}
	for other in gates:
		if other["kind"] == "gas" and first <= int(other["last"]) + 1 and last >= int(other["first"]) - 1:
			gate = other
	if gate.is_empty():
		gate = {"kind": "gas", "outside": Vector2i(first - 1, int(floors.get(first - 1, 0))), "nodes": [], "first": first, "last": last}
		gates.append(gate)
	gate["nodes"].append(node)
	gate["first"] = mini(int(gate["first"]), first)
	gate["last"] = maxi(int(gate["last"]), last)
	gate["outside"] = Vector2i(int(gate["first"]) - 1, int(floors.get(int(gate["first"]) - 1, 0)))


## A wall of brick is broken by stone or a quake, or climbed over by a lift.
func _wall(node: RockWall, floors: Dictionary) -> void:
	var columns: Array = node.columns
	if columns.is_empty():
		return
	gates.append({"kind": "wall", "outside": Vector2i(int(columns[0]["x"]) - 1, int(columns[0]["bottom"])), "nodes": [node], "first": int(columns[0]["x"]), "last": int(columns[-1]["x"]), "columns": columns})


## Eyes and turrets shoot whoever they see, a long way. Those whose sight overlaps are one place to cross, hidden from or covered against.
func _watchers(shooters: Array, floors: Dictionary) -> void:
	var groups: Array = []  # each {"posts": [...], "first": column, "last": column}
	for node in shooters:
		var reach: float = node.get("reach") if node.get("reach") != null else 480.0
		var col := floori(node.global_position.x / float(ArenaGen.TILE))
		var span := ceili(reach / float(ArenaGen.TILE))
		var joined := false
		for group: Dictionary in groups:
			if col - span <= int(group["last"]) and col + span >= int(group["first"]):
				group["posts"].append(node)
				group["first"] = mini(int(group["first"]), col - span)
				group["last"] = maxi(int(group["last"]), col + span)
				joined = true
				break
		if not joined:
			groups.append({"posts": [node], "first": col - span, "last": col + span})
	for group: Dictionary in groups:
		var tiles: Array[Vector2i] = []
		for c in range(int(group["first"]), int(group["last"]) + 1):
			if floors.has(c):
				tiles.append(Vector2i(c, int(floors[c]) - 1))
		var post: Node2D = group["posts"][0]
		var key := "gate %s" % str(Vector2i(int(group["first"]), int(floors.get(int(group["first"]), 0))))
		tolls[key] = tiles
		crossings.append({"kind": "sentinel", "key": key, "span": Rect2(Vector2(int(group["first"]), int(floors.get(int(group["first"]), 0)) - 4) * float(ArenaGen.TILE), Vector2(int(group["last"]) - int(group["first"]) + 1, 4) * float(ArenaGen.TILE)), "post": post, "posts": group["posts"].size()})


## Water with fish in it, however shallow: no one wades it. It is crossed on a way laid over it, like a pit.
func _shoals(tree: SceneTree, floors: Dictionary) -> void:
	for node: Node in tree.get_nodes_in_group("shoals"):
		if not (node is Piranhas) or not node.alive():
			continue
		var first := floori(node.water.position.x / float(ArenaGen.TILE))
		var last := floori((node.water.end.x - 1.0) / float(ArenaGen.TILE))
		var known := false
		for crossing in crossings:
			if crossing["kind"] in ["piranhas", "flood", "chasm"] and crossing.has("fill") and first <= (crossing["fill"] as Rect2i).end.x and last >= (crossing["fill"] as Rect2i).position.x:
				known = true
		if known:
			continue
		var rim := mini(int(floors.get(first - 1, 0)), int(floors.get(last + 1, 0)))
		var span := Rect2i(first, rim, last - first + 1, 8)
		var key := "gate %s" % str(Vector2i(first - 1, rim))
		var tiles: Array[Vector2i] = []
		for x in range(span.position.x, span.end.x):
			tiles.append(Vector2i(x, rim - 1))
		tolls[key] = tiles
		crossings.append({"kind": "piranhas", "key": key, "span": Rect2(Vector2(span.position) * float(ArenaGen.TILE), Vector2(span.size.x, 3) * float(ArenaGen.TILE)), "post": null, "fill": span})


## Steep faces and pits: where the ground itself stops a wizard on foot, and a spell is what gets it over.
func _faces_and_pits(tree: SceneTree, floors: Dictionary, plain: WorldNav) -> void:
	var cols: Array = floors.keys()
	cols.sort()
	var c := 0
	while c < cols.size() - 1:
		var col: int = cols[c]
		if int(floors[col]) - int(floors[col + 1]) >= SHEER:
			_face(col, floors, int(floors[col]) - int(floors[col + 1]))
		elif int(floors[col + 1]) > int(floors[col]):
			c = _pit(tree, cols, c, floors)
		c += 1


## A sheer face one cannot jump: a wall with the high ground on one side. The way up is a lift.
func _face(col: int, floors: Dictionary, rise: int) -> void:
	var foot := Vector2i(col, int(floors[col]) - 1)
	var top := Vector2i(col + 1, int(floors[col + 1]) - 1)
	var key := "gate %s" % str(Vector2i(col, int(floors[col])))
	links.append({"key": key, "left": foot, "right": foot, "top_left": top, "top_right": top})
	tolls[key] = [top]
	crossings.append({"kind": "wall", "key": key, "span": Rect2(Vector2(col + 1, int(floors[col + 1])) * float(ArenaGen.TILE), Vector2(1, rise) * float(ArenaGen.TILE)), "post": null})


## A pit: a run of columns lower than the ground before it, that the ground comes back up out of, deeper than a step. A wizard crosses it by a way over, or the water in it.
func _pit(tree: SceneTree, cols: Array, at: int, floors: Dictionary) -> int:
	var left: int = cols[at]
	var rim := int(floors[left])
	var end := at + 1
	var deepest := rim
	while end < cols.size() and int(floors[cols[end]]) > rim:
		deepest = maxi(deepest, int(floors[cols[end]]))
		end += 1
	if end >= cols.size() or deepest - rim < PIT_DEPTH:
		return maxi(end - 1, at)
	var right: int = cols[end]
	var span := Rect2i(left + 1, mini(rim, int(floors[right])), right - left - 1, 8)
	var wet := false
	var fish := false
	for node: Node in tree.get_nodes_in_group("ponds"):
		if node is Pond and not node.lava:
			var pond_first := floori(node.position.x / float(ArenaGen.TILE))
			if pond_first >= left and pond_first <= right:
				wet = true
	for node: Node in tree.get_nodes_in_group("shoals"):
		if node is Piranhas and node.alive() and floori(node.water.position.x / float(ArenaGen.TILE)) in range(left, right + 1):
			fish = true
	var kind := "piranhas" if fish else ("flood" if wet else "chasm")
	var key := "gate %s" % str(Vector2i(left, rim))
	var tiles: Array[Vector2i] = []
	for x in range(span.position.x, span.end.x):
		tiles.append(Vector2i(x, span.position.y - 1))
	tolls[key] = tiles
	crossings.append({"kind": kind, "key": key, "span": Rect2(Vector2(span.position) * float(ArenaGen.TILE), Vector2(span.size.x, deepest - span.position.y + 1) * float(ArenaGen.TILE)), "post": null, "fill": span})
	return end - 1


## Gas and walls are crossings as well as gates: the toll tiles are the ones a wizard stands on to cross them.
func _finish(floors: Dictionary) -> void:
	for gate in gates:
		var key := "gate %s" % str(gate["outside"])
		if gate["kind"] == "gas":
			var tiles: Array[Vector2i] = []
			for col in range(int(gate["first"]), int(gate["last"]) + 1):
				tiles.append(Vector2i(col, int(floors.get(col, 0)) - 1))
			tolls[key] = tiles
			var first := int(gate["first"])
			crossings.append({"kind": "gas", "key": key, "span": Rect2(Vector2(first, int(floors.get(first, 0)) - 1) * float(ArenaGen.TILE), Vector2(int(gate["last"]) - first + 1, 1) * float(ArenaGen.TILE)), "post": null})
		elif gate["kind"] == "wall":
			var columns: Array = gate["columns"]
			var tiles: Array[Vector2i] = []
			for column: Dictionary in columns:
				tiles.append(Vector2i(column["x"], int(column["top"]) - 1))
			tolls[key] = tiles
			links.append({"key": key, "left": Vector2i(int(columns[0]["x"]) - 1, int(columns[0]["bottom"]) - 1), "right": Vector2i(int(columns[-1]["x"]) + 1, int(columns[-1]["bottom"]) - 1), "top_left": tiles[0], "top_right": tiles[-1]})
			crossings.append({"kind": "wall", "key": key, "span": Rect2(Vector2(int(columns[0]["x"]), int(columns[0]["top"])) * float(ArenaGen.TILE), Vector2(columns.size(), int(columns[0]["bottom"]) - int(columns[0]["top"])) * float(ArenaGen.TILE)), "post": null, "solid": columns})


## The wizards' map of the ways: the room with its pits bridged and its walls solid, so that a path over each is open to whoever holds a spell for it.
func build_nav(nav: WorldNav, start: Vector2i) -> void:
	var cells := grid.duplicate()
	for crossing in crossings:
		if crossing.has("fill"):
			var rect: Rect2i = crossing["fill"]
			cells.fill_rect(Rect2i(rect.position - origin, rect.size), ArenaGen.GROUND)
		if crossing.has("solid"):
			for column: Dictionary in crossing["solid"]:
				for row in range(int(column["top"]), int(column["bottom"])):
					cells.put(Vector2i(column["x"], row) - origin, ArenaGen.GROUND)
	nav.origin = origin
	var local_tolls := {}
	for key: String in tolls:
		local_tolls[key] = tolls[key].map(func(tile: Vector2i) -> Vector2i: return tile - origin)
	var local_links := links.map(func(link: Dictionary) -> Dictionary:
		var out := link.duplicate()
		for side in ["left", "right", "top_left", "top_right"]:
			out[side] = link[side] - origin
		return out)
	nav.build(cells, grid.size.y, barred, start - origin, local_tolls, local_links)

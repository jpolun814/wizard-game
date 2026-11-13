class_name BrainExplore
extends RefCounted

## Where an AI wizard looks when it does not know where the pages are: the squares of the world it has been to, the places it picks to go and see, the portals it can reach, and the ground it will plan through. In a room where the ground is all in view it has no need of it.

var explored := {}              # the squares of the world it has been to ((x / 16, y / 12) -> true)
var explore_dir := 0.0
var sight_timer := 0.0

var brain: WizardBrain
var wizard: Wizard


func _init(owner: WizardBrain, body: Wizard) -> void:
	brain = owner
	wizard = body


## Goes to look at a part of the world it has not been to: along the way it was going, or the other way when that is shut off.
func choose_explore(start: Vector2i) -> bool:
	if not sight_is_limited():
		return false
	if explore_dir == 0.0:
		explore_dir = -1.0 if brain.rng.randf() < 0.5 else 1.0
	for round in 2:
		# It looks at what lies near first (to either side, and up or down a floor), and likes to go on the way it was going.
		var best_path: Array[Vector2i] = []
		var best_cost := INF
		var best_dir := explore_dir
		for dy in [0, -WizardBrain.EXPLORE_FLOOR, WizardBrain.EXPLORE_FLOOR, -2 * WizardBrain.EXPLORE_FLOOR, 2 * WizardBrain.EXPLORE_FLOOR]:
			for dir: float in [explore_dir, -explore_dir]:
				for k in range(0 if dy != 0 else 1, 10):
					var aim := Vector2i(start.x + int(dir) * k * WizardBrain.EXPLORE_STEP, start.y + dy)
					var tile: Vector2i = wizard.nav.nearest(aim, true)
					if tile == WorldNav.NONE or (absi(tile.x - start.x) < WizardBrain.EXPLORE_STEP / 2 and absi(tile.y - start.y) < WizardBrain.EXPLORE_FLOOR / 2):
						continue
					if explored.has(square_of(Vector2(tile.x * WizardRoute.TILE, tile.y * WizardRoute.TILE))):
						continue
					if Wreck.covers(wizard.get_tree(), Vector2((tile.x + 0.5) * WizardRoute.TILE, (tile.y + 1) * WizardRoute.TILE)):
						continue  # (a wreck is taken in at a glance: its page and its air are sought for themselves, its hold is not searched square by square)
					var path: Array[Vector2i] = brain.travel.raw_path(start, tile)
					if path.is_empty() or not through_known(path, start, tile):
						continue
					var cost := float(path.size()) + brain.rng.randf() * 12.0 - (14.0 if dir == explore_dir else 0.0)
					if cost < best_cost:
						best_cost = cost
						best_path = path
						best_dir = dir
					break  # (the nearest unexplored square this way on this floor is the one to weigh)
		if not best_path.is_empty():
			explore_dir = best_dir
			brain.goal = "explore"
			brain.route.set_path(best_path)
			return true
		explored.clear()  # it has been everywhere it can get to: it looks again
	return false


func note_sights(delta: float) -> void:
	sight_timer -= delta
	if sight_timer > 0.0:
		return
	sight_timer = 0.4
	var at := wizard.center()
	for pickup: PagePickup in wizard.get_tree().get_nodes_in_group("pages"):
		if wizard.eyes.rect().grow(WizardBrain.PAGE_GLOW).has_point(pickup.global_position) and not SpellTargets.sight_blocked(wizard.get_tree(), at, pickup.global_position):
			brain.seen_pages[pickup.get_instance_id()] = true
	explored[square_of(wizard.global_position)] = true
	# Everything on its screen has been seen: the squares whose middles lie on it are explored too.
	var view := wizard.eyes.rect()
	var square := Vector2(16.0 * WizardRoute.TILE, 12.0 * WizardRoute.TILE)
	var first := square_of(view.position)
	var last := square_of(view.end)
	for sx in range(first.x, last.x + 1):
		for sy in range(first.y, last.y + 1):
			if view.has_point((Vector2(sx, sy) + Vector2(0.5, 0.5)) * square):
				explored[Vector2i(sx, sy)] = true
	if brain.seen_pages.size() > 400:
		brain.seen_pages.clear()


## In a match a wizard knows of a page only when it has seen it, as a person does, and goes looking when it knows of none.
func sight_is_limited() -> bool:
	return wizard.get_tree().get_first_node_in_group(&"world") != null


func square_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / (16.0 * WizardRoute.TILE)), floori(point.y / (12.0 * WizardRoute.TILE)))


## Whether a way to an unexplored square goes only over ground it has seen, and the square itself or ground next to where it stands: a person
## exploring knows the ground they have seen, not the ground beyond, so they go to the edge of what they know and look. (The map of the ways is
## the whole world's; this keeps the brain to the part a person would know.)
func through_known(path: Array[Vector2i], start: Vector2i, target: Vector2i) -> bool:
	var here := square_of(Vector2(start.x * WizardRoute.TILE, start.y * WizardRoute.TILE))
	var there := square_of(Vector2(target.x * WizardRoute.TILE, target.y * WizardRoute.TILE))
	for tile in path:
		var sq := square_of(Vector2(tile.x * WizardRoute.TILE, tile.y * WizardRoute.TILE))
		if explored.has(sq) or (absi(sq.x - there.x) <= 1 and absi(sq.y - there.y) <= 1) or (absi(sq.x - here.x) <= 1 and absi(sq.y - here.y) <= 1):
			continue
		return false
	return true


## As far toward a place as the ground it has seen takes it: of the places it knows that lie between here and there (along the line to it, and
## along its own floor), the one nearest the place that it can walk to over ground it has seen. Empty when none is nearer than where it stands.
func toward_known(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var best := brain.travel.no_path()
	var best_gap := Vector2(to - from).length() - 3.0  # it must come nearer, or there is no point
	var aims: Array[Vector2i] = []
	for k in range(8, 0, -1):
		aims.append(from + Vector2i((Vector2(to - from) * k / 8.0).round()))  # along the line, the far end first
	var side := signi(to.x - from.x)
	for k in range(1, 6):
		aims.append(Vector2i(from.x + side * k * WizardBrain.EXPLORE_STEP / 2, from.y))  # and along its own floor, the way the place lies
	for aim in aims:
		var tile: Vector2i = wizard.nav.nearest(aim, true)
		if tile == WorldNav.NONE or tile == from or not explored.has(square_of(Vector2(tile.x * WizardRoute.TILE, tile.y * WizardRoute.TILE))):
			continue
		var gap := Vector2(to - tile).length()
		if gap >= best_gap:
			continue
		var path := brain.travel.raw_path(from, tile)
		if path.is_empty() or not through_known(path, from, tile):
			continue
		best = path
		best_gap = gap
	return best


## The open portal nearest by the way it must walk, as {"portal", "path"}, or nothing when fewer than two are open (one leads nowhere).
func nearest_portal(start: Vector2i) -> Dictionary:
	var open: Array = wizard.get_tree().get_nodes_in_group("field_portals").filter(func(p: FieldPortal) -> bool: return not p.is_closing())
	var best := {}
	if open.size() < 2:
		return best
	for portal: FieldPortal in open:
		if portal.remaining() < WizardBrain.PORTAL_LEFT or portal.lift > PortalField.JUMPABLE or brain.skip.has(portal.get_instance_id()):  # one hung higher than a jump reaches is not for it
			continue
		var path: Array[Vector2i] = brain.travel.find_path(start, wizard.nav.nearest(brain.tile_of(portal.global_position + Vector2(0.0, Portal.RY + portal.lift))))
		if not path.is_empty() and (best.is_empty() or path.size() < best["path"].size()):
			best = {"portal": portal, "path": path}
	return best

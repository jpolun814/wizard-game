class_name Sensing
extends RefCounted

## What a wizard can take in at a glance, as a list of numbers: the same for a person's wizard (written into the play recording, to learn from) and for a
## wizard a policy plays (read by the agent in training and in a match), so that what is learned from people is what the learner sees.
##
## Layout (all about -1..1): the wizard itself (7), a box of ground tiles about the feet with what is solid and what is lethal (GRID_W x GRID_ROWS, two each),
## the nearest pages (3), the nearest rivals (2), and the nearest creatures and things that hurt (4).

const GRID_W := 11     # tiles across, the feet in the middle one
const GRID_UP := 5     # tiles above the feet that are looked at
const GRID_DOWN := 3
const GRID_ROWS := GRID_UP + GRID_DOWN + 1
const LETHAL_UP := 1   # the lethal tiles are looked for only from this many rows above the feet down (lava lies on or under the ground)
const PAGES := 3
const RIVALS := 2
const THREATS := 4
const SEE := 900.0
const SEE_THREAT := 500.0
const SIZE := 7 + GRID_W * GRID_ROWS * 2 + PAGES * 3 + RIVALS * 5 + THREATS * 3

static var _sensors := {}  # wizard instance id -> a brain used only to ask what is lethal where, for a wizard that has no brain of its own


## The numbers for one wizard.
static func observe(wizard: Wizard) -> PackedFloat32Array:
	var obs := PackedFloat32Array()
	if wizard == null or not is_instance_valid(wizard):
		obs.resize(SIZE)
		return obs
	obs.append(wizard.velocity.x / 300.0)
	obs.append(clampf(wizard.velocity.y / 600.0, -2.0, 2.0))
	obs.append(1.0 if wizard.is_on_floor() else 0.0)
	obs.append(wizard.stamina / 200.0)
	obs.append(wizard.max_stamina / 200.0)
	obs.append(wizard.facing)
	obs.append(1.0 if wizard.air_jump_ready else 0.0)
	var codes := grid(wizard)
	for code in codes:
		obs.append(float(code & 3) * 0.5)  # solid: 0, a platform 0.5, solid ground 1
		obs.append(1.0 if code & 4 != 0 else 0.0)
	_nearest_pages(wizard, obs)
	_nearest_rivals(wizard, obs)
	_nearest_threats(wizard, obs)
	return obs


## The ground about the feet, a tile to a number: 0 open, 1 a platform (a wizard can pass up through it), 2 solid, plus 4 where it is lethal.
static func grid(wizard: Wizard) -> PackedInt32Array:
	var out := PackedInt32Array()
	var space := wizard.get_world_2d().direct_space_state
	var here := Vector2i(floori(wizard.global_position.x / WizardRoute.TILE), floori((wizard.global_position.y - 1.0) / WizardRoute.TILE))
	var sensor := _sensor_for(wizard)
	for dy in range(-GRID_UP, GRID_DOWN + 1):
		for dx in range(-(GRID_W / 2), GRID_W / 2 + 1):
			var point := Vector2((here.x + dx + 0.5) * WizardRoute.TILE, (here.y + dy + 0.5) * WizardRoute.TILE)
			var query := PhysicsPointQueryParameters2D.new()
			query.position = point
			query.collision_mask = 1 | 16
			var code := 0
			for hit in space.intersect_point(query, 2):
				var layer: int = hit["collider"].collision_layer if hit["collider"] is CollisionObject2D else 1
				code = maxi(code, 1 if (layer & 16 != 0 and layer & 1 == 0) else 2)
			if dy >= -LETHAL_UP and sensor._lethal_at(point):
				code |= 4
			out.append(code)
	return out


static func _sensor_for(wizard: Wizard) -> WizardBrain:
	if wizard.brain != null:
		return wizard.brain
	var id := wizard.get_instance_id()
	if not _sensors.has(id) or _sensors[id].wizard != wizard:
		_sensors[id] = WizardBrain.new(wizard)
	return _sensors[id]


static func _nearest_pages(wizard: Wizard, obs: PackedFloat32Array) -> void:
	var found: Array = []
	for pickup: Node2D in wizard.get_tree().get_nodes_in_group("pages"):
		var off := pickup.global_position - wizard.center()
		if off.length() < SEE:
			found.append(off)
	found.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.length() < b.length())
	for i in PAGES:
		if i < found.size():
			obs.append_array([found[i].x / SEE, found[i].y / SEE, 1.0])
		else:
			obs.append_array([0.0, 0.0, 0.0])


static func _nearest_rivals(wizard: Wizard, obs: PackedFloat32Array) -> void:
	var found: Array = []
	for other: Wizard in SpellTargets.wizards(wizard.get_tree()):
		if other != wizard and not other.dead and other.visible:
			var off := other.center() - wizard.center()
			if off.length() < SEE:
				found.append([off, other])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0].length() < b[0].length())
	for i in RIVALS:
		if i < found.size():
			var other: Wizard = found[i][1]
			obs.append_array([found[i][0].x / SEE, found[i][0].y / SEE, other.stamina / 200.0, 1.0 if other.wild else 0.0, 1.0])
		else:
			obs.append_array([0.0, 0.0, 0.0, 0.0, 0.0])


## What is near that can hurt: creatures (1), and the spells and fires in the world (0.5).
static func _nearest_threats(wizard: Wizard, obs: PackedFloat32Array) -> void:
	var found: Array = []
	for group in ["mobs", "danger"]:
		for node: Node2D in wizard.get_tree().get_nodes_in_group(group):
			if node == wizard or not is_instance_valid(node):
				continue
			var off := node.global_position - wizard.center()
			if off.length() < SEE_THREAT:
				found.append([off, 1.0 if group == "mobs" else 0.5])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0].length() < b[0].length())
	for i in THREATS:
		if i < found.size():
			obs.append_array([found[i][0].x / SEE_THREAT, found[i][0].y / SEE_THREAT, found[i][1]])
		else:
			obs.append_array([0.0, 0.0, 0.0])

class_name SpellTargets
extends RefCounted

## Who a spell can hurt. A spell has no side: once it is cast it hurts whoever it touches, the caster and its own
## allies included. The few shots that pass their caster by are handled by the shot itself (see Projectile).

static var _fires: Array = []
static var _fires_frame := -1
static var _fires_count := -1
static var _fires_tree: SceneTree


## True when a spell can hurt the body: a wizard, or an enemy, still standing.
static func affects(body) -> bool:  # (no type: a body freed a moment ago must reach the check below, and a typed argument refuses it before that, as an error every frame)
	if not is_instance_valid(body):
		return false
	if body.is_in_group("wizards"):
		return not body.dead
	return body.is_in_group("mobs") and not body.is_dead()


## The wizard whose blow this is: the wizard themselves, or the one whose spell (it knows its caster) did it. Nothing for an enemy's or the world's.
static func striker_of(by: Node) -> Wizard:
	if not is_instance_valid(by):
		return null  # (a spell whose caster has left the world)
	if by is Wizard:
		return by
	var owner: Variant = by.get("caster")
	if is_instance_valid(owner) and owner is Wizard:  # (a caster gone from the world is asked after first: "is" on a freed one is an error)
		return owner
	return null


## What a blow counts as having come from, for the safety that follows it (see Wizard.take_damage): the thing that struck, when it says it is one whole
## cast by having a `hit_source()` (a spell that is a single node, or one that shares a source among the many nodes of one cast); otherwise nothing, and
## the blow works under the one safety every blow without a source shares. A spell is moved over by giving it that method.
static func hit_source_of(by: Node) -> Object:
	if is_instance_valid(by) and by.has_method("hit_source"):
		return by.hit_source()
	return null


## Hurts the body. Enemies take school damage (weak, resisted); a wizard, whoever plays it, takes it plain. A shot's hurt
## (shot true) is stopped by a wizard's Barrier, as every shot is.
static func hurt(body: Node, amount: int, school: String, shot := false, lava := false, by: Node = null) -> void:
	if not affects(body):
		return
	var striker := striker_of(by)
	if striker != null and striker.adrenaline_time > 0.0:
		amount = roundi(amount * Wizard.ADRENALINE_DEALT)  # blood racing in the one who struck
	if lava and body.has_method("lava_proof") and body.lava_proof():
		return  # black glass: the lava runs off it
	var kind := Damage.kind_of(school, by)
	amount = Damage.laws(body, amount, kind, by)  # what a blow of this kind does besides harm: any body
	if body.is_in_group("wizards"):
		if Damage.shatters(kind) and body.is_frozen():
			amount = roundi(amount * Damage.SHATTER)  # a frozen wizard is shattered out of the ice, as a frozen enemy is
			body.thaw()
			Shatter.spawn(body.get_parent(), body.center(), Color("#cdeeff"))
			Sfx.cue("ice_block", "shatter", body.center())
		MatchStats.strike(by)  # (whose blow it is, for the count of what each wizard has done)
		body.take_damage(amount, true, shot, hit_source_of(by))
	else:
		MatchStats.strike(by)
		body.take_damage(amount, school, shot)
	MatchStats.strike(null)


## Every body a spell can reach: every enemy, and every wizard while alive.
static func all(tree: SceneTree) -> Array:
	var out := []
	out.append_array(tree.get_nodes_in_group("mobs"))
	out.append_array(wizards(tree))
	return out


## The one of these bodies whose middle is nearest a point, if it is nearer than `within`; null when none is.
static func nearest_to(bodies: Array, point: Vector2, within := INF) -> Node2D:
	var best: Node2D = null
	var best_distance := within
	for body: Node2D in bodies:
		var distance := center_of(body).distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best


## The wizards still standing: the player, and every other wizard that is not beaten.
static func wizards(tree: SceneTree) -> Array:
	var out := []
	for wizard: Wizard in tree.get_nodes_in_group("wizards"):
		if not wizard.dead:
			out.append(wizard)
	return out


## The surface a point sits on. A point under the ground is moved up to the ground above it, so a drawn spell that
## starts underground still lands on top of the earth.
## How far a pool's ground may step up or down between two neighboring points, in pixels.
const RUN_STEP_UP := 26.0
const RUN_STEP_DOWN := 34.0


static func surface_over(world: World2D, point: Vector2) -> Vector2:
	# A point in the open is over the first ground below it, not a ceiling above it.
	var inside := PhysicsPointQueryParameters2D.new()
	inside.position = point
	inside.collision_mask = 1
	if world.direct_space_state.intersect_point(inside, 1).is_empty():
		for lift in [6.0, 40.0]:  # the ground just under the point, and failing that a rise a little above it (a slope that climbs)
			var down := PhysicsRayQueryParameters2D.create(point + Vector2(0.0, -lift), point + Vector2(0.0, 800.0))
			down.collision_mask = 1
			var below := world.direct_space_state.intersect_ray(down)
			if not below.is_empty():
				return below["position"]
		# No ground below: the point is inside a hill (a world's rock is outlines, which have no inside for the query above to find), whose surface is over it.
		for reach in [64.0, 800.0]:
			var up := PhysicsRayQueryParameters2D.create(point + Vector2(0.0, -reach), point)
			up.collision_mask = 1
			var above := world.direct_space_state.intersect_ray(up)
			if not above.is_empty():
				return above["position"]
		return Vector2(point.x, ArenaGen.GROUND_Y)
	# A point inside the ground is over the nearest surface above it (the ground it is in), and only failing that the first one far above (never a platform overhead
	# when the ground right here is near).
	for reach in [64.0, 800.0]:
		var query := PhysicsRayQueryParameters2D.create(Vector2(point.x, point.y - reach), point)
		query.collision_mask = 1
		var hit := world.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			return hit["position"]
	return solid_below(world, point + Vector2(0, -6))


## The ground a pool lies on (oil, mud), read across its width from its middle outward, the way a person would walk it: each next point is found a step up or down from the
## last one, so the pool follows a slope or a small step and stops at a wall or at the edge of a drop (a platform's end, a cliff, a pit) and does not hang in the air past it,
## or jump down to a floor below. Gives the height of the ground at `samples` points evenly across `width` (relative to `origin`), and NAN for the points it did not reach.
static func ground_run(world: World2D, origin: Vector2, width: float, samples: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(samples)
	out.fill(NAN)
	var middle := samples / 2
	out[middle] = 0.0
	var here := PhysicsRayQueryParameters2D.create(origin + Vector2(0.0, -RUN_STEP_UP), origin + Vector2(0.0, RUN_STEP_DOWN))
	here.collision_mask = 1
	if world.direct_space_state.intersect_ray(here).is_empty():
		out.fill(0.0)  # no ground under the middle of it at all (it was cast over open air): a level pool, as wide as it was drawn
		return out
	for direction in [-1, 1]:
		var last := origin.y
		var i: int = middle + direction
		while i >= 0 and i < samples:
			var x := origin.x + lerpf(-width * 0.5, width * 0.5, float(i) / float(samples - 1))
			var query := PhysicsRayQueryParameters2D.create(Vector2(x, last - RUN_STEP_UP), Vector2(x, last + RUN_STEP_DOWN))
			query.collision_mask = 1
			var hit := world.direct_space_state.intersect_ray(query)
			if hit.is_empty():
				break  # a wall (the ray starts in rock) or a drop (nothing under it): the pool ends here
			last = hit["position"].y
			out[i] = last - origin.y
			i += direction
	return out


## The middle of a body, for distance checks. Enemies and the player both have center(); anything else uses its
## position.
static func center_of(body: Node2D) -> Vector2:
	return body.center() if body.has_method("center") else body.global_position


## Hurts every affected body within a radius of a point, and returns how many it hit.
static func hurt_within(tree: SceneTree, point: Vector2, radius: float, amount: int, school: String, shot := false, lava := false, by: Node = null) -> int:
	var hit := 0
	for body in all(tree):
		if center_of(body).distance_to(point) <= radius:
			hurt(body, amount, school, shot, lava, by)
			hit += 1
	return hit


## The surface directly below a point (the floor or a platform), or the point itself pushed down a little if
## there is nothing below.
static func ground_below(world: World2D, point: Vector2, reach := 800.0, through_canopy := false) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(point, point + Vector2(0, reach))
	query.collision_mask = 1 | 16
	if through_canopy:  # (a bolt from the sky passes the leaves of a great tree)
		var leaves: Array[RID] = []
		for body: CollisionObject2D in (Engine.get_main_loop() as SceneTree).get_nodes_in_group("canopy"):
			leaves.append(body.get_rid())
		query.exclude = leaves
	var hit := world.direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else Vector2(point.x, ArenaGen.GROUND_Y)


## The solid ground surface below a point, ignoring platforms.
static func solid_below(world: World2D, point: Vector2, reach := 800.0) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(point, point + Vector2(0, reach))
	query.collision_mask = 1
	var hit := world.direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else Vector2(point.x, ArenaGen.GROUND_Y)


## Every fire burning, as {at: where it is, heat: how fiercely it melts, size: how far it reaches past that point,
## shot: true for a fireball or ball of lava in flight}. Burning ground and a firewall are steady heat; a fireball or a
## ball of lava is three times as hot; each puff of breath is a small flame.
static func fire_points(tree: SceneTree) -> Array:
	# Everything that cares about fire asks this many times a frame, and a great pool of lava is hundreds of points, so the answer is kept for
	# the frame (and thrown away when a fire is lit or put out in it).
	var frame := Engine.get_physics_frames()
	var count := tree.get_nodes_in_group("fires").size()
	if frame == _fires_frame and count == _fires_count and tree == _fires_tree:
		return _fires
	var fires := []
	for node in tree.get_nodes_in_group("fires"):
		if node.has_method("fire_profile"):
			fires.append_array(node.fire_profile())
	_fires = fires
	_fires_frame = frame
	_fires_count = count
	_fires_tree = tree
	return fires


## True when any fire, a fireball in flight included, touches a box in the world. Plants burn from it.
static func fire_touching(tree: SceneTree, box: Rect2) -> bool:
	for fire in fire_points(tree):
		var at: Vector2 = fire["at"]
		if at.distance_to(at.clamp(box.position, box.end)) < maxf(fire["size"], 0.0) + 8.0:
			return true
	return false


## True when smoke or darkness stops someone at one point from seeing another. A bank of smoke blocks any line of sight
## through it. Inside an eclipse you only see what is close, unless a flare lights the spot.
static func sight_blocked(tree: SceneTree, from: Vector2, to: Vector2) -> bool:
	for smoke in tree.get_nodes_in_group("sight_blockers"):
		if smoke.blocks(from, to):
			return true
	for eclipse in tree.get_nodes_in_group("eclipses"):
		if eclipse.covers(from) and from.distance_to(to) > Eclipse.SIGHT and not _lit_by_flare(tree, from):
			return true
	return false


## True when a light shines on a place: a flare close enough to light it, or a fire burning near it.
static func lit_near(tree: SceneTree, point: Vector2, reach: float) -> bool:
	for flare in tree.get_nodes_in_group("flares"):
		if flare.global_position.distance_to(point) < Flare.LIGHT_RADIUS * 0.6 + reach:
			return true
	for light in tree.get_nodes_in_group("lights"):  # a Glowcap or a Moonbeam: dimmer, so they show less
		if light.global_position.distance_to(point) < light.light_radius * 0.6 + reach:
			return true
	for fire in fire_points(tree):
		if fire["at"].distance_to(point) < 160.0 + reach + maxf(fire["size"], 0.0):
			return true
	return false


static func _lit_by_flare(tree: SceneTree, point: Vector2) -> bool:
	for flare in tree.get_nodes_in_group("flares"):
		if flare.global_position.distance_to(point) < Flare.LIGHT_RADIUS:
			return true
	for light in tree.get_nodes_in_group("lights"):
		if light.global_position.distance_to(point) < light.light_radius:
			return true
	return false


## The heat of the hottest steady fire (not a shot in flight) within reach of a box in the world, or 0 if none is.
static func fire_heat_near(tree: SceneTree, box: Rect2, reach: float) -> float:
	var heat := 0.0
	for fire in fire_points(tree):
		if fire["shot"]:
			continue
		var at: Vector2 = fire["at"]
		var nearest := at.clamp(box.position, box.end)
		if at.distance_to(nearest) < reach + fire["size"]:
			heat = maxf(heat, fire["heat"])
	return heat


## How much a shot that touched something hurts it: an enemy's bolt or one of the spell projectiles. Anything else, 0.
static func shot_damage(area: Area2D) -> int:
	if area is EnemyBolt:
		return area.damage
	if area is Projectile or area is LavaBall:
		return area.damage()
	return 0

class_name SpellTargets
extends RefCounted

## Who a spell can hurt. A spell has no side: once it is cast it hurts whoever it touches, the caster and its own
## allies included. The few shots that pass their caster by are handled by the shot itself (see Projectile).


## True when a spell can hurt the body: a wizard, or an enemy, still standing.
static func affects(body: Node) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if body.is_in_group("wizards"):
		return not body.dead
	return body.is_in_group("mobs") and not body.is_dead()


## Hurts the body. Enemies take school damage (weak, resisted); a wizard, whoever plays it, takes it plain. A shot's hurt
## (shot true) is stopped by a wizard's Barrier, as every shot is.
static func hurt(body: Node, amount: int, school: String, shot := false, lava := false) -> void:
	if not affects(body):
		return
	if lava and body.has_method("lava_proof") and body.lava_proof():
		return  # black glass: the lava runs off it
	if body.is_in_group("wizards"):
		if school in ["Air", "Earth"] and body.is_frozen():
			amount = roundi(amount * 1.5)  # a frozen wizard is shattered out of the ice, as a frozen enemy is
			body.thaw()
			Shatter.spawn(body.get_parent(), body.center(), Color("#cdeeff"))
			Sfx.play("ice_shatter", body.center())
		body.take_damage(amount, true, shot)
	else:
		body.take_damage(amount, school, shot)


## Every body a spell can reach: every enemy, and every wizard while alive.
static func all(tree: SceneTree) -> Array:
	var out := []
	out.append_array(tree.get_nodes_in_group("mobs"))
	out.append_array(wizards(tree))
	return out


## The wizards still standing: the player, and every other wizard that is not beaten.
static func wizards(tree: SceneTree) -> Array:
	var out := []
	for wizard: Wizard in tree.get_nodes_in_group("wizards"):
		if not wizard.dead:
			out.append(wizard)
	return out


## The surface a point sits on. A point under the ground is moved up to the ground above it, so a drawn spell that
## starts underground still lands on top of the earth.
static func surface_over(world: World2D, point: Vector2) -> Vector2:
	# A point in the open is over the first ground below it, not a ceiling above it.
	var inside := PhysicsPointQueryParameters2D.new()
	inside.position = point
	inside.collision_mask = 1
	if world.direct_space_state.intersect_point(inside, 1).is_empty():
		return solid_below(world, point + Vector2(0, -40))
	var query := PhysicsRayQueryParameters2D.create(Vector2(point.x, point.y - 800.0), point)
	query.collision_mask = 1
	var hit := world.direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit["position"]
	return solid_below(world, point + Vector2(0, -40))


## The middle of a body, for distance checks. Enemies and the player both have center(); anything else uses its
## position.
static func center_of(body: Node2D) -> Vector2:
	return body.center() if body.has_method("center") else body.global_position


## Hurts every affected body within a radius of a point, and returns how many it hit.
static func hurt_within(tree: SceneTree, point: Vector2, radius: float, amount: int, school: String, shot := false, lava := false) -> int:
	var hit := 0
	for body in all(tree):
		if center_of(body).distance_to(point) <= radius:
			hurt(body, amount, school, shot, lava)
			hit += 1
	return hit


## The surface directly below a point (the floor or a platform), or the point itself pushed down a little if
## there is nothing below.
static func ground_below(world: World2D, point: Vector2, reach := 800.0) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(point, point + Vector2(0, reach))
	query.collision_mask = 1 | 16
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
	var fires := []
	for node in tree.get_nodes_in_group("fires"):
		if node is Hazard:
			fires.append({"at": node.global_position, "heat": 1.0, "size": node.width * 0.5, "shot": false})
		elif (node is Projectile and node.spell == "Ignite") or node is LavaBall:
			fires.append({"at": node.global_position, "heat": 3.0, "size": 0.0, "shot": true})
		elif node is Firewall:
			for point in node.flame_points():
				fires.append({"at": point, "heat": 1.0, "size": 12.0, "shot": false})
		elif node is FireBreath:
			for point in node.flame_points():
				fires.append({"at": point, "heat": 1.0, "size": -10.0, "shot": false})
		elif node is Pond:
			fires.append({"at": node.global_position + Vector2(node.width * 0.5, 0), "heat": 1.0, "size": node.width * 0.5, "shot": false})
		elif node is Bonfire:
			fires.append({"at": node.global_position + Vector2(0, -20), "heat": 1.0, "size": 24.0, "shot": false})
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

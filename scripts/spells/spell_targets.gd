class_name SpellTargets
extends RefCounted

## Who a spell can hurt. A spell has no side: once it is cast it hurts whoever it touches, the caster and its own
## allies included. The few shots that pass their caster by are handled by the shot itself (see Projectile).


## True when a spell can hurt the body: the player, or an enemy still standing.
static func affects(body: Node) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if body.is_in_group("player"):
		return true
	return body.is_in_group("mobs") and not body.is_dead()


## Hurts the body. Enemies take school damage (weak, resisted); the player takes it plain. A shot's hurt (shot true)
## is stopped by the player's Barrier, as every shot is.
static func hurt(body: Node, amount: int, school: String, shot := false) -> void:
	if not affects(body):
		return
	if body.is_in_group("player"):
		if school in ["Force", "Earth"] and body.is_frozen():
			amount = roundi(amount * 1.5)  # a frozen player is shattered out of the ice, as a frozen enemy is
			body.thaw()
			Shatter.spawn(body.get_parent(), body.center(), Color("#cdeeff"))
			Sfx.play("ice_shatter", body.center())
		body.take_damage(amount, true, shot)
	else:
		body.take_damage(amount, school)


## Every body a spell can reach: every enemy, and the player while alive.
static func all(tree: SceneTree) -> Array:
	var out := []
	out.append_array(tree.get_nodes_in_group("mobs"))
	var player := tree.get_first_node_in_group("player")
	if player and not player.dead:
		out.append(player)
	return out


## The surface a point sits on. A point under the ground is moved up to the ground above it, so a drawn spell that
## starts underground still lands on top of the earth.
static func surface_over(world: World2D, point: Vector2) -> Vector2:
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
static func hurt_within(tree: SceneTree, point: Vector2, radius: float, amount: int, school: String, shot := false) -> int:
	var hit := 0
	for body in all(tree):
		if center_of(body).distance_to(point) <= radius:
			hurt(body, amount, school, shot)
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
	return fires


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

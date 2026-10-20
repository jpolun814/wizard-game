class_name SpellTargets
extends RefCounted

## Who a spell can hurt. Every spell belongs to a team: "player" for yours and "enemy" for the dark wizard's.
## Your spells hurt enemies, and they hurt you too if you are caught in them. The dark wizard's spells hurt only
## you, so it can't blow itself up.


## True when a spell of this team affects the body (an enemy or the player).
static func affects(body: Node, team: String) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if body.is_in_group("player"):
		return true
	if body.is_in_group("mobs"):
		if body.is_dead():
			return false
		if team == "enemy":
			return body.kind == "dark_wizard"  # its own spells burn it too, but never its fellow enemies
		return true
	return false


## Hurts the body if the spell's team affects it. Enemies take school damage (weak, resisted); the player takes
## it plain.
static func hurt(body: Node, amount: int, school: String, team: String) -> void:
	if not affects(body, team):
		return
	if body.is_in_group("player"):
		if school in ["Force", "Earth"] and body.is_frozen():
			amount = roundi(amount * 1.5)  # a frozen player is shattered out of the ice, as a frozen enemy is
			body.thaw()
			Shatter.spawn(body.get_parent(), body.center(), Color("#cdeeff"))
			Sfx.play("ice_shatter", body.center())
		body.take_damage(amount)
	else:
		body.take_damage(amount, school)


## Every body a spell of this team affects: enemies (for your spells) and the player.
static func all(tree: SceneTree, team: String) -> Array:
	var out := []
	if team == "player":
		out.append_array(tree.get_nodes_in_group("mobs"))
	else:
		for mob in tree.get_nodes_in_group("mobs"):
			if mob.kind == "dark_wizard":
				out.append(mob)
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
static func hurt_within(tree: SceneTree, point: Vector2, radius: float, amount: int, school: String, team: String) -> int:
	var hit := 0
	for body in all(tree, team):
		if center_of(body).distance_to(point) <= radius:
			hurt(body, amount, school, team)
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

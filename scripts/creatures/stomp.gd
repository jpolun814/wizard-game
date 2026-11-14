class_name Stomp
extends RefCounted

## A giant's stomp: its foot comes down in front of it, breaking any stone wall or boulder there, hurting every other enemy close by, and knocking the player back if
## they are in reach. Reached as `mob.stomp`. (Only a creature of the "smash" kind uses it.)

const WINDUP := 0.9  # a giant draws its leg back this long before it stomps
const REACH := 130.0  # how far in front of it a smash lands
const HEIGHT := -50.0  # and how high up: about where a giant's stomp lands
const WALL_DAMAGE := 200.0  # a smash breaks a stone wall or a boulder outright
const MOB_DAMAGE := 20  # and hurts any other enemy close to it
const STUCK := 3.0  # the first stomp sticks the player in the ground this long
const SPOTS := 8  # the ground the stomp lands on is marked at this many points, from the giant out to its reach

var mob: Mob


func _init(owner_mob: Mob) -> void:
	mob = owner_mob


## The ground the stomp lands on: points along the ground in front of the giant, out to its reach.
func spots() -> Array:
	var out := []
	for i in range(1, SPOTS + 1):
		var x := mob.global_position.x + mob.facing * REACH * float(i) / SPOTS
		out.append(SpellTargets.solid_below(mob.get_world_2d(), Vector2(x, mob.global_position.y - 60.0)))
	return out


## Shows where the stomp will land: dust rising off the ground at each spot, as the giant draws its leg back.
func telegraph() -> void:
	for spot in spots():
		Fx.smoke(mob.get_parent(), spot, Color(0.82, 0.74, 0.6, 0.9), 6, 26.0, 40.0)


## True when a stone wall or boulder stands within a smash's reach in front of the giant.
func wall_ahead() -> bool:
	var query := PhysicsRayQueryParameters2D.create(mob.global_position + Vector2(0, HEIGHT), mob.global_position + Vector2(REACH * mob.facing, HEIGHT))
	query.collision_mask = 1
	var hit := mob.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var blocker: Object = hit["collider"]
	return blocker.is_in_group("stone_walls") or blocker.is_in_group("rocks")


## The foot comes down.
func land() -> void:
	var tree := mob.get_tree()
	var facing := mob.facing
	var point := mob.global_position + Vector2(REACH * facing, HEIGHT)
	Sfx.play("stones", point, -2.0)
	Fx.debris(mob.get_parent(), point, Color("#a08060"), 10, 180.0)
	GameCamera.shake_near(tree, mob.global_position, 0.3, Mob.SHAKE_REACH)
	for wall in tree.get_nodes_in_group("walls"):
		wall.take_blow_near(point, WALL_DAMAGE)
	for rock in tree.get_nodes_in_group("rocks"):
		rock.take_blow_near(point, WALL_DAMAGE)
	for other in tree.get_nodes_in_group("mobs"):
		if other != mob and not other.is_dead() and other.center().distance_to(point) <= 50.0:
			other.take_damage(MOB_DAMAGE)
	# The impact shows on every spot the stomp landed on.
	for spot in spots():
		Fx.smoke(mob.get_parent(), spot, Color(0.5, 0.43, 0.34, 0.85), 5, 26.0, 40.0)
		Fx.debris(mob.get_parent(), spot, Color("#8a7058"), 6, 150.0)
	# The stomp covers the ground in front of the giant, from its feet up to the height of a standing player. The first stomp that catches the player sticks them
	# in the ground; a stomp that catches them while they are stuck throws them far away and frees them.
	var player := mob.player
	var rel: Vector2 = player.center() - mob.global_position if player else Vector2.ZERO
	if player and not player.dead and signf(rel.x) == facing and absf(rel.x) < REACH + 40.0 and absf(rel.y) < 120.0:
		player.take_damage(Mob.KINDS[mob.kind].damage)
		if player.root_time > 0.0:
			player.push(Vector2(facing * 900.0, -220.0))
		else:
			player.stick_in_ground(STUCK)
	Sfx.play("push", point, -6.0)

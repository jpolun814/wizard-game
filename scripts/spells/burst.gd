class_name Burst
extends SpellEffect

## Burst: blood bursts outward from the point drawn. Everything in reach is hurt and thrown away from the middle, except the caster,
## and shots in the air are turned back the way they came.

const RADIUS := 140.0
const DAMAGE := 40
const KNOCK := 520.0  # how hard a body is thrown, at the middle; less toward the edge
const LIFT := -220.0


func _begin(origin: Vector2, _aim_angle: float) -> void:
	_life = 0.45
	var tree := get_tree()
	for body in SpellTargets.all(tree):
		if body == caster:
			continue  # the one who bursts it stands in its middle, and it passes them by
		var at := SpellTargets.center_of(body)
		var gap := at.distance_to(origin)
		if gap > RADIUS:
			continue
		var away := (at - origin).normalized() if gap > 1.0 else Vector2.UP
		var share := 1.0 - 0.5 * gap / RADIUS
		if body.is_in_group("mobs"):
			body.knock_back(Vector2(away.x * KNOCK * share, minf(away.y * KNOCK * share, LIFT * share)))  # thrown first: the blow may be its last
		else:
			body.push(Vector2(away.x * KNOCK * share * 0.6, minf(away.y * KNOCK * share * 0.6, LIFT * share)))
		SpellTargets.hurt(body, DAMAGE, "Blood")
	for shot in tree.get_nodes_in_group("shots"):
		var from: Vector2 = shot.global_position
		if from.distance_to(origin) <= RADIUS and shot.has_method("reflect"):
			shot.reflect((from - origin).normalized() if from.distance_to(origin) > 1.0 else Vector2.UP)
	var blood: Color = SpellData.SCHOOL_COLORS["Blood"]
	Fx.pop(get_parent(), origin, "circle_03", blood.lightened(0.2), RADIUS * 2.0, 0.45, 1.3)
	Fx.pop(get_parent(), origin, "circle_05", Color(1.0, 0.7, 0.7), RADIUS * 0.8, 0.2, 1.5)
	Fx.burst(get_parent(), origin, blood, 28, 320.0, 0.55, true)
	Sfx.play("explosion", origin, -2.0)
	Sfx.play("blood_cast", origin)
	GameCamera.shake_scene(tree, 0.6)

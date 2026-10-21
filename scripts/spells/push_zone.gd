class_name PushZone
extends SpellEffect

## Push: a circle of force. Everything inside it is shoved once along the line drawn out of the circle: foes, the
## caster, dropped foci, loose rocks, and shots (which are turned back).

const LIFE := 0.5
const KNOCK_SPEED := 700.0

var zone_radius := 40.0  # set by the arena from the drawn circle
var aim := Vector2.RIGHT
var _pushed := false


func _begin(origin: Vector2, aim_angle: float) -> void:
	aim = Vector2.from_angle(aim_angle)
	_life = LIFE
	rotation = aim_angle
	Sfx.play("push", origin)
	var ring := PixelFx.play(get_parent(), origin, "ring", 60.0, maxf(1.0, roundf(zone_radius / 22.0)), Color(0.8, 0.6, 1.0))
	ring.material = Fx.additive()


func _act(_delta: float) -> void:
	if not _pushed and _age > 0.05:
		_pushed = true
		_push_everything()


func _inside(point: Vector2) -> bool:
	return point.distance_to(global_position) <= zone_radius


func _push_everything() -> void:
	for body in SpellTargets.all(get_tree(), team):
		if not (_inside(SpellTargets.center_of(body)) or _inside(body.global_position)):
			continue
		if body.is_in_group("mobs"):
			body.knock_back(aim * KNOCK_SPEED * 1.6)
		else:
			body.push(aim * KNOCK_SPEED * 1.6)  # lifts the caster well above a jump (a jump is about 140 px)
	for item in get_tree().get_nodes_in_group("items"):
		if _inside(item.global_position):
			item.knock(aim * KNOCK_SPEED * 0.6)
	for rock in get_tree().get_nodes_in_group("rocks"):
		if _inside(rock.global_position):
			rock.push(aim * KNOCK_SPEED * 1.6)
	for node in get_tree().get_nodes_in_group("shots"):
		if node is EnemyBolt and team == "player" and _inside(node.global_position):
			node.push(aim)
		elif (node is LavaBall or (node is Projectile and node.team != team)) and _inside(node.global_position):
			node.reflect(aim)


## Gusts of wind flying out across the circle along the line (the ring is a sprite).
func _draw() -> void:
	var gust := PixelFx.frames("wind_bolt", 14.0, true)
	var frame := gust.get_frame_texture("default", int(_age * 14.0) % gust.get_frame_count("default"))
	for i in 3:
		var x := fmod(_age * 300.0 + i * zone_radius * 2.0 / 3.0, zone_radius * 2.0) - zone_radius
		draw_set_transform(Vector2(x, (i - 1) * zone_radius * 0.45), 0.0, Vector2.ONE * 2.0)
		draw_texture(frame, -frame.get_size() * 0.5, Color(0.85, 0.7, 1.0, _fade()))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

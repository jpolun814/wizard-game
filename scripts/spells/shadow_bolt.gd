class_name ShadowBolt
extends Projectile

## Shadow Bolt: a dart of darkness, slow enough to outrun, that bends toward the nearest wizard other than whoever threw it. Ground and stone stop it and a
## Barrier turns it. It fades if it finds nobody.

const SPEED := 270.0
const HARM := 14
const FLIGHT := 4.0
const TURN := 1.5       # how fast it bends toward someone, in radians a second
const NOTICE := 520.0   # how near someone must be for it to bend toward them


func _begin(origin: Vector2, aim_angle: float) -> void:
	aim = Vector2.from_angle(aim_angle)
	add_to_group("projectiles")
	add_to_group("shots")
	rotation = aim_angle
	_life = FLIGHT
	var box := RectangleShape2D.new()
	box.size = Vector2(22, 14)
	_add_shape(box)
	body_entered.connect(_on_hit)
	_trail = Fx.trail(Color("#7a5aa0"), 40, 0.5, 25.0, Vector2.ZERO, "circle_05", 10.0)
	add_child(_trail)
	var dart := PixelFx.sprite("magic_bolt", 14.0)
	dart.scale = Vector2(2.0, 2.0)
	add_child(dart)
	Sfx.play("gravity", origin, -4.0)


func damage() -> int:
	return HARM


func velocity() -> Vector2:
	return aim * SPEED


func _act(delta: float) -> void:
	var prey := _nearest()
	if prey != null:
		var want := (SpellTargets.center_of(prey) - global_position).angle()
		var turn := clampf(angle_difference(aim.angle(), want), -TURN * delta, TURN * delta)
		aim = aim.rotated(turn)
	super._act(delta)


## The nearest wizard it can bend toward: not whoever threw it, and not one beyond its notice.
func _nearest() -> Node2D:
	var best: Node2D = null
	var best_distance := NOTICE
	for wizard: Node2D in SpellTargets.wizards(get_tree()):
		if wizard == caster:
			continue
		var away := SpellTargets.center_of(wizard).distance_to(global_position)
		if away < best_distance:
			best_distance = away
			best = wizard
	return best


func _impact_effect() -> void:
	Fx.burst(get_parent(), global_position, SpellData.SCHOOL_COLORS["Shadow"], 10, 110.0, 0.4, true)
	Sfx.play("gravity", global_position, -8.0)

class_name Thunderclap
extends SpellEffect

## Thunderclap: a peal of thunder cracks round the caster. Everyone near is thrown back, except the caster, and is dazed for a few seconds: they move slowly
## and can cast and chant nothing (see Wizard.daze_time). It does no harm of itself.

const RADIUS := 230.0
const KNOCK := 560.0   # how hard a body is thrown, at the middle; less toward the edge
const LIFT := -260.0
const DAZE := 4.0      # seconds


func _begin(origin: Vector2, _aim_angle: float) -> void:
	_life = 0.5
	var middle: Vector2 = caster.center() if is_instance_valid(caster) else origin
	global_position = middle
	var tree := get_tree()
	for body in SpellTargets.all(tree):
		if body == caster:
			continue  # the one who cracks it stands in its middle, and it passes them by
		var at := SpellTargets.center_of(body)
		var gap := at.distance_to(middle)
		if gap > RADIUS:
			continue
		var away := (at - middle).normalized() if gap > 1.0 else Vector2.UP
		var share := 1.0 - 0.5 * gap / RADIUS
		var throw := Vector2(away.x * KNOCK * share, minf(away.y * KNOCK * share, LIFT * share))
		if body.is_in_group("mobs"):
			body.knock_back(throw)
			body.apply_slow(DAZE)
		else:
			body.push(throw * 0.6)
			body.apply_debuff("daze", DAZE)
	var pale: Color = SpellData.SCHOOL_COLORS["Air"]
	Fx.pop(get_parent(), middle, "circle_03", pale.lightened(0.3), RADIUS * 2.0, 0.5, 1.3)
	Fx.pop(get_parent(), middle, "circle_05", Color(1.0, 1.0, 0.85), RADIUS * 0.7, 0.2, 1.6)
	Fx.burst(get_parent(), middle, Color(1.0, 1.0, 0.8), 26, 380.0, 0.5, true, "star_04")
	Sfx.play("thunder", middle, 4.0)  # a recording of thunder
	Sfx.play("quake", middle, -6.0)  # and the ground rumbling under it
	GameCamera.shake_scene(tree, 0.7)

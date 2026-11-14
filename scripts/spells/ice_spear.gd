class_name IceSpear
extends Projectile

## Frostbolt: a spear of ice thrown along the drawn line. It slows whoever it strikes, shatters on what stops it, and puts out a flame it meets.

const SPEED := 600.0
const HARM := 7
const FLIGHT := 2.0
const SLOW_SECONDS := 2.0
const SHARDS := Color("#b8f0ff")


func _begin(origin: Vector2, aim_angle: float) -> void:
	_life = FLIGHT
	_launch(aim_angle, Vector2(22, 12))
	# Drawn normally rather than as light, and a little blue, so the snow shows up against a snowy level.
	_trail = Fx.trail(Color("#a9dcff"), 36, 0.55, 30.0, Vector2(0, 60), "star_04", 12.0)
	_trail.material = null
	add_child(_trail)
	var shot := PixelFx.sprite("icespear", 18.0)
	shot.offset = Vector2(-18, 0)
	add_child(shot)
	Sfx.play("cast_ice", origin)


func damage() -> int:
	return HARM


func velocity() -> Vector2:
	return aim * SPEED


func _hurt_wizard(wizard: Wizard) -> void:
	super._hurt_wizard(wizard)
	wizard.apply_debuff("slow", SLOW_SECONDS)


func _hurt_mob(mob: Mob) -> void:
	super._hurt_mob(mob)
	mob.apply_slow(SLOW_SECONDS)


## Ice shatters into shards.
func _impact_effect() -> void:
	Shatter.spawn(get_parent(), global_position, SHARDS)
	Sfx.play("ice_shatter", global_position)
	SpellTargets.douse(get_tree(), global_position, 50.0)

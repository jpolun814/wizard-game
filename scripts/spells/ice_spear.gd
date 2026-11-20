class_name IceSpear
extends Projectile

## Frostbolt: a spear of ice thrown along the drawn line. It slows whoever it strikes, shatters on what stops it, and puts out a flame it meets.

const SPEED := 600.0
const HARM := 10
const FLIGHT := 2.0
const SLOW_SECONDS := 2.0
const SHARDS := Color("#b8f0ff")
const HEAD := 13.0  # how far the point of the shard is from the middle of its frame, in art pixels
const DROP := 1.0   # how far below the middle of its frame the shard lies


func _begin(origin: Vector2, aim_angle: float) -> void:
	_life = FLIGHT
	_launch(aim_angle, Vector2(22, 12))
	# The shot itself: pimen's ice shard, its point on the node and its tail streaming behind. Drawn normally rather than as light, so the snow shows up against it.
	var shot := AnimatedSprite2D.new()
	shot.sprite_frames = PixelFx.square_frames("pimen_ice", 16.0, true)
	shot.offset = Vector2(-HEAD, -DROP)
	shot.scale = Vector2(1.0, 1.0)
	shot.play("default")
	add_child(shot)
	Sfx.play("cast_ice", origin)


func damage() -> int:
	return HARM


func velocity() -> Vector2:
	return aim * SPEED


func _hurt_wizard(wizard: Wizard) -> void:
	super._hurt_wizard(wizard)
	wizard.apply_debuff("slow", wizard.coat.frozen_for(SLOW_SECONDS))  # cold bites a wet wizard harder


func _hurt_mob(mob: Mob) -> void:
	super._hurt_mob(mob)
	mob.apply_slow(SLOW_SECONDS)


## Ice shatters into shards.
func _impact_effect() -> void:
	PixelFx.play_square(get_parent(), global_position, "pimen_ice_hit", 18.0, 1.0, aim.angle())
	Shatter.spawn(get_parent(), global_position, SHARDS)
	Sfx.play("ice_shatter", global_position)
	SpellTargets.douse(get_tree(), global_position, 50.0)

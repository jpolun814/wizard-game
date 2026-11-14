class_name Fireball
extends Projectile

## Ignite: a ball of fire thrown along the drawn line. It shoves what it hits, bites a piece out of a snowbank, and sets alight what it passes.

const SPEED := 700.0
const HARM := 12
const FLIGHT := 2.0
const HEAD := 21.0  # how far the head of the fire bolt is from the middle of its frame
const DROP := 6.0  # how far below the middle of its frame the ball of the fire bolt is, in art pixels
const KNOCK := 420.0  # how hard a fireball pushes what it hits


func _begin(origin: Vector2, aim_angle: float) -> void:
	material = Fx.additive()  # fire adds light to what is behind it; ice is solid, with no glow
	add_to_group("fires")
	_life = FLIGHT
	_launch(aim_angle, Vector2(22, 12))
	var embers := Fx.trail(Color("#ff9a40"), 60, 0.35, 25.0, Vector2(0, -60), "flame_05", 12.0)
	embers.texture = PixelFx.ember()
	embers.angle_min = -180.0
	embers.angle_max = 180.0
	_trail = embers
	add_child(_trail)
	# The shot itself: pimen's fire bolt, its head on the node and its tail streaming behind.
	var shot := AnimatedSprite2D.new()
	shot.sprite_frames = PixelFx.square_frames("pimen_firebolt", 16.0, true)
	shot.offset = Vector2(-HEAD, -DROP)  # the ball sits below the middle of its frame: lift it onto the axis the glow, trail and hit box ride on
	shot.scale = Vector2(2.0, 2.0)
	shot.play("default")
	add_child(shot)
	Sfx.play("cast_fire", origin)


func damage() -> int:
	return HARM


func velocity() -> Vector2:
	return aim * SPEED


func _draw() -> void:
	Fx.draw_glow(self, Vector2.ZERO, 20.0 * (1.0 + 0.1 * sin(_age * 30.0)), Color(1.0, 0.45, 0.12, 0.45))


func _hurt_mob(mob: Mob) -> void:
	super._hurt_mob(mob)
	mob.knock_back(aim * KNOCK)  # a fireball shoves the enemy a little along its path


## Fire bursts into sparks and a puff of smoke.
func _impact_effect() -> void:
	PixelFx.play_square(get_parent(), global_position, "pimen_firebolt_hit", 18.0, 2.0, aim.angle())
	Blizzard.melt_at(get_tree(), global_position)  # a fireball that hits a snowbank bites a piece out of it
	Fx.smoke(get_parent(), global_position, Color(0.3, 0.25, 0.25, 0.4), 3, 18.0, 30.0)
	Sfx.play("fire_hit", global_position)

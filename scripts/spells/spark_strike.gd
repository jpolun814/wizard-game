class_name SparkStrike
extends SpellEffect

## Spark: a strike from the sky. It comes straight down through the stroke and stops at the first thing it meets,
## a platform or the ground, so nothing under a platform can be struck from above it.

const LIFE := 0.35
const DAMAGE := 20
const SKY := 420.0  # the strike starts this far above where it lands

var _struck := false


func _begin(origin: Vector2, _aim_angle: float) -> void:
	material = Fx.additive()  # lightning adds light to what is behind it
	_life = LIFE
	var ground := SpellTargets.ground_below(get_world_2d(), Vector2(origin.x, ArenaGen.WALL_TOP * ArenaGen.TILE), 2000.0)
	global_position = Vector2(origin.x, ground.y - SKY)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, SKY)
	_add_shape(rect, Vector2(0, SKY * 0.5))
	# The bolt is a pixel-art strike drawn twice its size, standing on the ground where it lands.
	var strike := PixelFx.play(get_parent(), ground + Vector2(0, 6), "lightning", 24.0, 2.0, Color(1.0, 1.0, 0.85), true)
	strike.z_index = 7
	PixelFx.play(get_parent(), ground, "blast_small", 20.0, 1.0, Color(1.0, 0.95, 0.6), true, false, true)
	Fx.impact(get_parent(), ground, Color("#ffe85a"), 50.0)
	Fx.burst(get_parent(), ground, Color("#ffe85a"), 20, 240.0, 0.4, true, "spark_04")
	Sfx.play("spark", ground)
	GameCamera.shake_scene(get_tree(), 0.25)


func _act(_delta: float) -> void:
	if not _struck and _age > 0.05:
		_struck = true
		_damage_overlapping(DAMAGE)

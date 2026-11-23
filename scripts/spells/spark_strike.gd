class_name SparkStrike
extends SpellEffect

## Spark: a strike from the sky (drawn the whole way down, with `BoltLine`). It comes straight down through the stroke and stops at the first thing it meets,
## a platform or the ground, so nothing under a platform can be struck from above it.

const LIFE := 0.35
const DAMAGE := 30
const SHOCK := 14  # what the water gives to those standing in it
const WIDTH := 26.0  # how wide the strike is where it hits: a little wider than the bolt drawn
const SKY := 420.0  # the strike starts this far above where it lands

var landing := Vector2.ZERO  # where it comes down, for the flames it lights
var _struck := false


func _begin(origin: Vector2, _aim_angle: float) -> void:
	material = Fx.additive()  # lightning adds light to what is behind it
	_life = LIFE
	# Under a roof the strike comes down from the roof, not from the sky above it.
	var start := Vector2(origin.x, maxf(origin.y - SKY, ArenaGen.WALL_TOP * ArenaGen.TILE))  # in the open it comes from the sky over the stroke
	var roof_query := PhysicsRayQueryParameters2D.create(origin, origin + Vector2(0, -SKY))
	roof_query.collision_mask = 1
	var roof := get_world_2d().direct_space_state.intersect_ray(roof_query)
	if not roof.is_empty():
		start = Vector2(origin.x, roof["position"].y + 4.0)
	var ground := SpellTargets.ground_below(get_world_2d(), start, 4000.0, true)
	var height := clampf(ground.y - start.y, 40.0, SKY)
	global_position = Vector2(origin.x, ground.y - height)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WIDTH, height)
	_add_shape(rect, Vector2(0, height * 0.5))
	# The bolt is a pixel-art strike drawn twice its size, standing on the ground where it lands.
	# (owner, 2026-11-22: it came from the middle of the screen: the picture was a short bolt standing on the ground. It now runs the whole way from the sky, or from the roof
	# it came down from, and in the open starts above the top of the view.)
	var sky_top := global_position + (Vector2.ZERO if not roof.is_empty() else Vector2(0.0, -260.0))
	BoltLine.lay(get_parent(), sky_top, ground + Vector2(0, 6), BoltLine.BOLTS, LIFE)
	PixelFx.play(get_parent(), ground, "blast_small", 20.0, 1.0, Color(1.0, 0.95, 0.6), true, false, true)
	Fx.impact(get_parent(), ground, Color("#ffe85a"), 50.0)
	Fx.burst(get_parent(), ground, Color("#ffe85a"), 20, 240.0, 0.4, true, "spark_04")
	Sfx.cue("Spark", "spark", ground)
	landing = ground
	add_to_group("fires")  # lightning sets plants alight
	add_to_group("lightning")  # and strikes a wet body harder (see SpellTargets.hurt)
	_shock_pond(ground)
	for shoal: Piranhas in get_tree().get_nodes_in_group("shoals"):
		shoal.shock(ground - Vector2(0, 20))  # lightning in the water kills the fish
	GameCamera.shake_scene(get_tree(), 0.25)
	ScreenFlash.strike(get_tree(), ground)


## Lightning that lands in a pool runs through the water: whoever stands in it is shocked.
func _shock_pond(ground: Vector2) -> void:
	for pond: Pond in get_tree().get_nodes_in_group("ponds"):
		if pond.lava or ground.x < pond.global_position.x or ground.x > pond.global_position.x + pond.width or ground.y < pond.global_position.y - 10.0:
			continue
		for body in pond.get_overlapping_bodies():
			if not pond.holds(body):
				continue
			SpellTargets.hurt(body, SHOCK, "Fire", false, false, self)
			Fx.burst(get_parent(), SpellTargets.center_of(body), Color("#ffe85a"), 8, 160.0, 0.3, true, "spark_04")


func _act(_delta: float) -> void:
	if not _struck and _age > 0.05:
		_struck = true
		_damage_overlapping(DAMAGE)


## What this fire is to everything else that cares about fire (SpellTargets.fire_points): where it burns, how hot, how big, and whether it is a shot.
func fire_profile() -> Array:
	return [{"at": landing, "heat": 3.0, "size": 14.0, "shot": true}]

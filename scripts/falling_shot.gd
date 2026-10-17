class_name FallingShot
extends Node2D

## A fireball called down from the sky by a fire caster. First a glowing mark appears on the ground where it will
## land, so you have a moment to step aside; then the fireball drops straight onto it.

const WARNING := 0.75
const FALL := 0.3
const HEIGHT := 360.0
const RADIUS := 28.0

var damage := 8
var colour := Color("#ff6a2a")
var _age := 0.0
var _landed := false


## Marks the ground below a point and drops a fireball onto it.
static func call_down(parent: Node, at: Vector2, shot_colour: Color, shot_damage: int) -> FallingShot:
	var shot := FallingShot.new()
	shot.colour = shot_colour
	shot.damage = shot_damage
	parent.add_child(shot)
	shot.global_position = SpellTargets.ground_below(shot.get_world_2d(), at + Vector2(0, -40))
	shot.add_to_group("danger")
	shot.z_index = 4
	return shot


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if not _landed and _age >= WARNING + FALL:
		_landed = true
		SpellTargets.hurt_within(get_tree(), global_position + Vector2(0, -16), RADIUS, damage, "Fire", "enemy")
		Fx.impact(get_parent(), global_position + Vector2(0, -6), colour, 50.0)
		Fx.smoke(get_parent(), global_position, Color(0.3, 0.25, 0.25, 0.4), 3, 22.0, 30.0)
		Sfx.play("fire_hit", global_position)
		queue_free()


func danger_at(point: Vector2) -> bool:
	return absf(point.x - global_position.x) < RADIUS + 6.0 and absf(point.y - global_position.y) < 60.0


## The warning mark is a pixel-art ring lying on the ground, closing in; then a pixel fireball drops onto it.
func _draw() -> void:
	var k := clampf(_age / (WARNING + FALL), 0.0, 1.0)
	var rings := PixelFx.frames("ring", 30.0, true)
	var ring := rings.get_frame_texture("default", int(_age * 30.0) % rings.get_frame_count("default"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
	draw_texture(ring, -ring.get_size() * 0.5, Color(colour.r, colour.g, colour.b, 0.5 + 0.5 * k))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _age > WARNING:
		var t := (_age - WARNING) / FALL
		var at := Vector2(0, -HEIGHT * (1.0 - t * t))
		var balls := PixelFx.frames("fireball", 18.0, true)
		var ball := balls.get_frame_texture("default", int(_age * 18.0) % balls.get_frame_count("default"))
		Fx.draw_glow(self, at, 18.0, Color(colour.r, colour.g, colour.b, 0.6))
		draw_set_transform(at, PI * 0.5, Vector2.ONE)
		draw_texture(ball, -ball.get_size() * 0.5 - Vector2(18, 0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

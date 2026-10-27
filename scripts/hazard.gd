class_name Hazard
extends Area2D

## A patch of burning ground, left where a volcano's lava lands. It burns whoever stands in it for a few seconds.
## Whoever stands in it burns, whoever lit it.

const FIRE_TICK := 0.5
const FIRE_DAMAGE := 5

var width := 24.0
var _age := 0.0
var _life := 3.0
var _tick := 0.0
var _flames: Node2D


## Places a patch centred on the point it is given, standing on the ground there.
static func place(parent: Node, at: Vector2, patch_width: float, life: float) -> Hazard:
	var hazard := Hazard.new()
	hazard.width = patch_width
	hazard._life = life
	hazard.global_position = at
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(patch_width, 14.0)
	shape.shape = rect
	shape.position = Vector2(0, -7)
	hazard.add_child(shape)
	hazard.collision_mask = 6  # the player and enemies
	parent.add_child.call_deferred(hazard)  # lava lands inside a physics callback, where a new area cannot be added yet
	return hazard


func _ready() -> void:
	add_to_group("danger")
	add_to_group("fires")
	# A row of the pixel fire along the patch.
	_flames = Node2D.new()
	_flames.position = Vector2(0, 4.0)
	add_child(_flames)
	var count := maxi(1, ceili(width / 22.0))
	for i in count:
		var flame := PixelFx.sprite("fire_puff", 12.0 + i % 3 * 2.0, true, 1)
		flame.offset = Vector2(0, -PixelArt.FX["fire_puff"]["size"].y * 0.5)
		flame.position = Vector2((i + 0.5) * width / count - width * 0.5, 0.0)
		flame.frame = (i * 2) % 7
		flame.flip_h = i % 2 == 1
		_flames.add_child(flame)


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	_tick -= delta
	if _tick <= 0.0:
		_tick = FIRE_TICK
		for body in get_overlapping_bodies():
			SpellTargets.hurt(body, FIRE_DAMAGE, "Fire")
	_flames.modulate.a = clampf((_life - _age) / 0.5, 0.0, 1.0)
	if _age >= _life:
		queue_free()


func danger_at(point: Vector2) -> bool:
	return absf(point.x - global_position.x) < width * 0.5 + 8.0 and absf(point.y - global_position.y) < 30.0


## Scorched ground with a glow of embers under the flames.
func _draw() -> void:
	var fade := clampf((_life - _age) / 0.8, 0.0, 1.0)
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.18))
	draw_circle(Vector2.ZERO, width * 0.55, Color(0.1, 0.05, 0.03, 0.55 * fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Fx.draw_glow(self, Vector2(0, -3), width * 0.45, Color(1.0, 0.4, 0.1, 0.45 * fade))

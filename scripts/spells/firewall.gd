class_name Firewall
extends SpellEffect

## A wall of fire that rises from the ground under the stroke. It burns whoever stands in it; anyone can walk through.

const LIFE := 4.0
const TICK := 0.5
const DAMAGE := 4
const HEIGHT := 120.0


func _begin(origin: Vector2, _aim_angle: float) -> void:
	material = Fx.additive()  # fire adds light to what is behind it
	_life = LIFE
	global_position = SpellTargets.ground_below(get_world_2d(), origin + Vector2(0, -20)) - Vector2(0, HEIGHT * 0.5)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, HEIGHT + 4.0)
	_add_shape(rect)
	_add_flames()
	add_to_group("danger")
	add_to_group("fires")
	Sfx.play("fire_wall", global_position)


## Four tall flames of the pixel fire, overlapping up the wall so they read as one wall of fire, with embers rising.
func _add_flames() -> void:
	for i in 4:
		var flame := PixelFx.sprite("fire_wall", 14.0 + i * 2.0)
		flame.scale = Vector2.ONE * 2.0
		flame.offset = Vector2(0, -PixelArt.FX["fire_wall"]["size"].y * 0.5)
		flame.position = Vector2(0, HEIGHT * 0.5 - i * HEIGHT / 3.0)
		flame.flip_h = i % 2 == 1
		flame.frame = i * 2
		flame.z_index = 1 - i % 2
		add_child(flame)
	var embers := Fx.trail(Color(1.0, 0.55, 0.2), 24, 0.8, 20.0, Vector2(0, -60), "spark_01", 6.0)
	embers.texture = PixelFx.ember()
	embers.direction = Vector2.UP
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(14, HEIGHT * 0.4)
	add_child(embers)


func _act(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_damage_overlapping(DAMAGE)


## The light the firewall throws on what's behind it; the flames themselves are sprites.
func _draw() -> void:
	Fx.draw_glow(self, Vector2(0, 10), HEIGHT * 0.55, Color(1.0, 0.4, 0.1, 0.3 * _fade()))


## Points up the middle of the wall, from its foot to its top, a flame's height apart.
func flame_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 5:
		points.append(global_position + Vector2(0, HEIGHT * 0.5 - i * HEIGHT / 4.0))
	return points


func danger_at(point: Vector2) -> bool:
	return absf(point.x - global_position.x) < 24.0 and absf(point.y - global_position.y) < HEIGHT * 0.5 + 10.0

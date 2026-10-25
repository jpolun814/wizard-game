class_name Bonfire
extends Node2D

## A bonfire that burns for a while on the ground. Standing near it slowly restores health.
## Its flames are the pixel-art fire column; a warm halo glows round them.

const LIFE := 30.0
const REACH := 90.0          # how close the player must stand to be warmed
const HEAL_PER_SECOND := 4.0

var power := 1.0             # set from the chant's accuracy: a truer chant warms more
var _age := 0.0
var _heal_carry := 0.0       # fractional healing kept between frames
var _flames: Node2D


func _ready() -> void:
	_flames = Node2D.new()
	_flames.material = Fx.additive()
	add_child(_flames)
	_flames.draw.connect(_draw_flames)
	for i in 3:
		var fire := PixelFx.sprite("fire_puff", 12.0 + i * 2.0)  # the same flame as the fire breath and the volcano
		fire.scale = Vector2.ONE * (1.4 if i == 1 else 1.1)
		fire.offset = Vector2(0, -PixelArt.FX["fire_puff"]["size"].y * 0.5)
		fire.position = Vector2(-11 + i * 11, 4)
		fire.flip_h = i == 1
		fire.frame = i * 2
		add_child(fire)


func _process(delta: float) -> void:
	_age += delta
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.global_position.distance_to(global_position) <= REACH and player.max_stamina < player.MAX_STAMINA:
		_heal_carry += HEAL_PER_SECOND * power * delta
		var whole := int(_heal_carry)
		if whole > 0:
			player.heal(whole)
			_heal_carry -= whole
	modulate.a = _fade()
	_flames.queue_redraw()
	if _age >= LIFE:
		queue_free()


func _fade() -> float:
	return clampf((LIFE - _age) / 1.5, 0.0, 1.0)


func _draw_flames() -> void:
	var fade := _fade()
	var warm := 1.0 + 0.08 * sin(_age * 5.0)
	# A warm halo that breathes, behind the flames.
	_flames.draw_circle(Vector2(0, -14), 64.0 * warm, Color(1.0, 0.45, 0.12, 0.05 * fade))
	_flames.draw_circle(Vector2(0, -14), 40.0 * warm, Color(1.0, 0.55, 0.18, 0.08 * fade))
	# Embers rising off the fire and fading as they climb.
	for i in 9:
		var k := fmod(_age * 0.55 + i / 9.0, 1.0)
		var drift := sin(i * 2.3 + _age * 2.0) * 12.0 * k
		_flames.draw_circle(Vector2(drift, -20.0 - k * 50.0), 1.5 * (1.0 - k) + 0.5, Color(1.0, 0.7, 0.3, 0.9 * (1.0 - k) * fade))


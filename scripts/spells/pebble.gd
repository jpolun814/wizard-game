class_name Pebble
extends Projectile

## Pebble: a small stone, slung along the drawn line. Unlike a fireball or an ice spear it falls as it flies, so it can be lobbed over a wall.
## It hits the first body or the ground in its way.

const SPEED := 1050.0
const HARM := 5
const FLIGHT := 2.5
const FALL := 760.0          # pixels a second it gains downward, every second
const ART := preload("res://art/fx/pebble.png")

var _v := Vector2.ZERO
var _picture: Sprite2D


func _begin(origin: Vector2, aim_angle: float) -> void:
	aim = Vector2.from_angle(aim_angle)
	_v = aim * SPEED
	add_to_group("projectiles")
	add_to_group("shots")
	_life = FLIGHT
	var box := RectangleShape2D.new()
	box.size = Vector2(10, 10)
	_add_shape(box)
	body_entered.connect(_on_hit)
	_picture = Sprite2D.new()
	_picture.texture = ART
	_picture.scale = Vector2(2.0, 2.0)
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_picture)
	Sfx.play("push", origin, -4.0)


func damage() -> int:
	return HARM


func velocity() -> Vector2:
	return _v


func _act(delta: float) -> void:
	if _age >= CLEAR_CHECK_AFTER and not _clear and not get_overlapping_bodies().has(caster):
		_clear = true
	_v.y += FALL * delta
	position += (_v + _pulled) * delta
	aim = _v.normalized()
	_picture.rotation = _age * 9.0  # it tumbles


## A turned stone flies off along the new heading, with the speed it had.
func reflect(direction: Vector2) -> void:
	_v = direction.normalized() * _v.length()
	super.reflect(direction)


func _impact_effect() -> void:
	Fx.burst(get_parent(), global_position, Color("#a89270"), 5, 70.0, 0.3, false)
	Sfx.play("stones", global_position, -6.0)

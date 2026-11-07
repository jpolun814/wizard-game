class_name WindBlade
extends Projectile

## Wind Cutter: a thin blade of wind, thrown the way the drawn crescent bulges. It is fast and straight and cuts the first body it meets. It is a shot like
## any other: ground and stone stop it, a Barrier turns it, and a gust turns it.

const SPEED := 1100.0
const HARM := 9
const FLIGHT := 1.1


func _begin(origin: Vector2, aim_angle: float) -> void:
	aim = Vector2.from_angle(aim_angle)
	add_to_group("projectiles")
	add_to_group("shots")
	rotation = aim_angle
	_life = FLIGHT
	var box := RectangleShape2D.new()
	box.size = Vector2(12, 30)
	_add_shape(box)
	body_entered.connect(_on_hit)
	var blade := PixelFx.sprite("wind_bolt", 18.0)
	blade.scale = Vector2(2.0, 2.0)
	blade.modulate = Color(0.85, 0.95, 1.0)
	add_child(blade)
	Sfx.play("push", origin, -2.0)


func damage() -> int:
	return HARM


func velocity() -> Vector2:
	return aim * SPEED


func _impact_effect() -> void:
	Fx.burst(get_parent(), global_position, Color("#d8e4ee"), 6, 90.0, 0.3, true)
	Sfx.play("push", global_position, -8.0)

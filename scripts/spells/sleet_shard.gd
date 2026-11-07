class_name SleetShard
extends Projectile

## One shard of a spray of Sleet: a small, quick bit of ice that sinks a little as it flies and does a little harm. Stone and cover stop it, a Barrier turns it, and a
## flame melts it in the air. It is in the "shots" group, so wind turns it.

const SPEED := 640.0
const HARM := 4
const FLIGHT := 0.5
const FALL := 260.0
const MELT_REACH := 26.0
const ART := preload("res://art/fx/hailstone.png")

var _v := Vector2.ZERO


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
	var picture := Sprite2D.new()
	picture.texture = ART
	picture.scale = Vector2(3.0, 3.0)
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(picture)


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
	for fire: Dictionary in SpellTargets.fire_points(get_tree()):
		if global_position.distance_to(fire["at"]) < MELT_REACH + float(fire["size"]):
			Fx.burst(get_parent(), global_position, Color("#b8f0ff"), 4, 60.0, 0.3, false)
			_finish()  # melted in the air
			return


func reflect(direction: Vector2) -> void:
	_v = direction.normalized() * _v.length()
	super.reflect(direction)


func _impact_effect() -> void:
	Fx.burst(get_parent(), global_position, Color("#b8f0ff"), 4, 60.0, 0.3, false)

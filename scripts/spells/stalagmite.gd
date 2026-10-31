class_name Stalagmite
extends SpellEffect

## A spike of rock that rises out of the ground as a point-up triangle, its base hidden inside the ground. It hurts whatever
## touches it, and stays where it grew.

const TICK := 0.5
const DAMAGE := 6
const RISE := 0.3  # seconds it takes to grow

var polygon := PackedVector2Array()  # the triangle, relative to the middle of its base, which is in the ground; set by the arena before setup
var rock: Texture2D  # the biome's earth, which the spike is made of; set by the arena before setup


func _begin(origin: Vector2, _aim_angle: float) -> void:
	_life = INF
	add_to_group("lasting")
	add_to_group("danger")
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index = -1  # behind the ground, which hides its base
	var shape := ConvexPolygonShape2D.new()
	shape.points = polygon
	_add_shape(shape)
	scale.y = 0.0
	create_tween().tween_property(self, "scale:y", 1.0, RISE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("stones", origin, -2.0)
	Fx.debris(get_parent(), origin, Color("#8a6a4a"), 6, 120.0)


func _act(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_damage_overlapping(DAMAGE)


## The drawn triangle filled with the ground's own earth.
func _draw() -> void:
	var uvs := PackedVector2Array()
	for p in polygon:
		uvs.append(p / rock.get_size())
	draw_colored_polygon(polygon, Color.WHITE, uvs, rock)


func danger_at(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point - global_position, polygon) or (point - global_position).length() < 24.0

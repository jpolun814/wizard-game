class_name Icicle
extends SpellEffect

## Ice that hangs from a ceiling as a point-down triangle, its base hidden inside the ceiling. It hurts whatever
## touches it. Fire melts it a slice at a time from the top while the base stays put, until it is gone: a fireball or a
## ball of lava that strikes it takes a slice off at once, and a steady fire touching any part of it (a firewall,
## burning ground, fire breath) takes slices off as long as it burns there. Otherwise it hangs there.

const TICK := 0.5
const DAMAGE := 6
const MELT_RATE := 0.5  # share of its height a steady fire melts a second
const MELT_STEP := 0.25  # it melts in slices of this share of its height
const MELT_REACH := 20.0  # fire this close to the ice melts it
const ICE := preload("res://art/props/ice_fill.png")

var polygon := PackedVector2Array()  # the triangle, relative to the middle of its base, which is at the ceiling; set by the arena before setup
var _melted := 0.0  # heat taken in from steady fire toward the next slice
var _struck := {}  # shots that have already melted a slice; shrinking the ice makes a shot inside it touch it again


func _begin(origin: Vector2, _aim_angle: float) -> void:
	_life = INF
	add_to_group("lasting")
	add_to_group("danger")
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index = -1  # behind the ceiling, which hides its base
	var shape := ConvexPolygonShape2D.new()
	shape.points = polygon
	_add_shape(shape)
	area_entered.connect(_on_shot)
	Sfx.play("ice_shatter", origin, 2.0)
	Fx.burst(get_parent(), origin, Color("#dff6ff"), 8, 80.0, 0.4, true, "star_04")


func _act(delta: float) -> void:
	_melted += SpellTargets.fire_heat_near(get_tree(), _ice_box(), MELT_REACH) * MELT_RATE * delta
	if _melted >= MELT_STEP:
		_melted -= MELT_STEP
		_melt_slice()
	if is_queued_for_deletion():
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_damage_overlapping(DAMAGE)


## A fireball or a ball of lava that strikes the ice melts a slice off it.
func _on_shot(area: Area2D) -> void:
	if _struck.has(area.get_instance_id()):
		return
	if (area is Projectile and area.spell == "Ignite") or area is LavaBall:
		_struck[area.get_instance_id()] = true
		_melt_slice()


## The top slice melts away: it shrinks toward its base, which is at the origin, until nothing is left.
func _melt_slice() -> void:
	scale.y = maxf(scale.y - MELT_STEP, 0.0)
	if scale.y <= 0.05:
		queue_free()


## The box round the ice that is left, in the world.
func _ice_box() -> Rect2:
	var box := GestureTemplates.bounds(polygon)
	return Rect2(global_position + box.position * Vector2(1.0, scale.y), box.size * Vector2(1.0, scale.y))


## The drawn triangle filled with pixel-art ice.
func _draw() -> void:
	var uvs := PackedVector2Array()
	for p in polygon:
		uvs.append(p / ICE.get_size())
	draw_colored_polygon(polygon, Color(1, 1, 1, 0.95 * _fade()), uvs, ICE)


func danger_at(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point - global_position, polygon) or (point - global_position).length() < 24.0

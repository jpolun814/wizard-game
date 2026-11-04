class_name Thorn
extends Projectile

## One thorn of a volley of Barbs: a short, quick shot that does a little harm. Stone and cover stop it, a Barrier turns it, and a flame burns it up
## in the air. It behaves as any other shot (it is in the "shots" group, so wind turns it and a Black Hole bends it).

const SPEED := 520.0
const HARM := 3
const FLIGHT := 0.5          # seconds in the air: a short throw
const BURN_REACH := 26.0     # how near a flame must be to burn it
const ART := preload("res://art/fx/thorn.png")

var _speed_scale := 1.0


func _begin(origin: Vector2, aim_angle: float) -> void:
	aim = Vector2.from_angle(aim_angle)
	add_to_group("projectiles")
	add_to_group("shots")
	rotation = aim_angle
	_life = FLIGHT
	var box := RectangleShape2D.new()
	box.size = Vector2(22, 8)
	_add_shape(box)
	body_entered.connect(_on_hit)
	var picture := Sprite2D.new()
	picture.texture = ART
	picture.scale = Vector2(2.0, 2.0)
	picture.offset = Vector2(-ART.get_width() * 0.5, 0.0)  # its tip is on the node
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(picture)


func damage() -> int:
	return HARM


func velocity() -> Vector2:
	return aim * SPEED * _speed_scale


func _act(delta: float) -> void:
	super._act(delta)
	for fire: Dictionary in SpellTargets.fire_points(get_tree()):
		if global_position.distance_to(fire["at"]) < BURN_REACH + float(fire["size"]):
			Fx.burst(get_parent(), global_position, Color("#ff9a40"), 4, 60.0, 0.3, true)
			_finish()  # burnt up in the air
			return


func _impact_effect() -> void:
	Fx.burst(get_parent(), global_position, Color("#7fbf5a"), 4, 50.0, 0.3, false)

class_name Scythe
extends Node2D

## Scythe: one wide swing in front of the caster, a half circle of reach. It cuts whoever is inside it, hard, and drives them back a little.
## A wall or the ground between the caster and a body shelters that body. It is over in an instant.

const RADIUS := 120.0
const HARM := 30
const KNOCK := 260.0
const BODY_RADIUS := 24.0
const LIFE := 0.4
const BLADE: Texture2D = preload("res://art/fx/scythe.png")  # a handle, left, and a blade, right; it is held by the left end

var caster_node: Wizard
var facing := 1.0
var _age := 0.0


func _ready() -> void:
	add_to_group("danger")
	if is_instance_valid(caster_node):
		facing = caster_node.facing
		global_position = caster_node.center()
	var blood: Color = SpellData.SCHOOL_COLORS["Blood"]
	_show_swing()
	Fx.burst(get_parent(), global_position + Vector2(facing * RADIUS * 0.7, 0.0), blood, 12, 180.0, 0.4, true)
	Sfx.play("blood_cast", global_position)
	_swing()


## Hurts whoever stands in the half circle in front and in the open to the caster, and drives them back.
func _swing() -> void:
	for body in SpellTargets.all(get_tree()):
		if body == caster_node:
			continue
		var at := SpellTargets.center_of(body)
		if not _reaches(at) or _sheltered(at):
			continue
		SpellTargets.hurt(body, HARM, "Blood", false, false, self)
		var push := Vector2(facing * KNOCK, -60.0)
		if body.is_in_group("mobs"):
			body.knock_back(push)
		else:
			body.push(push)


func _reaches(point: Vector2) -> bool:
	var to := point - global_position
	return to.length() <= RADIUS + BODY_RADIUS and to.x * facing >= -BODY_RADIUS


func _sheltered(point: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, point)
	query.collision_mask = 1  # ground and stone
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## The scythe itself, held by the end of its handle and swung from raised behind the caster down and forward through the half circle, with a pale
## streak of the blade's path behind it.
func _show_swing() -> void:
	var holder := Node2D.new()
	holder.position = Vector2(facing * 10.0, -6.0)
	holder.scale.x = facing  # (a mirror also turns the swing the other way round)
	holder.rotation = -2.3
	holder.z_index = 6
	add_child(holder)
	var blade := Sprite2D.new()
	blade.texture = BLADE
	blade.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	blade.centered = false
	blade.offset = Vector2(0.0, -30.0)
	holder.add_child(blade)
	var tween := holder.create_tween()
	tween.tween_property(holder, "rotation", 1.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(holder, "modulate:a", 0.0, 0.15)
	var streak := Fx.pop(get_parent(), global_position + Vector2(facing * RADIUS * 0.2, 0.0), "slash_01", Color(1.0, 0.55, 0.6), RADIUS * 2.2, 0.3, 1.1, 0.0, true)
	streak.rotation = -PI * 0.5 * facing  # the picture is a smile: turned so it bulges the way the swing goes


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()


func danger_at(point: Vector2) -> bool:
	return _age < LIFE and _reaches(point)

class_name Scythe
extends Node2D

## Scythe: one wide swing in front of the caster, a half circle of reach. It cuts whoever is inside it, hard, and drives them back a little.
## A wall or the ground between the caster and a body shelters that body. It is over in an instant.

const RADIUS := 170.0
const HARM := 45
const KNOCK := 260.0
const BODY_RADIUS := 24.0
const LIFE := 0.4
const BLADE: Texture2D = preload("res://art/fx/scythe.png")  # a shaft, left, and a curved blade hooking down at its end, right; it is held by the left end, and the blade leads the swing (pixel art made for the game, tools/make_scythe.py)

var caster: Wizard
var facing := 1.0
var _age := 0.0


func _ready() -> void:
	add_to_group("danger")
	if is_instance_valid(caster):
		facing = caster.facing
		global_position = caster.center()
	var blood: Color = SpellData.SCHOOL_COLORS["Blood"]
	_show_swing()
	Fx.burst(get_parent(), global_position + Vector2(facing * RADIUS * 0.7, 0.0), blood, 12, 180.0, 0.4, true)
	Sfx.play("blood_cast", global_position)
	_swing()


## Hurts whoever stands in the half circle in front and in the open to the caster, and drives them back.
func _swing() -> void:
	for body in SpellTargets.all(get_tree()):
		if body == caster:
			continue
		var at := SpellTargets.center_of(body)
		if not _reaches(at) or _sheltered(at):
			continue
		SpellTargets.hurt(body, HARM, "Blood", false, false, self)
		var push := Vector2(facing * KNOCK, -60.0)
		if body is Mob:  # (not the group: a mob the blow has just beaten has left it)
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
	holder.scale.x = facing
	holder.rotation = -2.3 * facing  # raised behind the caster: a mirror does not turn the swing round by itself, so the angles are mirrored too
	holder.z_index = 6
	add_child(holder)
	var blade := Sprite2D.new()
	blade.texture = BLADE
	blade.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	blade.material = Fx.additive()  # it is made of light, not iron: the colors of the art are only its shape
	blade.modulate = Color(1.0, 0.4, 0.55, 0.9)
	blade.scale = Vector2(2.0, 2.0)  # whole times the art, so the blade reaches as far as the swing hurts
	blade.offset = Vector2(0.0, -30.0)
	blade.centered = false
	holder.add_child(blade)
	var tween := holder.create_tween()
	tween.tween_property(holder, "rotation", 0.45 * facing, 0.22).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)  # an even sweep, so the whole arc is seen
	tween.tween_property(holder, "modulate:a", 0.0, 0.15)



func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()


func danger_at(point: Vector2) -> bool:
	return _age < LIFE and _reaches(point)

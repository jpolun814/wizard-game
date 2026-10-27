class_name Sentinel
extends Node2D

## A hooded statue that stands in a passage and shoots whoever it sees. It sees what stands in the open air within its
## range: not through rock, not through smoke or an eclipse. It goes for a decoy it sees before it goes for the wizard,
## and wears the decoy down. Its bolts are like any other shot: a Barrier stops them, and they hurt anyone they cross.

const RANGE := 700.0
const FIRST_SHOT := 0.3   # seconds from first seeing someone to the first shot
const INTERVAL := 0.7
const DAMAGE := 40        # what a bolt does to the wizard
const DECOY_DAMAGE := 8   # what it does to a decoy, so a decoy buys several seconds
const ART := preload("res://art/props/statue.png")
const HEIGHT := 120.0

var _seen_for := 0.0
var _cool := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	add_to_group("sentinels")
	_sprite = Sprite2D.new()
	_sprite.texture = ART
	_sprite.scale = Vector2.ONE * (HEIGHT / ART.get_height())
	_sprite.offset = Vector2(0, -ART.get_height() * 0.5 + 2.0)
	_sprite.z_index = 1
	add_child(_sprite)


func center() -> Vector2:
	return global_position + Vector2(0, -HEIGHT * 0.6)


func _physics_process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	var target := _target()
	if target == null:
		_seen_for = 0.0
		return
	_seen_for += delta
	if _seen_for < FIRST_SHOT or _cool > 0.0:
		return
	_cool = INTERVAL
	var at := SpellTargets.center_of(target)
	Sfx.play("spark", center(), -8.0)
	if target is Decoy:  # the shot lands on the decoy at once, so no bolt flies on past it to hit whoever stands behind
		target.take_damage(DECOY_DAMAGE)
		Fx.burst(get_parent(), at, Color("#ff5a40"), 8, 120.0, 0.3)
	else:
		EnemyBolt.fire(get_parent(), center(), at, Color("#ff5a40"), DAMAGE, 0.0, false, "magic_bolt", null)


## Who it shoots at: a decoy it can see, otherwise the wizard if it can see them, otherwise no one.
func _target() -> Node2D:
	for decoy: Decoy in get_tree().get_nodes_in_group("decoys"):
		if not decoy.is_dead() and _sees(decoy.center()):
			return decoy
	var wizard := get_tree().get_first_node_in_group("player")
	if wizard != null and not wizard.dead and _sees(wizard.center()):
		return wizard
	return null


func _sees(point: Vector2) -> bool:
	if center().distance_to(point) > RANGE:
		return false
	var query := PhysicsRayQueryParameters2D.create(center(), point)
	query.collision_mask = 1  # terrain only
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		return false
	return not SpellTargets.sight_blocked(get_tree(), center(), point)

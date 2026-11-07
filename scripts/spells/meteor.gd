class_name Meteor
extends Node2D

## Meteor: a burning rock called down from the sky onto the spot the circle was drawn round. A glow marks the ground where it will land, then a ball of lava
## falls straight down (see LavaBall): it burns whoever it lands on and sets the ground alight. It falls from the sky above the spot that was drawn, so a roof
## between that spot and the ground takes the blow instead.

const WARNING := 0.9
const FALL_SPEED := 1000.0
const SKY := 560.0   # how high above the spot it starts

var _age := 0.0
var _landing := Vector2.ZERO
var _from := Vector2.ZERO
var _thrown := false


func _ready() -> void:
	add_to_group("danger")
	z_index = 2
	var space := get_world_2d().direct_space_state
	var up := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, -SKY))
	up.collision_mask = 1 | 16  # a roof over the drawn spot is as high as it can start: it was drawn under cover
	var roof := space.intersect_ray(up)
	_from = (roof["position"] + Vector2(0, 14)) if not roof.is_empty() else global_position + Vector2(0, -SKY)
	var down := PhysicsRayQueryParameters2D.create(_from, _from + Vector2(0, SKY + 1400.0))
	down.collision_mask = 1 | 16  # and it lands on the first thing below it: the ground, or a roof it was drawn above
	var hit := space.intersect_ray(down)
	_landing = hit["position"] if not hit.is_empty() else global_position
	Sfx.play("fire_wall", _landing, -6.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if not _thrown and _age >= WARNING:
		_thrown = true
		LavaBall.throw(get_parent(), _from, Vector2(0, FALL_SPEED))
	if _age >= WARNING + 0.1:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if _thrown:
		return
	var closeness := _age / WARNING
	var glow := Color(1.0, 0.4, 0.1, 0.25 + 0.4 * closeness)
	Fx.draw_glow(self, _landing - global_position, 26.0 + 22.0 * (1.0 - closeness), glow)


func danger_at(point: Vector2) -> bool:
	return not _thrown and absf(point.x - _landing.x) < 50.0 and point.y > _from.y

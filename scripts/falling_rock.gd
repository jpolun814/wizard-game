class_name FallingRock
extends Node2D

## A rock that has broken loose from the roof of a cavern and drops. It hurts whoever it strikes on the way down (once), and bursts into
## dust on the ground. It is the stalactites' own fall and the cave-ins' rubble.

const GRAVITY := 1400.0
const RADIUS := 22.0
const DAMAGE := 10
const SPRITE := preload("res://art/props/rock_spike_1.png")

var _speed := 0.0
var _ground_y := 0.0
var _struck := false


func _ready() -> void:
	add_to_group("danger")
	z_index = 3
	var sprite := Sprite2D.new()
	sprite.texture = SPRITE
	sprite.flip_v = true  # its point is down, as a stalactite's is
	sprite.scale = Vector2(2.0, 2.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_ground_y = SpellTargets.ground_below(get_world_2d(), global_position + Vector2(0.0, 24.0)).y


func _physics_process(delta: float) -> void:
	_speed += GRAVITY * delta
	global_position.y += _speed * delta
	if not _struck:
		for body: Node2D in SpellTargets.all(get_tree()):
			if SpellTargets.center_of(body).distance_to(global_position) < RADIUS and not (body is Wizard and body.is_likeness()):
				_struck = true
				SpellTargets.hurt(body, DAMAGE, "Earth")
				break
	if global_position.y >= _ground_y - 8.0:
		Fx.smoke(get_parent(), Vector2(global_position.x, _ground_y), Color(0.45, 0.42, 0.4, 0.7), 4, 30.0, 30.0)
		Fx.burst(get_parent(), Vector2(global_position.x, _ground_y - 6.0), Color(0.55, 0.5, 0.45), 8, 140.0, 0.5)
		Sfx.play("stones", global_position, -6.0)
		queue_free()


## True under the rock while it falls.
func danger_at(point: Vector2) -> bool:
	return absf(point.x - global_position.x) < RADIUS + 8.0 and point.y > global_position.y and point.y < _ground_y + 20.0

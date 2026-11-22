class_name FallingRock
extends Node2D

## A rock that has broken loose from the roof of a cavern and drops. It hurts whoever it strikes on the way down (once), and bursts into
## dust on the ground. It is the stalactites' own fall and the cave-ins' rubble.

const GRAVITY := 1400.0
const RADIUS := 22.0
const DAMAGE := 10
const SPRITE := preload("res://art/props/rock_spike_1.png")

var tint := Color(1, 1, 1)  ## set by the cave: the color of the ground's own rock
var _speed := 0.0
var _ground_y := 0.0
var _struck := false
var _drag := 1.0         # how much of its way it covers this frame (a wind holds it back)
var _pulled := Vector2.ZERO
var _side := 0.0         # a sideways drift, once it is shoved
var _turned := 0.0       # seconds since a Barrier turned it, so it is not turned again at once


func _ready() -> void:
	add_to_group("danger")
	add_to_group("shots")  # a stone falling on someone is a shot like any other
	z_index = 3
	var sprite := Sprite2D.new()
	sprite.texture = SPRITE
	sprite.flip_v = true  # its point is down, as a stalactite's is
	sprite.scale = Vector2(2.0, 2.0)
	sprite.modulate = tint
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_ground_y = SpellTargets.ground_below(get_world_2d(), global_position + Vector2(0.0, 24.0)).y


func _physics_process(delta: float) -> void:
	_speed += GRAVITY * delta
	_turned = maxf(_turned - delta, 0.0)
	global_position += (Vector2(_side, _speed) * _drag + _pulled) * delta
	if absf(_side) > 1.0 or _pulled != Vector2.ZERO:
		_ground_y = SpellTargets.ground_below(get_world_2d(), global_position + Vector2(0.0, 24.0)).y  # (it has moved over other ground)
	_drag = 1.0
	_pulled = Vector2.ZERO
	if not _struck:
		for body: Node2D in SpellTargets.all(get_tree()):
			if SpellTargets.center_of(body).distance_to(global_position) < RADIUS and not (body is Wizard and body.is_likeness()):
				if body is Wizard and _turned <= 0.0 and Elements.shield_turns(self, body):  # a Barrier turns it away
					_turned = 0.5
					break
				_struck = true
				SpellTargets.hurt(body, DAMAGE, "Earth")
				break
	if global_position.y >= _ground_y - 8.0:
		Fx.smoke(get_parent(), Vector2(global_position.x, _ground_y), Color(0.45, 0.42, 0.4, 0.7), 4, 30.0, 30.0)
		Fx.burst(get_parent(), Vector2(global_position.x, _ground_y - 6.0), Color(0.55, 0.5, 0.45), 8, 140.0, 0.5)
		Sfx.cue("falling_rock", "rocks", global_position, -6.0)
		queue_free()


## True under the rock while it falls.
func danger_at(point: Vector2) -> bool:
	return absf(point.x - global_position.x) < RADIUS + 8.0 and point.y > global_position.y and point.y < _ground_y + 20.0


## A wind holds it back: for this frame it covers only this much of its way.
func hinder(pace: float) -> void:
	_drag = minf(_drag, pace)


## Which way it is going.
func heading() -> Vector2:
	return Vector2(_side, _speed).normalized()


## A pull on it (a hole).
func pull(force: Vector2, delta: float) -> void:
	_pulled += force * delta


## A shove or a Barrier sends it off sideways, as fast as it was falling, and slower than that.
func reflect(way: Vector2) -> void:
	_side = way.x * maxf(_speed, 200.0) * 0.6

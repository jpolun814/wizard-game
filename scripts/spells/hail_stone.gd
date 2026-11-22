class_name HailStone
extends Area2D

## One stone of a Hailstorm, falling. It stops at the first ground or platform it meets, and hurts the first body it meets before that. It is a shot like any other
## (the group "shots"): wind holds it back or turns it, a hole pulls it, a Barrier turns it away.

const FALL_SPEED := 640.0
const HARM := 5
const ART := preload("res://art/fx/hailstone.png")

var caster: Node
var _spent := false
var _age := 0.0
var _v := Vector2(0.0, FALL_SPEED)  # where it is going, each second
var _drag := 1.0                    # how much of its way it covers this frame (a wind holds it back)
var _pulled := Vector2.ZERO         # a pull on it this frame


func _ready() -> void:
	add_to_group("shots")
	collision_layer = 0
	collision_mask = 1 | 2 | 4 | 16  # ground, enemies, wizards and platforms
	var box := RectangleShape2D.new()
	box.size = Vector2(8, 10)
	var holder := CollisionShape2D.new()
	holder.shape = box
	add_child(holder)
	var picture := Sprite2D.new()
	picture.texture = ART
	picture.scale = Vector2(3.0, 3.0)
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(picture)
	body_entered.connect(_on_hit)


func damage() -> int:
	return HARM


func _physics_process(delta: float) -> void:
	_age += delta
	position += _v * _drag * delta + _pulled * delta
	_drag = 1.0
	_pulled = Vector2.ZERO
	if _age > 3.0:
		queue_free()


func _on_hit(body: Node2D) -> void:
	if _spent:
		return
	_spent = true
	if body.is_in_group("wizards"):
		if body.dead:
			_spent = false
			return
		if Elements.shield_turns(self, body):
			return
		MatchStats.strike(self)
		body.take_damage(HARM, true, true)
	elif body.is_in_group("mobs"):
		if body.is_dead():
			_spent = false
			return
		MatchStats.strike(self)
		body.take_damage(HARM, "Water", true)
	_shatter()


func _shatter() -> void:
	Shatter.spawn(get_parent(), global_position, Color("#cdeeff"))
	Sfx.cue("Hailstorm", "shatter", global_position, -14.0)
	queue_free()


## A Barrier stops it dead (Elements.shield_turns).
func deflected() -> void:
	_shatter()


## A wind holds it back: for this frame it covers only this much of its way. It falls the same way.
func hinder(pace: float) -> void:
	_drag = minf(_drag, pace)


## Which way it is going right now.
func heading() -> Vector2:
	return _v.normalized()


## Something pulls it (a hole).
func pull(force: Vector2, _delta: float) -> void:
	_pulled += force


## A gust or a Barrier turns it: it goes on the new way at the speed it had.
func reflect(direction: Vector2) -> void:
	_v = direction.normalized() * _v.length()
	_spent = false

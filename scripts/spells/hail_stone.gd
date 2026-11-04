class_name HailStone
extends Area2D

## One stone of a Hailstorm, falling. It stops at the first ground or platform it meets, and hurts the first body it meets before that.

const FALL_SPEED := 640.0
const HARM := 5
const ART := preload("res://art/fx/hailstone.png")

var caster: Node
var _spent := false
var _age := 0.0


func _ready() -> void:
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
	position.y += FALL_SPEED * delta
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
		if body.has_shield():
			_shatter()
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
	Sfx.play("ice_shatter", global_position, -14.0)
	queue_free()

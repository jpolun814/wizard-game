class_name SpellEffect
extends Area2D

## A spell's effect in the world. Each kind of effect has its own script that extends this one: Projectile, Firewall,
## Icicle, Blizzard, PushZone, Gust, StoneWall and SparkStrike. This base holds what they share: who cast it, how
## long it lasts, and hurting what stands inside it (see SpellTargets).

var spell := ""
var caster: Node  # who cast it; a few shots pass their caster by at first (see Projectile)
var _age := 0.0
var _life := 1.0
var _tick := 0.0


## Places the effect where it was cast, facing the way it was drawn, and starts it.
func setup(spell_name: String, origin: Vector2, aim_angle: float) -> void:
	spell = spell_name
	global_position = origin
	collision_mask = 7  # terrain, enemies and the player
	_begin(origin, aim_angle)


## Starts the effect: each kind sets its life, its shape and its look here.
func _begin(_origin: Vector2, _aim_angle: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	_act(delta)
	if _age >= _life and not is_queued_for_deletion():
		_finish()


## What the effect does each physics frame.
func _act(_delta: float) -> void:
	pass


## Ends the effect.
func _finish() -> void:
	queue_free()


## How much of its life the effect has left, from 1 when cast down to 0.
func _fade() -> float:
	return clampf(1.0 - _age / _life, 0.0, 1.0)


func _add_shape(shape: Shape2D, at := Vector2.ZERO) -> void:
	var holder := CollisionShape2D.new()
	holder.shape = shape
	holder.position = at
	add_child(holder)


func _damage_overlapping(amount: int) -> void:
	for body in get_overlapping_bodies():
		SpellTargets.hurt(body, amount, _school())


## The school this spell belongs to, which decides what enemies resist or are weak to.
func _school() -> String:
	return SpellData.SPELLS[spell]["school"] if SpellData.SPELLS.has(spell) else "Fire"


## True when a point is in this spell's harm. The dark wizard uses it to step out of danger.
func danger_at(_point: Vector2) -> bool:
	return false

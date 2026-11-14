class_name Projectile
extends SpellEffect

## A shot that flies from the caster: the base of Ignite's Fireball, Frostbolt's IceSpear, the Pebble and the Thorn. It hits the first body or
## wall in its way. It can't hit the one who cast it until it has flown out of their body.

const CLEAR_CHECK_AFTER := 0.05  # the overlaps of a new shot are not known until a few physics frames have passed

var aim := Vector2.RIGHT
var _pulled := Vector2.ZERO  # a pull (a Black Hole's) bends the flight, on top of the aim
var _spent := false
var _clear := false  # it has flown out of its caster's body: from then on it can hit the caster too
var _trail: CPUParticles2D


## What every shot does when it is cast: it flies along the aim, joins the groups that wind and holes in the world look for, and gets hurt by what it hits.
func _launch(aim_angle: float, box: Vector2) -> void:
	aim = Vector2.from_angle(aim_angle)
	add_to_group("projectiles")
	add_to_group("shots")
	rotation = aim_angle
	var shape := RectangleShape2D.new()
	shape.size = box
	_add_shape(shape)
	body_entered.connect(_on_hit)


## Whether it lands on a wizard even in the moment of safety after a hit: a volley of thorns, each of which counts.
func lands_through_grace() -> bool:
	return false


## How hard it hits: each kind of shot says its own.
func damage() -> int:
	return 0


## How fast and which way it is moving: each kind of shot says its own.
func velocity() -> Vector2:
	return Vector2.ZERO


## A steady pull, such as a Black Hole's. Call it every frame the pull lasts.
func pull(force: Vector2, delta: float) -> void:
	_pulled += force * delta


## Which way it is flying right now.
func heading() -> Vector2:
	return aim


func _act(delta: float) -> void:
	if _age >= CLEAR_CHECK_AFTER and not _clear and not get_overlapping_bodies().has(caster):
		_clear = true
	position += (velocity() + _pulled) * delta
	rotation = aim.angle()


func _on_hit(body: Node2D) -> void:
	if _spent or (body == caster and not _clear):
		return  # the one who cast it is safe from it until it has flown clear of them
	if body.is_in_group("wizards") and body.has_shield():
		reflect(Vector2.from_angle(randf() * TAU))  # a Barrier sends it off in a random direction
		return
	if body.is_in_group("wizards"):
		if body.dead:
			return
		_spent = true
		MatchStats.strike(self)
		_hurt_wizard(body)
	elif body.is_in_group("mobs"):
		if body.is_dead():
			return
		_spent = true
		MatchStats.strike(self)
		_hurt_mob(body)
	else:
		_spent = true  # terrain, walls and stone slabs stop it
	_impact_effect()
	_finish()


## What a wizard is dealt: the hit, which a thorn's volley lets land through the moment of safety that follows a blow.
func _hurt_wizard(wizard: Wizard) -> void:
	wizard.take_damage(damage(), not lands_through_grace(), true)


## What a creature is dealt.
func _hurt_mob(mob: Mob) -> void:
	mob.take_damage(damage(), _school(), true)


## What is seen and heard where the shot lands: each kind of shot has its own.
func _impact_effect() -> void:
	pass


## A Gust, Push or Tornado turns this shot: it flies off along the new heading.
func reflect(direction: Vector2) -> void:
	aim = direction.normalized()
	_age = 0.2  # it may hit whoever is in front of it straight away
	_spent = false
	Fx.burst(get_parent(), global_position, Color("#d9b8ff"), 8, 120.0, 0.3, true)
	Sfx.play("push", global_position, -4.0)


## A spent shot's trail is let go to finish fading rather than vanishing with it.
func _finish() -> void:
	if _trail:
		var trail := _trail
		_trail = null
		trail.emitting = false
		trail.reparent(get_parent())
		get_tree().create_timer(trail.lifetime + 0.1).timeout.connect(trail.queue_free)
	queue_free()

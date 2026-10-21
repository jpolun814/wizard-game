class_name Projectile
extends SpellEffect

## A shot that flies straight from the caster: Ignite's fireball or Frostbolt's ice spear. It hits the first foe or
## wall in its way. A Force Wall, Push or Tornado can turn it; a reflected shot changes sides.

const STATS := {
	"Ignite": {"speed": 700.0, "damage": 12, "life": 2.0, "color": Color("#ff7a2a")},
	"Frostbolt": {"speed": 600.0, "damage": 6, "life": 2.0, "color": Color("#b8f0ff")},
}
const SLOW_SECONDS := 2.0
const FIREBALL_KNOCK := 420.0  # how hard a fireball pushes what it hits

var aim := Vector2.RIGHT
var _spent := false
var _trail: CPUParticles2D


func _begin(origin: Vector2, aim_angle: float) -> void:
	aim = Vector2.from_angle(aim_angle)
	if spell == "Ignite":
		material = Fx.additive()  # fire adds light to what is behind it; ice is solid, with no glow
	add_to_group("projectiles")
	add_to_group("shots")
	if spell == "Ignite":
		add_to_group("fires")
	rotation = aim_angle
	_life = STATS[spell]["life"]
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 12)
	_add_shape(rect)
	body_entered.connect(_on_hit)
	_trail = _make_trail()
	add_child(_trail)
	# The shot itself: a pixel-art fireball or ice spear, its head on the node and its tail streaming behind.
	var shot := PixelFx.sprite("fireball" if spell == "Ignite" else "icespear", 18.0)
	shot.offset = Vector2(-18, 0)
	add_child(shot)
	Sfx.play("cast_fire" if spell == "Ignite" else "cast_ice", origin)


func damage() -> int:
	return STATS[spell]["damage"]


func velocity() -> Vector2:
	return aim * STATS[spell]["speed"]


func _act(delta: float) -> void:
	position += velocity() * delta
	rotation = aim.angle()


func _draw() -> void:
	if spell == "Ignite":
		Fx.draw_glow(self, Vector2.ZERO, 20.0 * (1.0 + 0.1 * sin(_age * 30.0)), Color(1.0, 0.45, 0.12, 0.45))


## The trail behind the shot. Ice leaves drifting snow; fire leaves embers of the same pixel fire as the flames.
func _make_trail() -> CPUParticles2D:
	if spell == "Frostbolt":
		# Drawn normally rather than as light, and a little blue, so the snow shows up against a snowy level.
		var snow := Fx.trail(Color("#a9dcff"), 36, 0.55, 30.0, Vector2(0, 60), "star_04", 12.0)
		snow.material = null
		return snow
	var embers := Fx.trail(Color("#ff9a40"), 60, 0.35, 25.0, Vector2(0, -60), "flame_05", 12.0)
	embers.texture = PixelFx.ember()
	embers.angle_min = -180.0
	embers.angle_max = 180.0
	return embers


func _on_hit(body: Node2D) -> void:
	if _spent:
		return
	if body.is_in_group("player"):
		if team == "player":
			return  # a shot never hurts the one who cast it
		_spent = true
		body.take_damage(damage(), true, true)
		if spell == "Frostbolt":
			body.apply_debuff("slow", SLOW_SECONDS)
	elif body.is_in_group("mobs"):
		if team == "enemy" or body.is_dead():
			return  # the dark wizard's shots fly through its allies
		_spent = true
		body.take_damage(damage(), _school())
		if spell == "Ignite":
			body.knock_back(aim * FIREBALL_KNOCK)  # a fireball shoves the enemy a little along its path
		if spell == "Frostbolt":
			body.apply_slow(SLOW_SECONDS)
	else:
		_spent = true  # terrain, walls and stone slabs stop it
	_impact_effect()
	_finish()


## Ice shatters into shards; fire bursts into sparks and a puff of smoke.
func _impact_effect() -> void:
	if spell == "Frostbolt":
		Shatter.spawn(get_parent(), global_position, STATS[spell]["color"])
		Sfx.play("ice_shatter", global_position)
	else:
		PixelFx.play(get_parent(), global_position, "blast_small", 22.0, 1.0)
		Fx.smoke(get_parent(), global_position, Color(0.3, 0.25, 0.25, 0.4), 3, 18.0, 30.0)
		Sfx.play("fire_hit", global_position)


## A Force Wall, Push or Tornado sent this shot back: it turns around and now belongs to the other side.
func reflect(direction: Vector2) -> void:
	aim = direction.normalized()
	team = "enemy" if team == "player" else "player"
	_age = 0.2  # it may hit whoever is in front of it straight away
	_spent = false
	Fx.burst(get_parent(), global_position, Color("#d9b8ff"), 8, 120.0, 0.3, true)
	Sfx.play("force", global_position, -4.0)


## Wind turns the shot to a new heading. Unlike a reflection, it stays with whoever fired it.
func deflect(direction: Vector2) -> void:
	aim = direction.normalized()
	rotation = aim.angle()


## A spent shot's trail is let go to finish fading rather than vanishing with it.
func _finish() -> void:
	if _trail:
		var trail := _trail
		_trail = null
		trail.emitting = false
		trail.reparent(get_parent())
		get_tree().create_timer(trail.lifetime + 0.1).timeout.connect(trail.queue_free)
	queue_free()

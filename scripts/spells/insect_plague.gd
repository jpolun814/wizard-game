class_name InsectPlague
extends SpellEffect

## Insect Plague: a swarm of stinging insects, built as one cloud that ticks and drawn as many insects. It goes after the nearest wizard within reach,
## the caster too once it has been out a few seconds, and stings whoever is in it. One hit on it, a flame, water, smoke or wind, and the whole swarm
## disperses. It gives up when it has had no one to follow for a while, and lasts no longer than a fixed time in all.

const RADIUS := 26.0            # the size of the cloud
const SIGHT := 520.0            # how far off it notices a wizard
const IGNORES_CASTER := 4.0     # seconds after the cast in which it takes no notice of the one who cast it
const SPEED_SHARE := 0.85       # how fast it flies, as a share of a wizard's running speed
const TICK := 0.5               # seconds between stings
const STING := 1
const IDLE_LIMIT := 6.0         # seconds with no one to follow before it gives up
const HARD_LIMIT := 20.0        # the longest it lasts
const INSECTS := 16
const ART := preload("res://art/fx/insect.png")

var _idle := 0.0
var _dispersing := false
var _target: Wizard


func _begin(origin: Vector2, _aim_angle: float) -> void:
	add_to_group("danger")
	_life = HARD_LIMIT
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	_add_shape(shape)
	global_position = origin + Vector2(0.0, -30.0)
	Sfx.play("summon", origin, -8.0)


func _act(delta: float) -> void:
	if _dispersing:
		return
	_target = _nearest_wizard()
	if _target == null:
		_idle += delta
		if _idle >= IDLE_LIMIT:
			disperse()
			return
	else:
		_idle = 0.0
		var to := SpellTargets.center_of(_target) - global_position
		if to.length() > 6.0:
			global_position += to.normalized() * minf(Wizard.SPEED * SPEED_SHARE * delta, to.length())
	if _struck():
		disperse()
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_sting()


## The nearest wizard within sight that it will follow: the caster only once the swarm has been out a while.
func _nearest_wizard() -> Wizard:
	var best: Wizard = null
	var best_gap := SIGHT
	for wizard: Wizard in SpellTargets.wizards(get_tree()):
		if wizard.dead or (wizard == caster and _age < IGNORES_CASTER):
			continue
		var gap := SpellTargets.center_of(wizard).distance_to(global_position)
		if gap < best_gap:
			best_gap = gap
			best = wizard
	return best


## Stings whoever is in the cloud. The caster is passed over for a moment after the cast, as it is not followed.
func _sting() -> void:
	for body in get_overlapping_bodies():
		if not SpellTargets.affects(body) or (body == caster and _age < IGNORES_CASTER):
			continue
		MatchStats.strike(self)
		if body.is_in_group("mobs"):
			body.take_damage(STING, _school())
		else:
			body.take_damage(STING, false)
	Sfx.play("mob_hurt", global_position, -22.0)


## True when something has hit the swarm: a shot, a flame, a cloud of smoke or water, or a gust of wind.
func _struck() -> bool:
	for shot: Node2D in get_tree().get_nodes_in_group("shots"):
		if shot.global_position.distance_to(global_position) < RADIUS + 12.0:
			return true
	for fire: Dictionary in SpellTargets.fire_points(get_tree()):
		if (fire["at"] as Vector2).distance_to(global_position) < RADIUS + 14.0 + maxf(float(fire["size"]), 0.0):
			return true
	for cloud: Node2D in get_tree().get_nodes_in_group("clouds"):
		if cloud == self:
			continue
		var span: Vector2 = cloud.span()
		if global_position.x >= span.x - RADIUS and global_position.x <= span.y + RADIUS and absf(global_position.y - cloud.global_position.y) < 200.0:
			return true  # smoke, snow, hail: anything that hangs in the air
	for pool: Pond in get_tree().get_nodes_in_group("ponds"):
		if pool.lava:
			continue
		if pool.wet_at(global_position):
			return true  # a swarm that meets water is driven off
		for body in get_overlapping_bodies():
			if SpellTargets.affects(body) and pool.holds(body):
				return true  # and so is one on someone who has jumped in
	for area in get_overlapping_areas():
		if area is Gust or area is PushZone or area is Tornado or area is LavaBall:
			return true  # wind, and a thrown flame
	return false


## The swarm scatters and is gone.
func disperse() -> void:
	if _dispersing:
		return
	_dispersing = true
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.6)
	fade.tween_callback(queue_free)


func danger_at(point: Vector2) -> bool:
	return not _dispersing and point.distance_to(global_position) < RADIUS + 10.0


func _draw() -> void:
	var frame_width := ART.get_width() / 2
	for k in INSECTS:
		var phase := float(k) * 2.399  # spread round, no two alike
		var round_it := _age * (2.2 + 0.3 * float(k % 4)) + phase
		var at := Vector2(cos(round_it), sin(round_it * 1.3)) * RADIUS * (0.35 + 0.65 * fmod(float(k) * 0.37, 1.0))
		if _dispersing:
			at *= 1.0 + 3.0 * clampf((1.0 - modulate.a), 0.0, 1.0)
		var frame := int(_age * 18.0 + float(k)) % 2
		draw_texture_rect_region(ART, Rect2(at.floor() - Vector2(frame_width, ART.get_height()) , Vector2(frame_width * 2.0, ART.get_height() * 2.0)), Rect2(frame * frame_width, 0, frame_width, ART.get_height()))

class_name Headwind
extends Node2D

## Headwind: a wind that blows out from the caster in every direction for a while. Anyone or anything that comes into it is slowed, as if walking against the
## wind: wizards and creatures walk slower, and a shot flies slower. A shot is only slowed: not turned, not stopped. The caster, and the caster's own shots, go
## through it as if it were not there.

const SECONDS := 12.0
const RADIUS := 170.0
const SHOT_PACE := 0.4   # how much of its way a shot covers in the wind
const SLOW_FOR := 0.25   # seconds of slowing given each moment a wizard or creature is in it

var caster: Wizard  # set by the arena before it enters the tree
var _age := 0.0
var _puff := 0.0
var _ring := 0.0
var _layering := 0.0


func _ready() -> void:
	for other in get_tree().get_nodes_in_group("headwinds"):
		if other != self and other.caster == caster:
			other.queue_free()  # one each: a new one replaces the old
	add_to_group("headwinds")
	add_to_group("lasting")
	z_index = 4
	global_position = SpellTargets.center_of(caster) if is_instance_valid(caster) else global_position
	_layer()


## The recording is short, so one wind is made of many overlapping layers of it: each starts somewhere in it, at a pitch of its own, and swells and fades, so no
## repeat can be heard. Layers already sounding die away by themselves after the wind ends.
func _layer() -> void:
	if Sfx.muted:
		return
	var path := Sfx.path_of("Headwind", "wind")
	var stream := load(path) as AudioStream
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.bus = Sfx.BUS
	var loud := Sfx.level_of(Sfx.sound_of("Headwind", "wind")) - 3.0
	player.volume_db = -40.0
	player.pitch_scale = Dice.looks.randf_range(0.8, 1.15)
	player.max_distance = Sfx.MAX_DISTANCE
	player.attenuation = 0.6
	get_parent().add_child(player)
	player.global_position = global_position
	var length := stream.get_length()
	var span := minf(length * 0.8, 1.1)
	player.play(Dice.looks.randf() * (length - span))
	var swell := player.create_tween()
	swell.tween_property(player, "volume_db", loud, span * 0.35)
	swell.tween_property(player, "volume_db", -40.0, span * 0.65)
	swell.tween_callback(player.queue_free)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= SECONDS or (is_instance_valid(caster) and caster.dead):
		queue_free()
		return
	if is_instance_valid(caster):
		global_position = SpellTargets.center_of(caster)
	for body in SpellTargets.all(get_tree()):
		if body == caster or SpellTargets.center_of(body).distance_to(global_position) > RADIUS:
			continue
		if body is Wizard:
			body.slow_time = maxf(body.slow_time, SLOW_FOR)
		elif body.has_method("apply_slow"):
			body.apply_slow(SLOW_FOR)
	for shot: Node2D in get_tree().get_nodes_in_group("shots"):
		if shot.has_method("hinder") and shot.global_position.distance_to(global_position) <= RADIUS and not _is_the_casters(shot):
			shot.hinder(SHOT_PACE)
	_layering -= delta
	if _layering <= 0.0:
		_layering = Dice.looks.randf_range(0.3, 0.5)  # a new layer before the last has gone: the howl never stops
		_layer()
	_puff -= delta
	if _puff <= 0.0:
		_puff = Dice.looks.randf_range(0.04, 0.11)
		_blow()


## Whether a shot was loosed by the caster of this wind.
func _is_the_casters(shot: Node) -> bool:
	return is_instance_valid(caster) and (("caster" in shot and shot.caster == caster) or ("_shooter" in shot and shot._shooter == caster))


## A gale: great streaks of wind tear outward from the caster in every direction, dust and scraps are flung before it, and a ring of force rolls out to its edge.
func _blow() -> void:
	for k in 3:
		var angle := Dice.looks.randf() * TAU
		var from := global_position + Vector2.from_angle(angle) * RADIUS * 0.2
		var sprite := Fx.pop(get_parent(), from, "slash_01", Color(0.9, 0.96, 1.0, 0.85), 110.0, 0.35, 1.1, 0.0, true, true)
		sprite.rotation = angle  # (the streak points the way it blows: straight out)
		var rush := sprite.create_tween()
		rush.tween_property(sprite, "global_position", global_position + Vector2.from_angle(angle) * RADIUS * 1.15, 0.35).set_ease(Tween.EASE_IN)
	var out := Dice.looks.randf() * TAU
	var dust := Fx.burst(get_parent(), global_position + Vector2.from_angle(out) * RADIUS * 0.6, Color(0.78, 0.74, 0.66), 5, 300.0, 0.45, false, "smoke_04")  # dust torn off the ground and flung outward
	dust.texture = Fx.soft("smoke_04")  # (smooth, not the chunky pixel cut: this is wind, not a thing)
	dust.direction = Vector2.from_angle(out)
	dust.spread = 25.0
	dust.gravity = Vector2.ZERO
	_ring -= 0.12
	if _ring <= 0.0:
		_ring = Dice.looks.randf_range(0.3, 1.0)
		var shock := Fx.pop(get_parent(), global_position, "circle_02", Color(0.85, 0.93, 1.0, 0.6), RADIUS * Dice.looks.randf_range(0.4, 0.7), Dice.looks.randf_range(0.4, 0.7), 3.4, 0.0, true, true)
		shock.z_index = 4


func danger_at(_point: Vector2) -> bool:
	return false

class_name Fissure
extends Node2D

## Fissure: a jagged crack drawn along the ground. The ground splits open along it, starting where the stroke
## began and racing to where it ended. Rock spikes burst up along the crack, throwing anyone standing on the
## ground there into the air. Flyers and anyone mid-jump are untouched.

const SPEED := 650.0      # how fast the crack runs along the ground
const DAMAGE := 14
const LAUNCH := -420.0
const MAX_LENGTH := 380.0
const STAND_REACH := 14.0 # how close to the ground surface feet must be to count as standing on it
const LINGER := 0.9

var team := "player"
var from_x := 0.0         # where the crack starts and ends, in world x; set before adding to the tree
var to_x := 0.0
var _surface := PackedVector2Array()  # the ground under the crack, one point every 8 pixels
var _age := 0.0
var _front := 0.0         # how far the crack has run
var _length := 0.0
var _hit := {}            # bodies already thrown, so each is hit once
var _spikes: Array = []
var _direction := 1.0
const SPIKES := [preload("res://art/props/rock_spike_1.png"), preload("res://art/props/rock_spike_2.png"),
		preload("res://art/props/rock_spike_3.png")]


func _ready() -> void:
	_direction = signf(to_x - from_x) if to_x != from_x else 1.0
	_length = minf(absf(to_x - from_x), MAX_LENGTH)
	global_position = Vector2(from_x, global_position.y)
	# Follow the ground's surface under the stroke, so the crack runs across steps and mounds.
	var steps := int(_length / 8.0) + 1
	for i in steps + 1:
		var x := from_x + _direction * minf(i * 8.0, _length)
		var top := SpellTargets.solid_below(get_world_2d(), Vector2(x, global_position.y - 60.0), 300.0)
		_surface.append(top - global_position)
	for i in int(_length / 22.0) + 1:
		var k := float(i) / maxf(1.0, _length / 22.0)
		_spikes.append({"at": k, "texture": SPIKES[randi() % SPIKES.size()], "size": 1.0 if randf() < 0.6 else 2.0, "flip": randf() < 0.5})
	add_to_group("danger")
	z_index = 2
	Sfx.play("quake", global_position)
	GameCamera.shake_scene(get_tree(), 0.35)


func _physics_process(delta: float) -> void:
	_age += delta
	_front = minf(_front + SPEED * delta, _length)
	queue_redraw()
	_throw_standing()
	if _front >= _length and _age > _length / SPEED + LINGER:
		queue_free()


## Anyone on the ground over the part of the crack that has opened is thrown up and hurt, once.
func _throw_standing() -> void:
	for body in SpellTargets.all(get_tree(), team):
		if _hit.has(body):
			continue
		var feet: Vector2 = body.global_position
		if body.is_in_group("mobs") and body.KINDS[body.kind]["role"] == "flyer":
			continue
		var along := (feet.x - global_position.x) * _direction
		if along < -10.0 or along > _front + 10.0:
			continue
		var ground := _surface_at(along)
		if absf(feet.y - (global_position.y + ground.y)) > STAND_REACH:
			continue
		_hit[body] = true
		var is_mob: bool = body.is_in_group("mobs")  # checked first: a foe the crack kills leaves the group
		SpellTargets.hurt(body, DAMAGE, "Earth", team)
		if is_mob:
			body.knock_back(Vector2(0, LAUNCH))
		else:
			body.push(Vector2(0, LAUNCH * 0.8))
		Fx.debris(get_parent(), feet, Color("#9c7a52"), 8, 240.0)


func _surface_at(distance: float) -> Vector2:
	var i := clampi(int(maxf(distance, 0.0) / 8.0), 0, _surface.size() - 1)
	return _surface[i]


func danger_at(point: Vector2) -> bool:
	var along := (point.x - global_position.x) * _direction
	return along >= -10.0 and along <= _length + 10.0 and absf(point.y - (global_position.y + _surface_at(along).y)) < 40.0


## Pixel-art rock spikes jut up behind the crack's front, then sink back into the ground.
func _draw() -> void:
	var fade := 1.0 - clampf((_age - _length / SPEED - LINGER + 0.4) / 0.4, 0.0, 1.0)
	for spike in _spikes:
		var d: float = spike["at"] * _length
		if d > _front:
			continue
		var since := (_front - d) / SPEED
		var rise := clampf(since / 0.08, 0.0, 1.0) * (1.0 - clampf((since - 0.35) / 0.3, 0.0, 1.0))
		if rise <= 0.0:
			continue
		var texture: Texture2D = spike["texture"]
		var size: Vector2 = texture.get_size() * float(spike["size"])
		var base := _surface_at(d) * Vector2(_direction, 1.0)
		# It rises out of the ground: the part still below the surface is not drawn.
		var shown := floorf(size.y * rise)
		var source := Rect2(0, 0, texture.get_width(), shown / float(spike["size"]))
		var at := Rect2(base.x - size.x * 0.5, base.y - shown + 2.0, size.x * (-1.0 if spike["flip"] else 1.0), shown)
		draw_texture_rect_region(texture, at, source, Color(1, 1, 1, fade))

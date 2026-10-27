class_name TideSurf
extends Node2D

## Tide Surf: a wave rises under the caster and carries them along the ground the way the crest leans, for a few seconds. They can jump
## off it, but cannot stop or turn back. Whoever stands in the front of it is shoved aside, and it washes out flares and burning ground.
## It does no damage. Its origin is the caster's feet.

const SECONDS := 4.0
const LENGTH := 150.0        # how far the wave reaches behind its crest
const FRONT := 80.0          # how far ahead of the caster it shoves
const SHOVE := Vector2(620.0, -260.0)
const SHOVE_GAP := 0.8       # seconds before it shoves the same one again
const WATER := Color(0.28, 0.6, 0.9, 0.7)
const FOAM := Color(0.92, 0.98, 1.0, 0.9)

var caster_node: Node2D  # set by the arena before it enters the tree
var direction := 1.0
var _age := 0.0
var _shoved := {}  # who it has shoved lately -> seconds until it can again
var _crest: Array[AnimatedSprite2D] = []
var _spray: CPUParticles2D


func _ready() -> void:
	add_to_group("lasting")
	z_index = 6
	caster_node.start_surf(direction, SECONDS)
	for i in 3:
		var splash := PixelFx.sprite("splash", 10.0 + i)
		splash.scale = Vector2(1.5, 1.5)
		splash.offset = Vector2(0, -PixelArt.FX["splash"]["size"].y * 0.5)
		splash.position = Vector2(direction * (FRONT * 0.45 - i * 40.0), -6.0 + i * 3.0)
		splash.flip_h = direction < 0.0
		add_child(splash)
		_crest.append(splash)
	_spray = CPUParticles2D.new()
	_spray.amount = 40
	_spray.lifetime = 0.5
	_spray.direction = Vector2(direction * 0.5, -1.0)
	_spray.spread = 40.0
	_spray.initial_velocity_min = 80.0
	_spray.initial_velocity_max = 220.0
	_spray.gravity = Vector2(0, 600)
	_spray.texture = Geyser.DROPLET
	_spray.scale_amount_min = 0.25
	_spray.scale_amount_max = 0.5
	_spray.color_ramp = Fx.fade_ramp(Color(0.85, 0.96, 1.0, 0.95))
	_spray.local_coords = false
	_spray.position = Vector2(direction * FRONT * 0.5, -16.0)
	add_child(_spray)
	_spray.emitting = true
	global_position = caster_node.global_position
	Sfx.play("snow", global_position, 2.0)
	Sfx.play("push", global_position, -4.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(caster_node) or caster_node.dead or caster_node.fainted or _age >= SECONDS or caster_node.surf_time <= 0.0:
		_end()
		return
	global_position = caster_node.global_position
	queue_redraw()
	for body in _shoved.keys():
		_shoved[body] -= delta
		if _shoved[body] <= 0.0 or not is_instance_valid(body):
			_shoved.erase(body)
	var front := Rect2(global_position.x + (0.0 if direction > 0.0 else -FRONT), global_position.y - 90.0, FRONT, 100.0)
	for body in SpellTargets.all(get_tree()):
		if body == caster_node or _shoved.has(body) or not front.has_point(SpellTargets.center_of(body)):
			continue
		_shoved[body] = SHOVE_GAP
		var impulse := Vector2(SHOVE.x * direction, SHOVE.y)
		if body.is_in_group("mobs"):
			body.knock_back(impulse)
		else:
			body.push(impulse)
		Fx.burst(get_parent(), SpellTargets.center_of(body), FOAM, 8, 140.0, 0.4, true)
	Flare.snuff_near(get_tree(), global_position + Vector2(direction * 40.0, -30.0), 60.0)
	for fire in get_tree().get_nodes_in_group("fires"):
		if fire is Hazard and absf(fire.global_position.x - global_position.x) < LENGTH * 0.5 + fire.width * 0.5 and absf(fire.global_position.y - global_position.y) < 60.0:
			Fx.smoke(get_parent(), fire.global_position, Color(0.85, 0.85, 0.9, 0.6), 4, 20.0, 40.0)
			fire.queue_free()  # a wave over burning ground puts it out


func _end() -> void:
	if is_instance_valid(caster_node):
		caster_node.surf_time = 0.0
	_spray.emitting = false
	set_physics_process(false)
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.4)
	fade.tween_callback(queue_free)


## The water: a low swell behind the crest, lapping at the caster's legs.
func _draw() -> void:
	var back := -direction
	var swell := PackedVector2Array()
	var colours := PackedColorArray()
	var steps := 8
	for i in steps + 1:
		var t := float(i) / steps
		var x := direction * FRONT * 0.7 + back * LENGTH * t
		var height := 20.0 * (1.0 - t * 0.5) + 2.5 * sin(_age * 9.0 + t * 7.0)
		swell.append(Vector2(x, -height))
		colours.append(Color(WATER.r + 0.25 * (1.0 - t), WATER.g + 0.2 * (1.0 - t), WATER.b, WATER.a))
	swell.append(Vector2(direction * FRONT * 0.7 + back * LENGTH, 4.0))
	colours.append(Color(WATER.r * 0.6, WATER.g * 0.7, WATER.b * 0.9, WATER.a))
	swell.append(Vector2(direction * FRONT * 0.7, 4.0))
	colours.append(Color(WATER.r * 0.6, WATER.g * 0.7, WATER.b * 0.9, WATER.a))
	draw_polygon(swell, colours)

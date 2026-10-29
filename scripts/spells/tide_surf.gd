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
const CREST := preload("res://art/fx/surf_crest.png")  # a wave rising and curling over; CC0, see art/CREDITS.md
const BODY := preload("res://art/fx/surf_body.png")    # and the rolling swell behind it
const CREST_SCALE := 2.2
const BODY_SCALE := 1.6
const BODY_TILE := 48.0 * BODY_SCALE
const FOAM := Color(0.92, 0.98, 1.0, 0.9)

var caster_node: Wizard  # set by the arena before it enters the tree
var direction := 1.0
var _age := 0.0
var _frame_time := 0.0
var _shoved := {}  # who it has shoved lately -> seconds until it can again
var _crest: Sprite2D
var _body: Array[Sprite2D] = []
var _spray: CPUParticles2D


func _ready() -> void:
	add_to_group("lasting")
	z_index = 6
	caster_node.start_surf(direction, SECONDS)
	_crest = _strip(CREST, 4, CREST_SCALE, Vector2(direction * (FRONT * 0.5 + 10.0), 4.0))
	for k in 3:  # the swell the wizard rides: tiles of rolling water behind the crest, each a step out of time with the next
		var tile := _strip(BODY, 9, BODY_SCALE, Vector2(direction * (FRONT * 0.5 - 40.0 - k * BODY_TILE), 4.0))
		tile.frame = k * 3
		_body.append(tile)
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
	Sfx.play("surf", global_position)


func _physics_process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(caster_node) or caster_node.dead or caster_node.fainted or _age >= SECONDS or caster_node.surf_time <= 0.0:
		_end()
		return
	global_position = caster_node.global_position
	_frame_time += delta
	_crest.frame = mini(3, int(_frame_time / 0.12))  # it rises and curls over, then holds
	_crest.position.y = 4.0 + 2.0 * sin(_age * 8.0)
	for tile in _body:
		tile.frame = (int(_frame_time * 10.0) + tile.get_index() * 3) % 9
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


## A strip of animation frames laid out side by side, standing on the caster's feet and facing the way the wave runs.
func _strip(texture: Texture2D, frames: int, factor: float, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.hframes = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(factor, factor)
	sprite.flip_h = direction < 0.0
	sprite.offset = Vector2(0, -16)  # the frame's bottom edge sits on the feet
	sprite.position = at
	add_child(sprite)
	return sprite

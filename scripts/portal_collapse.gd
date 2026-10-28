extends Node2D

## The portal the wizards came in by, giving way: it tears open high in the middle of the world, crackles with violet lightning, and then pulls every
## wizard still standing up and into it. It does not end the world itself: the world waits PULL seconds after calling pull() and goes on.

const GROW := 1.5          # seconds for the portal to open to its full size
const PULL := 3.0          # seconds the wizards take to be drawn in
const SIZE := 3.5          # how many times the size of a doorway portal it grows
const CRACKLE_COLOUR := Color(0.55, 0.25, 1.0)  # the portal's violet

var _portal: Portal
var _t := 0.0
var _crackle := 0.0
var _pulled: Array[Node2D] = []
var _trail := 0.0


func _ready() -> void:
	_portal = Portal.new()
	_portal.scale = Vector2.ONE * 0.2
	_portal.z_index = 5  # over the sky and anything in it
	add_child(_portal)
	_portal.open()
	_portal.add_to_group(&"portals")  # the arrow at the edge of the screen points to it
	Sfx.play("portal_open", global_position, -2.0)
	create_tween().tween_property(_portal, "scale", Vector2.ONE * SIZE, GROW).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	_crackle -= delta
	if _crackle <= 0.0:
		_crackle = lerpf(0.35, 0.06, clampf(_t / (GROW + PULL), 0.0, 1.0)) * randf_range(0.6, 1.4)
		var bolt := AnimatedSprite2D.new()
		bolt.sprite_frames = PixelFx.frames("lightning", 24.0, false)
		bolt.material = Fx.additive()
		bolt.modulate = CRACKLE_COLOUR
		bolt.scale = Vector2.ONE * randf_range(1.0, 2.2)
		bolt.offset = Vector2(0.0, -100.0)  # the bolt leaves from the portal
		bolt.rotation = randf() * TAU
		bolt.z_index = 6
		bolt.animation_finished.connect(bolt.queue_free)
		add_child(bolt)
		bolt.play("default")
		if randf() < 0.5:
			Sfx.play("thunder", global_position, -14.0)
	_trail -= delta
	if _trail <= 0.0:
		_trail = 0.05
		for body in _pulled:
			if is_instance_valid(body):
				Fx.burst(get_parent(), body.global_position + Vector2(0.0, -30.0), CRACKLE_COLOUR, 3, 80.0, 0.3, true)


## Draws these wizards into the portal: they can no longer act, rise through the world to it (slowly at first, then faster and faster) and fade as they go.
func pull(wizards: Array) -> void:
	for body: Node2D in wizards:
		_pulled.append(body)
		body.set_physics_process(false)
		body.collision_layer = 0  # nothing in the way, and nothing in the way of it
		body.collision_mask = 0
		if "movement_enabled" in body:
			body.movement_enabled = false
		var tween := body.create_tween().set_parallel()
		tween.tween_property(body, "global_position", global_position + Vector2(0.0, 30.0), PULL).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(body, "modulate:a", 0.0, PULL * 0.4).set_delay(PULL * 0.6)
	Sfx.play("portal_enter", global_position, -2.0)

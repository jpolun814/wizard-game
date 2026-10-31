class_name BlackHole
extends Node2D

## Black Hole: a spiral drawn inward to its middle. A dark knot opens there and pulls everything toward it, hard close in and
## faintly from a long way off, for as long as it lasts. Walls, ceilings and platforms still stop what it pulls. Shots that come
## near are swallowed. It does no harm itself: it gathers everything up for your other spells.

const LIFE := 5.0
const REACH := 2600.0         # how far the pull reaches: a few screens, and it fades to nothing at the edge
const PULL := 4500.0          # pull strength at the middle; it falls off steeply, so it is fierce close in and a faint tug from far off
const SWALLOW_RADIUS := 120.0 # shots this close are swallowed
const DANGER_RADIUS := 200.0  # the AI wizards keep this far from the middle
const SHOW_RADIUS := 140.0    # the size of the knot and its swirl of motes, which is all the eye can take in
const DARK := Color(0.55, 0.35, 0.8)

var _age := 0.0
var _collapsed := false


func _ready() -> void:
	add_to_group("danger")
	z_index = 3
	Sfx.play("gravity", global_position)
	# Motes drawn in from all round, spiralling as they fall toward the middle.
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 0.7
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = SHOW_RADIUS
	p.radial_accel_min = -SHOW_RADIUS * 4.0
	p.radial_accel_max = -SHOW_RADIUS * 3.0
	p.tangential_accel_min = 120.0
	p.tangential_accel_max = 200.0
	p.gravity = Vector2.ZERO
	p.texture = Fx.tex("circle_05")
	p.scale_amount_min = 5.0 / Fx.TEX_SIZE
	p.scale_amount_max = 10.0 / Fx.TEX_SIZE
	p.color_ramp = Fx.fade_ramp(Color(0.35, 0.2, 0.55, 0.9))
	add_child(p)
	p.emitting = true
	# The knot itself: the pixel-art vortex, at a whole number of times its size. It is drawn dark (not as light), so it
	# reads as a hole rather than a glow.
	var vortex := PixelFx.sprite("vortex", 40.0)
	vortex.scale = Vector2.ONE * maxf(1.0, roundf(SHOW_RADIUS / 45.0))
	vortex.modulate = DARK
	add_child(vortex)


func _physics_process(delta: float) -> void:
	_age += delta
	# The vortex is a sprite; it swells in at the start and fades as the hole closes.
	modulate.a = clampf(_age / 0.2, 0.0, 1.0) * (1.0 - clampf((_age - LIFE) / 0.3, 0.0, 1.0))
	if _age < LIFE:
		_pull(delta)
		_swallow_shots()
	elif not _collapsed:
		_collapsed = true
		Fx.impact(get_parent(), global_position, DARK, 60.0)
		Sfx.play("explosion", global_position, -4.0)  # the collapse
		GameCamera.shake_scene(get_tree(), 0.2)
	if _age >= LIFE + 0.3:
		queue_free()


## Every body and every shot in the world is drawn toward the middle; harder the closer it is. Your own black hole tugs at
## you as hard as at anyone.
func _pull(delta: float) -> void:
	for body in SpellTargets.all(get_tree()):
		var force := _force_at(SpellTargets.center_of(body))
		if force != Vector2.ZERO:
			body.pull(force, delta)
	for shot in get_tree().get_nodes_in_group("shots"):
		shot.pull(_force_at(shot.global_position), delta)


func _force_at(point: Vector2) -> Vector2:
	var to_middle := global_position - point
	var distance := to_middle.length()
	if distance > REACH or distance < 4.0:
		return Vector2.ZERO
	return to_middle.normalized() * PULL * pow(1.0 - distance / REACH, 3.0)


## Any shot that comes close spirals in and is gone.
func _swallow_shots() -> void:
	for node in get_tree().get_nodes_in_group("shots"):
		if node.global_position.distance_to(global_position) < SWALLOW_RADIUS:
			Fx.pop(get_parent(), node.global_position, "circle_05", DARK, 20.0, 0.25, 0.2)
			node.queue_free()


func danger_at(point: Vector2) -> bool:
	return point.distance_to(global_position) < DANGER_RADIUS

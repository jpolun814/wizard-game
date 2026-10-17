class_name GravityWell
extends Node2D

## Gravity Well: a spiral drawn inward to its middle. A knot of force forms there and draws everything around it
## in, the way the stroke winds in. Shots that come near are swallowed. It does no harm itself: it gathers foes up
## for your other spells. The wider the spiral, the farther it reaches.

const LIFE := 2.4
const PULL := 900.0          # pull strength at the middle; it weakens toward the edge
const SWALLOW_RADIUS := 0.55 # shots this far in (as a share of the reach) are swallowed
const MIN_REACH := 70.0
const MAX_REACH := 210.0

var team := "player"
var reach := 120.0
var _age := 0.0
var _collapsed := false


func _ready() -> void:
	reach = clampf(reach, MIN_REACH, MAX_REACH)
	add_to_group("danger")
	z_index = 3
	Sfx.play("gravity", global_position)
	# Motes drawn in from all round, spiralling as they fall toward the middle.
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 0.7
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = reach
	p.radial_accel_min = -reach * 4.0
	p.radial_accel_max = -reach * 3.0
	p.tangential_accel_min = 120.0
	p.tangential_accel_max = 200.0
	p.gravity = Vector2.ZERO
	p.texture = Fx.tex("circle_05")
	p.scale_amount_min = 5.0 / Fx.TEX_SIZE
	p.scale_amount_max = 10.0 / Fx.TEX_SIZE
	p.color_ramp = Fx.fade_ramp(Color(0.8, 0.6, 1.0, 0.9))
	p.material = Fx.additive()
	add_child(p)
	p.emitting = true
	# The well itself: a pixel-art vortex, as wide as its reach, at a whole number of times its size.
	var vortex := PixelFx.sprite("vortex", 40.0)
	vortex.scale = Vector2.ONE * maxf(1.0, roundf(reach / 45.0))
	vortex.material = Fx.additive()
	add_child(vortex)


func _physics_process(delta: float) -> void:
	_age += delta
	# The vortex is a sprite; it swells in at the start and fades as the well closes.
	modulate.a = clampf(_age / 0.2, 0.0, 1.0) * (1.0 - clampf((_age - LIFE) / 0.3, 0.0, 1.0))
	if _age < LIFE:
		_pull(delta)
		_swallow_shots()
	elif not _collapsed:
		_collapsed = true
		Fx.impact(get_parent(), global_position, Color("#b07cff"), 60.0)
		Sfx.play("force", global_position)
		GameCamera.shake_scene(get_tree(), 0.2)
	if _age >= LIFE + 0.3:
		queue_free()


## Everyone within reach is drawn toward the middle; harder the closer they are. Your own well tugs at you
## more gently than at your foes.
func _pull(delta: float) -> void:
	for body in SpellTargets.all(get_tree(), team):
		var to_middle := global_position - SpellTargets.center_of(body)
		var distance := to_middle.length()
		if distance > reach or distance < 4.0:
			continue
		var strength := PULL * (1.0 - distance / reach * 0.7)
		var force := to_middle.normalized() * strength
		if body.is_in_group("mobs"):
			body.pull(force, delta)
		else:
			var share := 0.45 if team == "player" else 0.7
			body.push(to_middle.normalized() * strength * share * 0.35)


## Enemy shots and the other side's spells that come close spiral in and are gone.
func _swallow_shots() -> void:
	for node in get_parent().get_children():
		var is_bolt := node is EnemyBolt and team == "player"
		var is_spell: bool = node is SpellEffect and node.team != team and SpellEffect.PROJECTILES.has(node.spell)
		if (is_bolt or is_spell) and node.global_position.distance_to(global_position) < reach * SWALLOW_RADIUS:
			Fx.pop(get_parent(), node.global_position, "circle_05", Color(0.8, 0.6, 1.0), 20.0, 0.25, 0.2)
			node.queue_free()


func danger_at(point: Vector2) -> bool:
	return point.distance_to(global_position) < reach * 0.8

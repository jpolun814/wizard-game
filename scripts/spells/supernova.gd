class_name Supernova
extends Node2D

## Supernova: a small sun that appears where it was drawn and hangs there for a little while. It burns whoever is close and pulls everything
## toward it, a little, so running is hard. Then it blows up: everything near is hurt and thrown away from the middle. The caster is hurt and thrown
## like anyone else (spells have no sides). Walls and ceilings still stop what it pulls.

const SUN: Texture2D = preload("res://art/fx/sun.png")
const RISE := 0.8             # seconds for the sun to swell into being
const HANG := 5.0             # seconds it hangs there before it blows
const BLAST := 0.5            # seconds the explosion shows
const BURN_RADIUS := 170.0    # who is close enough to be burned while it hangs
const BURN := 3
const BURN_GAP := 0.5
const PULL := 1300.0          # the pull at the sun itself; less the farther off
const REACH := 560.0          # how far the pull reaches
const EXPLODE_RADIUS := 260.0
const EXPLODE_DAMAGE := 45
const KNOCK := 650.0          # how hard a body is thrown at the middle; less toward the edge
const LIFT := -240.0
const SHOW_SCALE := 5.0       # the sun's art is 32 px: a whole number of times that
const DANGER_RADIUS := 300.0  # the AI wizards keep this far away

var _age := 0.0
var _burn := 0.0
var _exploded := false
var _sun: Sprite2D
var _glow := 0.0


func _ready() -> void:
	add_to_group("danger")
	z_index = 3
	_sun = Sprite2D.new()
	_sun.texture = SUN
	_sun.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sun.material = Fx.additive()
	add_child(_sun)
	var embers := Fx.trail(Color(1.0, 0.55, 0.2), 30, 0.9, 40.0, Vector2.ZERO, "spark_01", 7.0)
	embers.texture = PixelFx.ember()
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	embers.emission_sphere_radius = 70.0
	embers.radial_accel_min = -120.0
	embers.radial_accel_max = -80.0
	embers.gravity = Vector2.ZERO
	add_child(embers)
	Sfx.play("fire_hit", global_position, -2.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _exploded:
		if _age >= RISE + HANG + BLAST:
			queue_free()
		return
	var grown := clampf(_age / RISE, 0.0, 1.0)
	var closing := clampf((_age - (RISE + HANG - 0.7)) / 0.7, 0.0, 1.0)  # it shrinks and whitens just before it goes
	_sun.scale = Vector2.ONE * SHOW_SCALE * grown * (1.0 - 0.35 * closing) * (1.0 + 0.06 * sin(_age * 15.0))
	_sun.modulate = Color(1.0, 1.0 - 0.3 * closing, 1.0 - 0.7 * closing, grown)
	_glow = grown
	queue_redraw()
	if grown >= 1.0:
		_pull(delta)
		_burn -= delta
		if _burn <= 0.0:
			_burn = BURN_GAP
			_scorch()
	if _age >= RISE + HANG:
		_explode()


func _draw() -> void:
	if not _exploded:
		Fx.draw_glow(self, Vector2.ZERO, BURN_RADIUS * 0.8, Color(1.0, 0.45, 0.12, 0.28 * _glow))


## Everything near is drawn toward the sun, less the farther off it is. A wall or the ground still stops what is pulled.
func _pull(delta: float) -> void:
	for body in SpellTargets.all(get_tree()):
		var to_sun: Vector2 = global_position - SpellTargets.center_of(body)
		var gap: float = to_sun.length()
		if gap > REACH or gap < 8.0:
			continue
		body.pull(to_sun.normalized() * PULL * (1.0 - gap / REACH), delta)
	for shot in get_tree().get_nodes_in_group("shots"):
		var to_sun: Vector2 = global_position - shot.global_position
		var gap: float = to_sun.length()
		if gap <= REACH and gap > 8.0:
			shot.pull(to_sun.normalized() * PULL * (1.0 - gap / REACH), delta)


func _scorch() -> void:
	SpellTargets.hurt_within(get_tree(), global_position, BURN_RADIUS, BURN, "Fire", false, false, self)


func _explode() -> void:
	_exploded = true
	_sun.visible = false
	remove_from_group("danger")
	var tree := get_tree()
	for body in SpellTargets.all(tree):
		var at := SpellTargets.center_of(body)
		var gap := at.distance_to(global_position)
		if gap > EXPLODE_RADIUS:
			continue
		var away := (at - global_position).normalized() if gap > 1.0 else Vector2.UP
		var share := 1.0 - 0.5 * gap / EXPLODE_RADIUS
		if body.is_in_group("mobs"):
			body.knock_back(Vector2(away.x * KNOCK * share, minf(away.y * KNOCK * share, LIFT * share)))  # thrown first: the blow may be its last
		else:
			body.push(Vector2(away.x * KNOCK * share * 0.6, minf(away.y * KNOCK * share * 0.6, LIFT * share)))
		SpellTargets.hurt(body, EXPLODE_DAMAGE, "Fire", false, false, self)
	for shot in tree.get_nodes_in_group("shots"):
		var from: Vector2 = shot.global_position
		if from.distance_to(global_position) <= EXPLODE_RADIUS and shot.has_method("reflect"):
			shot.reflect((from - global_position).normalized() if from.distance_to(global_position) > 1.0 else Vector2.UP)
	var fire: Color = SpellData.SCHOOL_COLORS["Fire"]
	Fx.pop(get_parent(), global_position, "circle_03", fire.lightened(0.2), EXPLODE_RADIUS * 2.0, 0.5, 1.3)
	Fx.pop(get_parent(), global_position, "circle_05", Color(1.0, 0.9, 0.6), EXPLODE_RADIUS * 0.9, 0.25, 1.6)
	Fx.burst(get_parent(), global_position, fire, 40, 420.0, 0.7, true)
	Sfx.play("explosion", global_position)
	GameCamera.shake_scene(tree, 0.9)


func danger_at(point: Vector2) -> bool:
	return point.distance_to(global_position) < DANGER_RADIUS

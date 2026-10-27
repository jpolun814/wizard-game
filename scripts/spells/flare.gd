class_name Flare
extends Node2D

## Flare: a small harmless flame that hovers in front of the caster, where they face, and follows them, lighting the dark until you die or cast another.
## It cuts through an eclipse, and burns nothing: it is a light, not a fire.

const LIGHT_RADIUS := 380.0
const FOLLOW := 16.0  # how quickly it catches up with the caster: quick enough to keep in front at a run
const GRAB := 40.0  # how near a click or a gust has to be to reach it

var caster_node: Node2D  # set by the arena before the flare enters the tree
var _age := 0.0
var _flame: AnimatedSprite2D


func _ready() -> void:
	for other in get_tree().get_nodes_in_group("flares"):
		if other != self and other.caster_node == caster_node:
			other.queue_free()  # one flare each: a new one replaces the old
	add_to_group("flares")
	add_to_group("lasting")
	z_index = 4
	global_position = _rest_spot()
	_flame = PixelFx.sprite("fire_puff", 12.0, true, 1)
	_flame.offset = Vector2(0, -PixelArt.FX["fire_puff"]["size"].y * 0.5)
	_flame.scale = Vector2.ONE * 0.8
	add_child(_flame)
	# In a dark place the flare is a real light. Elsewhere only its glow shows.
	if get_tree().get_first_node_in_group("darkness") != null:
		var light := PointLight2D.new()
		light.texture = Fx.tex("light_01")
		light.texture_scale = LIGHT_RADIUS * 2.0 / Fx.TEX_SIZE
		light.color = Color(1.0, 0.7, 0.4)
		light.energy = 1.3
		light.shadow_enabled = false
		add_child(light)
	Sfx.play("fire_hit", global_position, -8.0)
	Fx.burst(get_parent(), global_position, Color("#ff9a40"), 6, 60.0, 0.4, true)


## In front of the caster, where they face, bobbing a little.
func _rest_spot() -> Vector2:
	if not is_instance_valid(caster_node):
		return global_position
	var bob := sin(_age * 3.0) * 4.0
	var lead: float = caster_node.velocity.x * 0.12 if "velocity" in caster_node else 0.0  # a little ahead of a runner, so it is not left behind
	return SpellTargets.center_of(caster_node) + Vector2(34.0 * caster_node.facing + lead, -30.0 + bob)


func _physics_process(delta: float) -> void:
	_age += delta
	global_position = global_position.lerp(_rest_spot(), clampf(FOLLOW * delta, 0.0, 1.0))
	queue_redraw()
	if (is_instance_valid(caster_node) and "dead" in caster_node and caster_node.dead):
		queue_free()
	for pond: Pond in get_tree().get_nodes_in_group("ponds"):
		if not pond.lava and Rect2(pond.global_position, Vector2(pond.width, pond.depth)).has_point(global_position):
			snuff()  # water puts a flame out
			return


## The light it throws, a soft glow in the air round the flame.
func _draw() -> void:
	var flicker := 1.0 + 0.08 * sin(_age * 17.0)
	Fx.draw_glow(self, Vector2(0, -14), LIGHT_RADIUS * 0.4 * flicker, Color(1.0, 0.55, 0.2, 0.22))


## Puts the flame out, in a puff of smoke.
func snuff() -> void:
	Fx.smoke(get_parent(), global_position + Vector2(0, -14), Color(0.8, 0.8, 0.85, 0.6), 4, 18.0, 30.0)
	Sfx.play("fire_hit", global_position, -4.0)
	queue_free()


## Snuffs every flare within reach of a point. True if any went out.
static func snuff_near(tree: SceneTree, point: Vector2, reach: float) -> bool:
	var out := false
	for flare: Flare in tree.get_nodes_in_group("flares"):
		if flare.global_position.distance_to(point) <= reach + GRAB:
			flare.snuff()
			out = true
	return out


## Snuffs every flare within reach of a line, such as a gust's path.
static func snuff_along(tree: SceneTree, from: Vector2, to: Vector2) -> void:
	for flare: Flare in tree.get_nodes_in_group("flares"):
		if Geometry2D.get_closest_point_to_segment(flare.global_position, from, to).distance_to(flare.global_position) <= GRAB:
			flare.snuff()

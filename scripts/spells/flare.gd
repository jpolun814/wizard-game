class_name Flare
extends Node2D

## Flare: a small harmless flame that hovers in front of the caster, where they face, and follows them, lighting the dark for 20 seconds.
## It cuts through an eclipse, and burns nothing: it is a light, not a fire.

const LIFE := 20.0
const LIGHT_RADIUS := 150.0
const FOLLOW := 5.0  # how quickly it catches up with the caster

var caster_node: Node2D  # set by the arena before the flare enters the tree
var _age := 0.0
var _flame: AnimatedSprite2D


func _ready() -> void:
	add_to_group("flares")
	add_to_group("lasting")
	z_index = 4
	global_position = _rest_spot()
	_flame = PixelFx.sprite("fire_puff", 12.0)
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
	return SpellTargets.center_of(caster_node) + Vector2(34.0 * caster_node.facing, -30.0 + bob)


func _physics_process(delta: float) -> void:
	_age += delta
	global_position = global_position.lerp(_rest_spot(), clampf(FOLLOW * delta, 0.0, 1.0))
	queue_redraw()
	modulate.a = clampf((LIFE - _age) / 1.5, 0.0, 1.0)
	if _age >= LIFE or (is_instance_valid(caster_node) and "dead" in caster_node and caster_node.dead):
		queue_free()


## The light it throws, a soft glow in the air round the flame.
func _draw() -> void:
	var flicker := 1.0 + 0.08 * sin(_age * 17.0)
	Fx.draw_glow(self, Vector2(0, -14), LIGHT_RADIUS * 0.5 * flicker, Color(1.0, 0.55, 0.2, 0.22))

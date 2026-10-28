class_name Glowcap
extends Node2D

## Glowcap: a glowing mushroom grown on the top of the caster's hat that lights their way. It is a light, not a fire: it
## burns nothing, water and wind do not put it out, and it lasts a minute, or until the caster is gone or grows another.

const SECONDS := 60.0
const LIGHT_RADIUS := 300.0  # how far it shows what is hidden in the dark; a flare's is 380
const CAP := preload("res://art/props/glowcap.png")
const HAT_HEIGHT := 73.0  # the top of the hat, over the wizard's feet
const GREEN := Color(0.55, 1.0, 0.65)

var caster_node: Node2D  # set by the arena before it enters the tree
var light_radius := LIGHT_RADIUS
var _age := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	for other in get_tree().get_nodes_in_group("glowcaps"):
		if other != self and other.caster_node == caster_node:
			other.queue_free()  # one cap each: a new one replaces the old
	add_to_group("glowcaps")
	add_to_group("lights")
	add_to_group("lasting")
	z_index = 5
	_sprite = Sprite2D.new()
	_sprite.texture = CAP
	_sprite.offset = Vector2(0, -CAP.get_height() * 0.5 + 2.0)  # it stands on its stem
	add_child(_sprite)
	if get_tree().get_first_node_in_group("darkness") != null:
		var light := PointLight2D.new()
		light.texture = Fx.tex("light_01")
		light.texture_scale = light_radius * 2.0 / Fx.TEX_SIZE
		light.color = GREEN
		light.energy = 1.0
		light.shadow_enabled = false
		add_child(light)
	_follow()
	Fx.burst(get_parent(), global_position, GREEN, 8, 70.0, 0.5, true)
	Sfx.play("pickup", global_position, -10.0)


## Where the mushroom sits: on the top of the hat.
func _rest_spot() -> Vector2:
	var at: Vector2 = caster_node.global_position
	var facing: float = caster_node.facing if "facing" in caster_node else 1.0
	return at + Vector2(2.0 * facing, -HAT_HEIGHT)


func _follow() -> void:
	if is_instance_valid(caster_node):
		global_position = _rest_spot()


func _physics_process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(caster_node) or ("dead" in caster_node and caster_node.dead) or _age >= SECONDS:
		queue_free()
		return
	_follow()
	# It blinks over its last few seconds, so its going out is no surprise.
	_sprite.visible = _age < SECONDS - 4.0 or int(_age * 6.0) % 2 == 0
	queue_redraw()


## The glow round the cap, breathing a little.
func _draw() -> void:
	var breath := 1.0 + 0.1 * sin(_age * 2.5)
	Fx.draw_glow(self, Vector2(0, -8), light_radius * 0.34 * breath, Color(GREEN.r, GREEN.g, GREEN.b, 0.2))
	Fx.draw_glow(self, Vector2(0, -8), 18.0 * breath, Color(GREEN.r, GREEN.g, GREEN.b, 0.3))

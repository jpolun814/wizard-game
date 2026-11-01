class_name Glowcap
extends Node2D

## Glowcap: a glowing mushroom that grows out of the ground where it was drawn and lights what is hidden in the dark near it. It is a light,
## not a fire: it burns nothing, and water and wind do not put it out. It lasts a minute, or until its caster is gone or grows another.
## Anyone who walks into it eats it, and is a little stronger for it, and glows for a few seconds (see GlowAura).

const SECONDS := 60.0
const LIGHT_RADIUS := 300.0  # how far it shows what is hidden in the dark; a flare's is 380
const CAP := preload("res://art/props/glowcap.png")
const GREEN := Color(0.55, 1.0, 0.65)
const GROW_SECONDS := 0.9
const EAT_REACH := 20.0  # how close, across, a wizard must be to eat it
const EAT_HEIGHT := 30.0  # and how far above the ground it is eaten from: a jump over it clears it
const FEED := 1       # how much it raises a wizard's most stamina

var caster_node: Wizard  # set by the arena before it enters the tree
var light_radius := LIGHT_RADIUS
var _age := 0.0
var _sprite: Sprite2D
var _light: PointLight2D


func _ready() -> void:
	for other in get_tree().get_nodes_in_group("glowcaps"):
		if other != self and other.caster_node == caster_node:
			other.queue_free()  # one cap each: a new one replaces the old
	add_to_group("glowcaps")
	add_to_group("lights")
	add_to_group("lasting")
	z_index = 2
	_sprite = Sprite2D.new()
	_sprite.texture = CAP
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0, -CAP.get_height() * 0.5 + 1.0)  # it stands on its stem, which is in the ground
	_sprite.scale = Vector2(1.0, 0.05)
	add_child(_sprite)
	create_tween().tween_property(_sprite, "scale:y", 1.0, GROW_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if get_tree().get_first_node_in_group("darkness") != null:
		_light = PointLight2D.new()
		_light.texture = Fx.tex("light_01")
		_light.texture_scale = light_radius * 2.0 / Fx.TEX_SIZE
		_light.color = GREEN
		_light.energy = 0.0
		_light.shadow_enabled = false
		_light.position = Vector2(0, -16)
		add_child(_light)
	Fx.burst(get_parent(), global_position, GREEN, 8, 70.0, 0.5, true)
	Sfx.play("pickup", global_position, -8.0)  # a rustle of leaves


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= SECONDS:
		queue_free()
		return
	var grown := clampf(_age / GROW_SECONDS, 0.0, 1.0)
	if _light != null:
		_light.energy = grown
	# It blinks over its last few seconds, so its going out is no surprise.
	_sprite.visible = _age < SECONDS - 4.0 or int(_age * 6.0) % 2 == 0
	if grown >= 1.0:
		_look_for_a_mouth()
	queue_redraw()


## A wizard who reaches it eats it.
func _look_for_a_mouth() -> void:
	for body in get_tree().get_nodes_in_group("wizards"):
		var wizard := body as Wizard
		if wizard == null or wizard.dead or wizard.is_likeness():
			continue
		var offset := wizard.global_position - global_position
		if absf(offset.x) <= EAT_REACH and offset.y >= -EAT_HEIGHT and offset.y <= 8.0:
			_eaten_by(wizard)
			return


func _eaten_by(wizard: Wizard) -> void:
	wizard.heal(FEED)
	GlowAura.give(wizard)
	Fx.burst(get_parent(), global_position + Vector2(0, -16), GREEN, 10, 90.0, 0.5, true)
	Sfx.play("pickup", global_position, -4.0)
	queue_free()


## The glow round the cap, breathing a little.
func _draw() -> void:
	var grown := clampf(_age / GROW_SECONDS, 0.0, 1.0)
	var breath := 1.0 + 0.1 * sin(_age * 2.5)
	Fx.draw_glow(self, Vector2(0, -16), light_radius * 0.34 * breath * grown, Color(GREEN.r, GREEN.g, GREEN.b, 0.2))
	Fx.draw_glow(self, Vector2(0, -16), 18.0 * breath * grown, Color(GREEN.r, GREEN.g, GREEN.b, 0.3))

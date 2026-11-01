class_name GlowAura
extends Node2D

## The glow a wizard takes on for a few seconds after eating a Glowcap: a green light that goes with them, lighting what is hidden in the dark
## near them. It is a light, not a fire. Eating another while it lasts starts it again.

const SECONDS := 8.0
const LIGHT_RADIUS := 260.0
const GREEN := Color(0.55, 1.0, 0.65)

var light_radius := LIGHT_RADIUS  # for SpellTargets.lit_near, which asks every light
var _age := 0.0


## Gives a wizard the glow, or starts theirs again.
static func give(wizard: Wizard) -> void:
	for child in wizard.get_children():
		if child is GlowAura:
			child._age = 0.0
			return
	wizard.add_child(GlowAura.new())


func _ready() -> void:
	add_to_group("lights")
	z_index = 5
	position = Vector2(0, -34)  # about the middle of the body
	if get_tree().get_first_node_in_group("darkness") != null:
		var light := PointLight2D.new()
		light.texture = Fx.tex("light_01")
		light.texture_scale = LIGHT_RADIUS * 2.0 / Fx.TEX_SIZE
		light.color = GREEN
		light.energy = 0.9
		light.shadow_enabled = false
		add_child(light)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= SECONDS:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade := clampf((SECONDS - _age) / 2.0, 0.0, 1.0)
	var breath := 1.0 + 0.08 * sin(_age * 3.0)
	Fx.draw_glow(self, Vector2.ZERO, LIGHT_RADIUS * 0.3 * breath, Color(GREEN.r, GREEN.g, GREEN.b, 0.16 * fade))
	Fx.draw_glow(self, Vector2.ZERO, 30.0 * breath, Color(GREEN.r, GREEN.g, GREEN.b, 0.22 * fade))

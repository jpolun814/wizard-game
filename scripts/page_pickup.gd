class_name PagePickup
extends Node2D

## A page of the spellbook that floats and bobs a little above the floor, outlined in the glow of its school. Standing under it and pressing
## Tab reads it into the spellbook, and the page is gone; a page the book already has is not taken, but the book opens at it. Its origin is
## the floor beneath it.

const REACH_X := 36.0
const REACH_Y := 220.0
const FLOAT := 112.0  # how high it floats over the floor
const PAGE := preload("res://art/props/page.png")  # a page of the spellbook
const OUTLINE := preload("res://scripts/page_outline.gdshader")
const CHANT_COLOR := Color("#ffe9a0")
const CHIME_NEAR := 500.0  # a page chimes once when the wizard comes this close
const CHIME_FAR := 720.0   # and again only after they have gone this far from it

var page := ""
var _t := 0.0
var _sprite: Sprite2D
var _hint: Label
var _color := CHANT_COLOR  # the outline
var _glow := CHANT_COLOR   # the light, in the school's own colour
var _chimed := false


func _ready() -> void:
	add_to_group("pages")
	z_index = 3
	if SpellData.SPELLS.has(page):
		_glow = SpellData.SCHOOL_COLORS[SpellData.SPELLS[page].school]
		_color = _glow.lightened(0.2)
	_t = randf() * TAU
	_sprite = Sprite2D.new()
	_sprite.texture = PAGE
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	outline.set_shader_parameter("outline_color", _color)
	_sprite.material = outline
	add_child(_sprite)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color("#ffe9a0"))
	_hint.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.08))
	_hint.add_theme_constant_override("outline_size", 5)
	_hint.position = Vector2(-90.0, -FLOAT - 70.0)
	_hint.size = Vector2(180.0, 20.0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.visible = false
	add_child(_hint)
	material = Fx.additive()  # the halo below adds light to what is behind it
	var light := PointLight2D.new()  # and lights the dark round it, in the school's colour
	light.texture = Fx.tex("light_01")
	light.texture_scale = 420.0 / Fx.TEX_SIZE
	light.color = _glow
	light.energy = 0.9
	light.position = Vector2(0, -FLOAT)
	add_child(light)
	var sparks := Fx.trail(_glow, 14, 1.4, 25.0, Vector2(0, -18), "star_04", 9.0)  # motes of its colour drifting up off it
	sparks.local_coords = true
	sparks.position = Vector2(0, -FLOAT)
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 22.0
	sparks.material = Fx.additive()
	add_child(sparks)
	sparks.emitting = true


func _physics_process(delta: float) -> void:
	_t += delta
	_sprite.position = Vector2(0.0, -FLOAT + sin(_t * 2.0) * 6.0)
	_sprite.rotation = sin(_t * 1.3) * 0.06
	(_sprite.material as ShaderMaterial).set_shader_parameter("strength", 0.75 + 0.25 * sin(_t * 3.0))
	_chime()
	var wizard := get_tree().get_first_node_in_group("player") as Node2D
	_hint.visible = is_underfoot()
	_hint.text = "Press Tab to read" if wizard == null or not wizard.ledger.knows(page) else "Press Tab: already in your book"
	queue_redraw()


## A soft chime as the wizard comes near, so a page is not walked past unheard.
func _chime() -> void:
	var wizard := get_tree().get_first_node_in_group("player") as Node2D
	if wizard == null or wizard.dead or wizard.ledger.knows(page):
		return
	var far := SpellTargets.center_of(wizard).distance_to(global_position + Vector2(0, -FLOAT))
	if not _chimed and far < CHIME_NEAR:
		_chimed = true
		Sfx.play("pickup", global_position + Vector2(0, -FLOAT), -12.0)
	elif _chimed and far > CHIME_FAR:
		_chimed = false


## True while the player's wizard stands under the page.
func is_underfoot() -> bool:
	var wizard := get_tree().get_first_node_in_group("player") as Node2D
	return wizard != null and not wizard.dead and is_under(wizard)


## True while this wizard stands under the page.
func is_under(wizard: Node2D) -> bool:
	var at := SpellTargets.center_of(wizard)
	return absf(at.x - global_position.x) < REACH_X and at.y > global_position.y - REACH_Y and at.y < global_position.y + 30.0


## Reads the page into a wizard's ledger and takes it off the ground, unless the book had it already. Returns its name.
func take(ledger: Ledger) -> String:
	if not ledger.knows(page):
		ledger.learn(page)
		Fx.burst(get_parent(), global_position + Vector2(0, -FLOAT), _color, 14, 130.0, 0.5, true)
		queue_free()
	return page


## The page the wizard stands under, or null.
static func underfoot(tree: SceneTree) -> PagePickup:
	for pickup: PagePickup in tree.get_nodes_in_group("pages"):
		if pickup.is_underfoot():
			return pickup
	return null


func _draw() -> void:
	Fx.draw_glow(self, Vector2(0, -FLOAT), 150.0 + sin(_t * 2.0) * 10.0, Color(_glow.r, _glow.g, _glow.b, 0.22))  # the light seen from afar
	Fx.draw_glow(self, Vector2(0, -FLOAT), 70.0 + sin(_t * 2.6) * 6.0, Color(_glow.r, _glow.g, _glow.b, 0.3))
	Fx.draw_glow(self, Vector2(0, -FLOAT), 34.0 + sin(_t * 3.0) * 3.0, Color(_glow.r, _glow.g, _glow.b, 0.5))

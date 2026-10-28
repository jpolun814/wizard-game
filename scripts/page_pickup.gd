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
var _color := CHANT_COLOR
var _chimed := false


func _ready() -> void:
	add_to_group("pages")
	z_index = 3
	if SpellData.SPELLS.has(page):
		_color = SpellData.SCHOOL_COLORS[SpellData.SPELLS[page].school].lightened(0.2)
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


func _physics_process(delta: float) -> void:
	_t += delta
	_sprite.position = Vector2(0.0, -FLOAT + sin(_t * 2.0) * 6.0)
	_sprite.rotation = sin(_t * 1.3) * 0.06
	(_sprite.material as ShaderMaterial).set_shader_parameter("strength", 0.75 + 0.25 * sin(_t * 3.0))
	_chime()
	var under := is_underfoot()
	_hint.visible = under
	_hint.text = "Press Tab to read" if not Pages.knows(page) else "Press Tab: already in your book"
	queue_redraw()


## A soft chime as the wizard comes near, so a page is not walked past unheard.
func _chime() -> void:
	var wizard := get_tree().get_first_node_in_group("player") as Node2D
	if wizard == null or Pages.knows(page):
		return
	var far := SpellTargets.center_of(wizard).distance_to(global_position + Vector2(0, -FLOAT))
	if not _chimed and far < CHIME_NEAR:
		_chimed = true
		Sfx.play("pickup", global_position + Vector2(0, -FLOAT), -12.0)
	elif _chimed and far > CHIME_FAR:
		_chimed = false


## True while the wizard stands under the page.
func is_underfoot() -> bool:
	var wizard := get_tree().get_first_node_in_group("player") as Node2D
	if wizard == null:
		return false
	var at := SpellTargets.center_of(wizard)
	return absf(at.x - global_position.x) < REACH_X and at.y > global_position.y - REACH_Y and at.y < global_position.y + 30.0


## Reads the page: it is learnt and taken off the ground, unless the book had it already. Returns its name.
func take() -> String:
	if not Pages.knows(page):
		Pages.learn(page)
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
	Fx.draw_glow(self, Vector2(0, -FLOAT), 110.0 + sin(_t * 2.0) * 8.0, Color(_color.r, _color.g, _color.b, 0.07))  # the faint light seen from afar
	Fx.draw_glow(self, Vector2(0, -FLOAT), 34.0 + sin(_t * 3.0) * 3.0, Color(_color.r, _color.g, _color.b, 0.14))

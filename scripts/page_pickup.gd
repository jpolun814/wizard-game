class_name PagePickup
extends Node2D

## A page of the spellbook lying on the ground. Standing on it and pressing Tab reads it into the spellbook, and the page is gone. A faint
## glow lies on it and a hint shows while the wizard stands on it. Its origin is the floor beneath it.

const REACH_X := 36.0
const REACH_Y := 140.0
const PAGE := preload("res://art/props/page.png")  # a page of the spellbook, lying flat

var page := ""
var _t := 0.0
var _hint: Label


func _ready() -> void:
	add_to_group("pages")
	z_index = 3
	var sprite := Sprite2D.new()
	sprite.texture = PAGE
	sprite.centered = false
	sprite.position = Vector2(-PAGE.get_width() * 0.5, -PAGE.get_height() + 4.0)
	add_child(sprite)
	_hint = Label.new()
	_hint.text = "Press Tab to read"
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color("#ffe9a0"))
	_hint.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.08))
	_hint.add_theme_constant_override("outline_size", 5)
	_hint.position = Vector2(-70.0, -170.0)
	_hint.size = Vector2(140.0, 20.0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.visible = false
	add_child(_hint)


func _physics_process(delta: float) -> void:
	_t += delta
	_hint.visible = not Pages.knows(page) and is_underfoot()
	queue_redraw()


## True while the wizard stands on the page.
func is_underfoot() -> bool:
	var wizard := get_tree().get_first_node_in_group("player") as Node2D
	if wizard == null:
		return false
	var at := SpellTargets.center_of(wizard)
	return absf(at.x - global_position.x) < REACH_X and at.y > global_position.y - REACH_Y and at.y < global_position.y + 30.0


## Reads the page: it is learnt and taken off the ground. Returns its name.
func take() -> String:
	Pages.learn(page)
	Fx.burst(get_parent(), global_position + Vector2(0, -16), Color("#ffe9a0"), 12, 120.0, 0.5, true)
	queue_free()
	return page


## The page the wizard stands on that has not been read yet, or null.
static func underfoot(tree: SceneTree) -> PagePickup:
	for pickup: PagePickup in tree.get_nodes_in_group("pages"):
		if not Pages.knows(pickup.page) and pickup.is_underfoot():
			return pickup
	return null


func _draw() -> void:
	Fx.draw_glow(self, Vector2(0, -8), 30.0 + sin(_t * 3.0) * 3.0, Color(1.0, 0.85, 0.45, 0.16))

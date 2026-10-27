class_name PagePickup
extends Node2D

## A page of the spellbook lying on the ground. Walking over it learns what is written on it, and the page is gone. It bobs a little in
## a faint glow. Its origin is the floor beneath it.

const REACH := 46.0
const PAGE := preload("res://art/props/page.png")  # a page of the spellbook, as it is drawn in the book

var page := ""
var _t := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	add_to_group("pages")
	z_index = 3
	_sprite = Sprite2D.new()
	_sprite.texture = PAGE
	_sprite.scale = Vector2.ONE * 0.5
	_sprite.rotation = -0.12
	_sprite.offset = Vector2(0, -PAGE.get_height() * 0.5 - 30.0)
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	_t += delta
	_sprite.position.y = sin(_t * 2.2) * 4.0
	queue_redraw()
	var arena := get_parent()
	var wizard := get_tree().get_first_node_in_group("player") as Node2D
	if wizard == null or Pages.knows(page) or SpellTargets.center_of(wizard).distance_to(global_position + Vector2(0, -40)) > REACH:
		return
	Pages.learn(page)
	if arena.has_method("on_page_found"):
		arena.on_page_found(page)
	Fx.burst(arena, global_position + Vector2(0, -40), Color("#ffe9a0"), 12, 120.0, 0.5, true)
	queue_free()


func _draw() -> void:
	Fx.draw_glow(self, Vector2(0, -42), 34.0 + sin(_t * 3.0) * 3.0, Color(1.0, 0.85, 0.45, 0.2))

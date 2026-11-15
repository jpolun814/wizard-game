class_name LevelWall
extends Node2D

## The nine lights that set how well the AI wizards play (BrainLevel): a row of cave crystals in the waiting room. A shot at one lights it and every
## crystal before it, so the number lit is the level (owner, 2026-11-15). It begins lit to the player's rating (Library). Only the room on its own has
## it: a network match picks its level from the players' ratings instead.

signal chosen(level: int)

const SPACING := 48.0
const UNLIT := Color(0.28, 0.28, 0.36)
const LIT := Color(1.0, 1.0, 1.0)
const GLOW := preload("res://art/particles/light_01.png")

var level := 1
var _crystals: Array[LevelCrystal] = []
var _glows: Array[PointLight2D] = []


## `ground_at` gives the height of the ground at a world x, so each crystal stands on it.
func build(first_x: float, ground_at: Callable, start_level: int) -> void:
	for i in BrainLevel.LEVELS:
		var x := first_x + i * SPACING
		var crystal := LevelCrystal.new()
		crystal.position = Vector2(x, ground_at.call(x))
		add_child(crystal)
		crystal.shot.connect(_on_shot.bind(i + 1))
		_crystals.append(crystal)
		var light := PointLight2D.new()
		light.texture = GLOW
		light.texture_scale = 0.9
		light.energy = 0.0
		light.position = Vector2(x, crystal.position.y - 14.0)
		add_child(light)
		_glows.append(light)
		var number := Label.new()
		number.text = str(i + 1)
		number.add_theme_font_size_override("font_size", 12)
		number.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 0.8))
		number.position = crystal.position + Vector2(-4.0, 4.0)
		add_child(number)
	set_level(start_level, false)


func set_level(new_level: int, announce := true) -> void:
	level = clampi(new_level, 1, BrainLevel.LEVELS)
	for i in _crystals.size():
		var lit := i < level
		_crystals[i].get_node("Sprite").modulate = LIT if lit else UNLIT
		_glows[i].energy = 0.7 if lit else 0.0
	if announce:
		chosen.emit(level)


func _on_shot(which: int) -> void:
	if which == level and which > 0:
		return
	Sfx.play("ritual_ok", _crystals[which - 1].global_position, -8.0)
	set_level(which)

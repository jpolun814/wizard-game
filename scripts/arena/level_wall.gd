class_name LevelWall
extends Node2D

## The nine lights that set how well the AI wizards play (BrainLevel): a column of cave crystals set in the tall stone wall at the end of the waiting room's sparring
## court, the first at the bottom and the ninth at the top. A shot at one lights it and every crystal under it, so the number lit is the level (owner, 2026-11-15).
## It begins lit to the player's rating (Library). Only the room on its own has it: a network match picks its level from the players' ratings instead.

signal chosen(level: int)

const FIRST_HEIGHT := 40.0   # how high above the floor the first crystal is
const STEP := 30.0           # and the rest, each this much above the last
const UNLIT := Color(0.28, 0.28, 0.36)
const LIT := Color(1.0, 1.0, 1.0)
const GLOW := preload("res://art/particles/light_01.png")

var level := 1
var _crystals: Array[LevelCrystal] = []
var _glows: Array[PointLight2D] = []


## `face_x` is the face of the wall the crystals are set in, `floor_y` the floor in front of it, and `open_side` which way the open room lies from the wall (1 is to
## its right, -1 to its left).
func build(face_x: float, floor_y: float, start_level: int, open_side: float) -> void:
	for i in BrainLevel.LEVELS:
		var crystal := LevelCrystal.new()
		crystal.position = Vector2(face_x + open_side * 14.0, floor_y - FIRST_HEIGHT - i * STEP)
		add_child(crystal)
		crystal.shot.connect(_on_shot.bind(i + 1))
		_crystals.append(crystal)
		var light := PointLight2D.new()
		light.texture = GLOW
		light.texture_scale = 0.9
		light.energy = 0.0
		light.position = crystal.position + Vector2(0.0, -14.0)
		add_child(light)
		_glows.append(light)
		var number := Label.new()
		number.text = str(i + 1)
		number.add_theme_font_size_override("font_size", 12)
		number.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 0.85))
		number.position = crystal.position + Vector2(18.0 if open_side > 0.0 else -34.0, -20.0)
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
	if which == level:
		return
	Sfx.play("ritual_ok", _crystals[which - 1].global_position, -8.0)
	set_level(which)

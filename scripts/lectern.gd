class_name Lectern
extends Area2D

## The spellbook on its stand, which starts a run: in the waiting room a person touches it, and the cut-scene (scripts/intro.gd) opens on the same
## book and the same stand. The stand is a stone tomb (nikllamadev's Dungeon Castle pack, widened) and the warning is on a gold plaque on its face (the owner's
## own art), both cut by tools/prepare_lectern.py. The words are so small that nobody can read them until the camera is brought close in the cut-scene.
## The node stands on the floor, and the book rests on top of the stand.

const BOOK := preload("res://art/props/spellbook.png")  # the whole book, closed
const STAND := preload("res://art/props/lectern_stand.png")
const PLAQUE := preload("res://art/props/lectern_plaque.png")
const LETTERING := preload("res://fonts/PirataOne-Regular.ttf")  # gothic letters, as on a plaque
const BOOK_SCALE := 0.8  # the book is drawn a little under its size, so it is not bigger than the stand it rests on
const BOOK_FOOT := 3.0  # the empty rows under the book's own picture, so it rests on the stand and does not float over it
const PLAQUE_AT := Vector2(0.0, -40.0)  # where the plaque is on the face of the stand
const SECOND_PLAQUE_AT := Vector2(0.0, -16.0)  # the second plaque is nailed up below the first
const SECOND_SIZE := 26
const SECOND_LINES := "SERIOUSLY!!"
const WORDS_BOX := Vector2(38.0, 20.0)  # the space the words take on the plaque
const WORDS_SIZE := 20  # drawn large and shrunk, so the letters are clear when the camera comes close
const WORDS_SHRINK := 0.2
const NOTICE_LINES := "Do not touch
this book lest
the world be
torn asunder"

var book: Sprite2D
var second_words: Label  # the words on the second plaque, once it is up
var _aura: BookAura  # what shows the book is no ordinary book: a violet glow behind it and violet smoke rising from it


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4  # the player only
	var height := STAND.get_height() + book_height() - BOOK_FOOT * BOOK_SCALE
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(STAND.get_width(), height)
	shape.shape = rect
	shape.position = Vector2(0.0, -height * 0.5)
	add_child(shape)
	var stand := Sprite2D.new()
	stand.texture = STAND
	stand.offset = Vector2(0.0, -STAND.get_height() * 0.5)
	add_child(stand)
	_make_aura()
	book = Sprite2D.new()
	book.texture = BOOK
	book.offset = Vector2(0.0, -BOOK.get_height() * 0.5)
	book.scale = Vector2.ONE * BOOK_SCALE
	book.position = Vector2(0.0, -STAND.get_height() + BOOK_FOOT * BOOK_SCALE)
	book.z_index = 1
	add_child(book)
	var plaque := Sprite2D.new()
	plaque.texture = PLAQUE
	plaque.position = PLAQUE_AT
	plaque.z_index = 1
	add_child(plaque)
	add_child(_lettered(NOTICE_LINES, PLAQUE_AT, WORDS_SIZE, 2))


## Dark letters on a gold plaque, drawn large and shrunk so that they are clear when the camera comes close.
func _lettered(text: String, at: Vector2, size: int, layer: int) -> Label:
	var words := Label.new()
	words.text = text
	words.add_theme_font_override("font", LETTERING)
	words.add_theme_font_size_override("font_size", size)
	words.add_theme_color_override("font_color", Color(0.2, 0.1, 0.03))
	words.add_theme_constant_override("line_spacing", -4)
	words.add_theme_color_override("font_shadow_color", Color(1.0, 0.86, 0.5, 0.8))  # a lit edge below each letter, as if it were cut into the metal
	words.add_theme_constant_override("shadow_offset_x", 2)
	words.add_theme_constant_override("shadow_offset_y", 3)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.size = WORDS_BOX / WORDS_SHRINK
	words.scale = Vector2.ONE * WORDS_SHRINK
	words.position = at - WORDS_BOX * 0.5
	words.z_index = layer
	return words


## A second plaque nailed on above the first, a little over it, for what the winner has to say. Returns it, so it can be knocked into place.
func hang_second_plaque() -> Node2D:
	var plaque := Sprite2D.new()
	plaque.texture = PLAQUE
	plaque.position = SECOND_PLAQUE_AT
	plaque.z_index = 3
	second_words = _lettered(SECOND_LINES, Vector2.ZERO, SECOND_SIZE, 1)
	second_words.visible_characters = 0  # the plaque goes up blank, and the words are cut into it a few letters at a time
	plaque.add_child(second_words)
	add_child(plaque)
	return plaque


## How tall the book stands as it is drawn.
static func book_height() -> float:
	return BOOK.get_height() * BOOK_SCALE


func _make_aura() -> void:
	_aura = BookAura.new()
	_aura.position = Vector2(0.0, -STAND.get_height() - book_height() * 0.5 + BOOK_FOOT * BOOK_SCALE)
	add_child(_aura)


## The book has come apart: whatever was in it goes with it.
func quiet() -> void:
	_aura.visible = false


## The book is back on its stand, and what was in it with it.
func wake() -> void:
	_aura.visible = true

class_name Lectern
extends Area2D

## The spellbook on its stand, which starts a run: in the waiting room a person touches it, and the cut-scene (scripts/intro.gd) opens on the same
## book and the same stand. The stand is a stone tomb (nikllamadev's Dungeon Castle pack, widened) and the warning is on a gold plaque on its face (the owner's
## own art), both cut by tools/prepare_lectern.py. The words are so small that nobody can read them until the camera is brought close in the cut-scene.
## The node stands on the floor, and the book rests on top of the stand.

const BOOK := preload("res://art/props/spellbook.png")  # the whole book, closed
const STAND := preload("res://art/props/lectern_stand.png")
const PLAQUE := preload("res://art/props/lectern_plaque.png")
const BOOK_SCALE := 0.8  # the book is drawn a little under its size, so it is not bigger than the stand it rests on
const BOOK_FOOT := 3.0  # the empty rows under the book's own picture, so it rests on the stand and does not float over it
const PLAQUE_AT := Vector2(0.0, -14.0)  # where the plaque is on the face of the stand
const WORDS_BOX := Vector2(38.0, 14.0)  # the space the words take on the plaque
const WORDS_SIZE := 20  # drawn large and shrunk, so the letters are clear when the camera comes close
const WORDS_SHRINK := 0.2
const NOTICE_LINES := "Do not touch
this book lest
the world be
torn asunder"

var book: Sprite2D
var _aura: Node2D  # what shows the book is no ordinary book: a violet glow behind it and violet smoke rising from it
var _clock := 0.0


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
	var words := Label.new()
	words.text = NOTICE_LINES
	words.add_theme_font_size_override("font_size", WORDS_SIZE)
	words.add_theme_color_override("font_color", Color(0.2, 0.1, 0.03))  # dark letters on the gold
	words.add_theme_constant_override("line_spacing", -4)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.size = WORDS_BOX / WORDS_SHRINK
	words.scale = Vector2.ONE * WORDS_SHRINK
	words.position = PLAQUE_AT - WORDS_BOX * 0.5
	words.z_index = 2
	add_child(words)


## How tall the book stands as it is drawn.
static func book_height() -> float:
	return BOOK.get_height() * BOOK_SCALE


func _process(delta: float) -> void:
	_clock += delta
	_aura.get_child(0).queue_redraw()


## The book is not still: a violet glow breathes behind it and smoke curls up off its top.
func _make_aura() -> void:
	_aura = Node2D.new()
	add_child(_aura)
	var middle := Vector2(0.0, -STAND.get_height() - book_height() * 0.5 + BOOK_FOOT * BOOK_SCALE)
	var glow := Node2D.new()
	glow.material = Fx.additive()
	glow.draw.connect(func() -> void:
		var breathe := 1.0 + 0.12 * sin(_clock * 2.2)
		Fx.draw_glow(glow, middle, 78.0 * breathe, Color(0.6, 0.22, 1.0, 0.6))
		Fx.draw_glow(glow, middle, 44.0 * breathe, Color(0.75, 0.45, 1.0, 0.45)))
	_aura.add_child(glow)
	var smoke := CPUParticles2D.new()
	smoke.amount = 22
	smoke.lifetime = 2.2
	smoke.position = middle + Vector2(0.0, -book_height() * 0.5)
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(15.0, 2.0)
	smoke.direction = Vector2.UP
	smoke.spread = 30.0
	smoke.initial_velocity_min = 8.0
	smoke.initial_velocity_max = 20.0
	smoke.gravity = Vector2(0.0, -6.0)
	smoke.angle_min = -180.0
	smoke.angle_max = 180.0
	smoke.angular_velocity_min = -30.0
	smoke.angular_velocity_max = 30.0
	smoke.texture = Fx.tex("smoke_04")
	smoke.scale_amount_min = 22.0 / Fx.TEX_SIZE
	smoke.scale_amount_max = 40.0 / Fx.TEX_SIZE
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.5))
	smoke.scale_amount_curve = grow
	smoke.color_ramp = Fx.fade_ramp(Color(0.7, 0.35, 1.0, 0.9))
	smoke.material = Fx.additive()  # it glows, as magic does
	smoke.z_index = 2
	_aura.add_child(smoke)


## The book has come apart: whatever was in it goes with it.
func quiet() -> void:
	_aura.queue_free()
	set_process(false)

class_name Spellbook
extends CanvasLayer

## A pixel-art spellbook held up in front of you (Foxel Games' Pixel Art Book, drawn five times its size). Tab opens
## or closes it, and it falls open and shut; Left and Right turn the pages, which flip over. It doesn't pause
## anything, so you can keep casting and typing while you read. Buttons are drawn as a mouse with the held buttons lit
## up, and every spell's shape is drawn on the book's own pixel grid.

const SHIFT_LEAVES := 5  # how many leaves a turn takes with Shift held
## The star beside "NEW!": an interface element made of pixel squares (O outline, G gold, H highlight, S shade), drawn at three times its size.
const SPARKLE_ROWS := ["...O...", "...G...", "..OGO..", "OGGHGGO", "..OGO..", "...G...", "...O..."]   # a tiny four-point twinkle, as coarse as the art round it
const SPARKLE_COLORS := {"O": Color("#8a5a10"), "G": Color("#f2b81c"), "H": Color("#fff2b0")}
const SPARKLE_SCALE := 2
const NEW_GOLD := Color("#f2b81c")
const INK := Color("#3a1d1a")
const TEXT_INK := Color(INK, 0.86)  # the writing is a touch lighter than the drawings, as if the pen was lifted
const HEADING := Color("#6e1420")
const SUBTLE := Color("#6b4434")
const PAPER_DARK := Color("#b88f72")
const SCALE := 5.0             # one pixel of the book is this many screen pixels
const FRAME := Vector2(190, 160)
const OPEN := 3                # the book's frames: 0 closed, 1-2 opening, 3 open, 4-6 a page turning over
const PAGES := [Rect2(25, 30, 57, 100), Rect2(98, 30, 58, 100)]  # where the writing goes, in book pixels
const FRAME_TIME := 0.06
const OPEN_MIDDLE := Vector2(90.5, 83.5)  # the middle of the open book in its frame

## The schools, in the order they appear in the book.
const SCHOOLS := ["Fire", "Water", "Air", "Earth", "Flora", "Shadow", "Blood"]

var _spread := 0
var _pages: Array[Callable] = []
var _page_of := {}  # a spell's name, or "chant:" and a chant's id -> the index of its page
var _book: BookArt
var _left: VBoxContainer
var _right: VBoxContainer
var _text_font: Font
var _title_font: Font
var _faces: Array[Font] = []
var _title_faces: Array[Font] = []
const FACE_FILES := ["res://fonts/Jersey15-Regular.ttf"]  # the face the text of the book is written in (names and headings are in Lettering.FACE)
var _left_number: Label  # the page numbers, at the foot of each page
var _right_number: Label


func _ready() -> void:
	visible = false
	layer = 5  # under the ritual typing box (layer 10), so the book never covers what you type

	_build_pages()

	# Each page is set in one of the candidate hands, in turn, so the pages can be compared as the book is turned.
	for path in FACE_FILES:
		var face: Font = load(path)
		_faces.append(face)
		_title_faces.append(Lettering.FACE)

	_book = BookArt.new()
	_book.size = FRAME * SCALE
	add_child(_book)
	_centre_book()
	get_viewport().size_changed.connect(_centre_book)  # a window made full screen keeps the book in the middle
	_left = _page_column(PAGES[0])
	_right = _page_column(PAGES[1])
	_use_face(0)
	_left_number = _page_number(_left)
	_right_number = _page_number(_right)

	_show_spread()


## The pages of the book: the cheat sheet, then a page to each spell and chant that is known. In the tutorial they come in the order they were found. In
## the waiting room, where every page is known, and in a match they are grouped by school, and within a school (in a match) in the order they were found;
## the chants come last.
func _build_pages() -> void:
	_pages = [_page_contents]
	_page_of = {}
	if _ledger().everything:
		for school in SCHOOLS:
			for spell_name in _spells_of(school):
				_add_spell_page(spell_name)
		for ritual_id in RitualInput.RITUALS:
			_add_chant_page(ritual_id)
		return
	if not get_parent() is Tutorial:
		for school in SCHOOLS:
			for page: String in _ledger().pages:
				if SpellData.SPELLS.has(page) and SpellData.SPELLS[page].school == school:
					_add_spell_page(page)
		for page: String in _ledger().pages:
			if page.begins_with("chant:"):
				_add_chant_page(page.trim_prefix("chant:"))
		return
	for page: String in _ledger().pages:
		if page.begins_with("chant:"):
			_add_chant_page(page.trim_prefix("chant:"))
		else:
			_add_spell_page(page)


func _add_spell_page(spell_name: String) -> void:
	if SpellData.SPELLS.has(spell_name) and _ledger().knows(spell_name) and not _page_of.has(spell_name):
		_page_of[spell_name] = _pages.size()
		_pages.append(_page_spell.bind(spell_name))  # every spell has a page to itself


func _add_chant_page(ritual_id: String) -> void:
	if RitualInput.RITUALS.has(ritual_id) and _ledger().knows_chant(ritual_id) and not _page_of.has("chant:" + ritual_id):
		_page_of["chant:" + ritual_id] = _pages.size()
		_pages.append(_page_incantation.bind(ritual_id))


## The ledger of the wizard whose book this is.
func _ledger() -> Ledger:
	return get_parent().player.ledger


## Takes in the pages that have been found since the book was last made.
func refresh() -> void:
	_build_pages()
	_spread = mini(_spread, ceili(_pages.size() / 2.0) - 1)
	_show_spread()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("book"):
		var lying := PagePickup.underfoot(get_tree()) if not visible else null
		if lying != null:
			_read(lying)
		else:
			_toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_right"):
		_turn(SHIFT_LEAVES if event.shift_pressed else 1)
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_left"):
		_turn(-SHIFT_LEAVES if event.shift_pressed else -1)
		get_viewport().set_input_as_handled()


## Reads a page lying on the ground into the book, and opens the book at it. A page the book has already is not taken: the book
## just opens at it.
func _read(lying: PagePickup) -> void:
	if lying.gives(_ledger()):
		get_parent().read_page(lying, get_parent().player)  # the arena reads it in, and opens the book at it (see show_page)
	else:
		show_page(lying.page)


## Opens the book at a page.
func show_page(page: String) -> void:
	_spread = int(_page_of.get(page, 0)) / 2
	_show_spread()
	if not visible:
		_toggle()


## Opens the book, which falls open before its writing shows, or shuts it.
func _toggle() -> void:
	if not visible:
		visible = true
		_set_writing(false)
		Sfx.play("book_open")
		_book.play([0, 1, 2, OPEN], _set_writing.bind(true))
	else:
		_set_writing(false)
		Sfx.play("book_close")
		_book.play([2, 1, 0], func() -> void: visible = false)


## Turns the leaves of the book: one at a time, or five with Shift held. The page flips in the direction it is turned.
func _turn(leaves: int) -> void:
	var direction := signi(leaves)
	var last_spread := ceili(_pages.size() / 2.0) - 1
	var turned := clampi(_spread + leaves, 0, last_spread)
	if turned == _spread:
		return
	Sfx.play("page")
	_spread = turned
	# The page flips over with the writing hidden, then the new pages show.
	_set_writing(false)
	_book.play([4, 5, 6, OPEN] if direction > 0 else [6, 5, 4, OPEN], func() -> void:
		_show_spread()
		_set_writing(true))


func _set_writing(on: bool) -> void:
	_left.get_parent().visible = on
	_right.get_parent().visible = on


## The open book sits in the middle of the screen; its frame has an empty margin round it, partly off screen.
func _centre_book() -> void:
	_book.position = (get_viewport().get_visible_rect().size * 0.5 - OPEN_MIDDLE * SCALE).floor()


## The writing area of one page. Anything too long is cut off at the page's edge, so a page never grows.
func _page_column(page: Rect2) -> VBoxContainer:
	var area := Control.new()
	area.position = page.position * SCALE
	area.size = page.size * SCALE
	area.clip_contents = true
	_book.add_child(area)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.size = area.size
	area.add_child(column)
	return column


## A number at the foot of a page, in the middle.
func _page_number(column: VBoxContainer) -> Label:
	var label := _ink("", 20, SUBTLE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(column.size.x, 30)
	label.position = Vector2(0, column.size.y - 56)
	column.get_parent().add_child(label)
	return label


func _show_spread() -> void:
	_use_face(_spread * 2)
	_fill(_left, _pages[_spread * 2])
	_use_face(_spread * 2 + 1)
	if _spread * 2 + 1 < _pages.size():
		_fill(_right, _pages[_spread * 2 + 1])
	else:
		_fill(_right, _page_blank)
	_left_number.text = str(_spread * 2 + 1)
	_right_number.text = str(_spread * 2 + 2) if _spread * 2 + 1 < _pages.size() else ""


## Sets the text and title faces for the page at this index.
func _use_face(page: int) -> void:
	var i := page % _faces.size()
	_text_font = _faces[i]
	_title_font = _title_faces[i]


func _fill(column: VBoxContainer, builder: Callable) -> void:
	for child in column.get_children():
		child.queue_free()
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.add_theme_constant_override("separation", 6)
	builder.call(column)


func _ink(text: String, size := 24, color := TEXT_INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_override("font", _text_font)
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label


## A label in the heading hand, for headings and names.
func _title_label(text: String, size: int, color := TEXT_INK) -> Label:
	var label := _ink(text, size, color)
	label.add_theme_font_override("font", _title_font)
	label.add_theme_font_size_override("font_size", Lettering.size_near(size))
	return label


## A heading in red ink, with a pixel rule under it.
func _heading(text: String, size := 44) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	block.add_child(_title_label(text, size, TEXT_INK))
	block.add_child(_rule(HEADING))
	return block


func _rule(colour := PAPER_DARK) -> ColorRect:
	var rule := ColorRect.new()
	rule.color = colour
	rule.custom_minimum_size = Vector2(0, SCALE * 0.6)
	return rule


## The mask of mouse buttons a school is cast with, found from its spells.
func _school_mask(school: String) -> int:
	for spell_name in SpellData.SPELLS:
		var s: Spell = SpellData.SPELLS[spell_name]
		if s.school == school:
			return s.buttons
	return 0


## A row showing a school's mouse with its buttons lit, next to the school's name.
func _school_row(school: String, mouse_scale := 1.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.add_child(MouseIcon.new(_school_mask(school), SpellData.SCHOOL_COLORS[school], mouse_scale))
	var name := _title_label(SpellData.school_name(school), 38, TEXT_INK)
	name.autowrap_mode = TextServer.AUTOWRAP_OFF  # a short name must keep its full width, or the row mis-centres
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name)
	return row


func _page_contents(column: VBoxContainer) -> void:
	# The cheat sheet: each school's mouse with the buttons that cast it lit, and the school's name. The rows share one
	# column, so the mice line up, and the whole sheet sits in the middle of the page, up and down and across.
	var sheet := VBoxContainer.new()
	sheet.add_theme_constant_override("separation", 12)
	sheet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for school in SCHOOLS:
		var row := _school_row(school, 1.5)
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		sheet.add_child(row)
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centre.add_child(sheet)
	column.add_child(centre)


## The names of a school's spells, in the order they are listed.
func _spells_of(school: String) -> Array:
	var names := []
	for spell_name in SpellData.SPELLS:
		if SpellData.SPELLS[spell_name].school == school:
			names.append(spell_name)
	return names


## A spell's own page: its name with its school's mouse, the shape drawn out large, what it costs, what it does, how to draw it.
func _page_spell(column: VBoxContainer, spell_name: String) -> void:
	var s: Spell = SpellData.SPELLS[spell_name]
	var school: String = s.school
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var heading := _heading(spell_name, 42)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	top.add_child(MouseIcon.new(_school_mask(school), SpellData.SCHOOL_COLORS[school]))
	column.add_child(top)
	if _is_new(spell_name):
		column.add_child(_new_badge())
	var gesture: String = s.preview if s.preview != "" else s.gesture
	var preview := StrokePreview.new(GestureTemplates.preview_points(gesture), GestureTemplates.preview_ground(gesture), 150.0)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(preview)
	column.add_child(_ink(s.effect, 22, TEXT_INK))
	_foot(column, [s.damage_line(), s.cost_line()])


## True for a spell or chant that this wizard has not cast yet this game (in the waiting room every page is known and nothing is marked).
func _is_new(page: String) -> bool:
	return not _ledger().everything and not _ledger().has_cast(page)


## The mark on the page of a spell that has not been cast yet this game: a gold star, and the word beside it.
func _new_badge() -> HBoxContainer:
	var badge := HBoxContainer.new()
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.add_theme_constant_override("separation", 8)
	badge.alignment = BoxContainer.ALIGNMENT_CENTER
	badge.add_child(_sparkle())
	var word := _ink("NEW!", 22, NEW_GOLD)
	word.autowrap_mode = TextServer.AUTOWRAP_OFF
	word.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	word.add_theme_color_override("font_outline_color", INK)
	word.add_theme_constant_override("outline_size", 5)
	badge.add_child(word)
	badge.add_child(_sparkle())
	return badge


## One of the little twinkles either side of NEW!.
static func _sparkle() -> TextureRect:
	var image := Image.create(SPARKLE_ROWS[0].length(), SPARKLE_ROWS.size(), false, Image.FORMAT_RGBA8)
	for y in SPARKLE_ROWS.size():
		for x in SPARKLE_ROWS[y].length():
			var key: String = SPARKLE_ROWS[y][x]
			if SPARKLE_COLORS.has(key):
				image.set_pixel(x, y, SPARKLE_COLORS[key])
	var twinkle := TextureRect.new()
	twinkle.texture = ImageTexture.create_from_image(image)
	twinkle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	twinkle.custom_minimum_size = Vector2(image.get_width(), image.get_height()) * SPARKLE_SCALE
	twinkle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	twinkle.stretch_mode = TextureRect.STRETCH_SCALE
	twinkle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return twinkle


## An incantation's own page: its name, its words and what it does. Every one is spoken by typing it and pressing Enter,
## which every page shows as a key, the way the spell pages show the mouse buttons.
func _page_incantation(column: VBoxContainer, ritual_id: String) -> void:
	var r: Dictionary = RitualInput.RITUALS[ritual_id]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var heading := _heading(r["name"], 40)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	top.add_child(KeyCap.new("Enter"))
	column.add_child(top)
	if _is_new("chant:" + ritual_id):
		column.add_child(_new_badge())
	column.add_child(_ink("“%s”" % r["text"], 26, TEXT_INK))
	column.add_child(_ink(ritual_effect(ritual_id), 20, TEXT_INK))
	_foot(column, [ritual_cost_line(ritual_id)])


## The figures of a page, always at its foot just above the page number, so a reader knows where to look: damage first, then cost.
## Lines that are empty are left out.
func _foot(column: VBoxContainer, lines: Array) -> void:
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(gap)
	for line: String in lines:
		if line != "":
			column.add_child(_ink(line, 20, SUBTLE if line == lines[lines.size() - 1] else TEXT_INK))
	var margin := Control.new()
	margin.custom_minimum_size = Vector2(0, 50)  # the room the page number takes
	column.add_child(margin)


static func ritual_effect(ritual_id: String) -> String:
	match ritual_id:
		"minimap":
			return "Reveal a map of the world."
		"insight":
			return "Gain deeper knowledge of those around you."
		"bonfire":
			return "Kindle a bonfire and heal your wounds."
		"boundless":
			return "Gain unlimited stamina for a short amount of time."
		"double_jump":
			return "Jump again in mid-air."
		"rift":
			return "Teleport to a random location. WARNING: this can be devastating."
		"haste":
			return "Run faster."
		"deep_breath":
			return "Hold your breath."
		"scrying_eye":
			return "Spy on another wizard."
		"dowsing":
			return "Show the way to the nearest page you have not read."
	return ""


func _page_blank(_column: VBoxContainer) -> void:
	pass


## What a chant costs, or nothing when it costs no stamina (most do not): a Rift wears down the most stamina you can have.
static func ritual_cost_line(ritual_id: String) -> String:
	return "35 max stamina" if ritual_id == "rift" else ""

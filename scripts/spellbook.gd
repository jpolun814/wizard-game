class_name Spellbook
extends CanvasLayer

## A pixel-art spellbook held up in front of you (Foxel Games' Pixel Art Book, drawn five times its size). Tab opens
## or closes it, and it falls open and shut; Left and Right turn the pages, which flip over. It doesn't pause
## anything, so you can keep casting and typing while you read. Buttons are drawn as a mouse with the held buttons lit
## up, and every spell's shape is drawn on the book's own pixel grid.

const INK := Color("#3a1d1a")
const HEADING := Color("#6e1420")
const SUBTLE := Color("#6b4434")
const PAPER_DARK := Color("#b88f72")
const SCALE := 5.0             # one pixel of the book is this many screen pixels
const FRAME := Vector2(190, 160)
const OPEN := 3                # the book's frames: 0 closed, 1-2 opening, 3 open, 4-6 a page turning over
const PAGES := [Rect2(24, 28, 62, 104), Rect2(94, 28, 62, 104)]  # where the writing goes, in book pixels
const FRAME_TIME := 0.06
const OPEN_MIDDLE := Vector2(90.5, 83.5)  # the middle of the open book in its frame

## The schools, in the order they appear in the book.
const SCHOOLS := ["Fire", "Ice", "Force", "Storm", "Earth"]
## How many incantations fit on one page. The rest run on to the facing page, so the book never grows.
const INCANTATIONS_PER_PAGE := 3

var _spread := 0
var _pages: Array[Callable] = []
var _book: BookArt
var _left: VBoxContainer
var _right: VBoxContainer
var _text_font: Font
var _title_font: Font


## The book itself, one frame of its sheet at a time. play() runs a list of frames, then calls back.
class BookArt extends Control:
	var frame := Spellbook.OPEN
	var _sheet: Texture2D = preload("res://art/ui/book.png")
	var _queue: Array = []
	var _clock := 0.0
	var _done: Callable

	func play(frames: Array, done: Callable) -> void:
		_queue = frames.duplicate()
		_done = done
		_clock = 0.0
		frame = _queue.pop_front()
		queue_redraw()

	func _process(delta: float) -> void:
		if _queue.is_empty():
			return
		_clock += delta
		if _clock >= Spellbook.FRAME_TIME:
			_clock = 0.0
			frame = _queue.pop_front()
			queue_redraw()
			if _queue.is_empty() and _done.is_valid():
				_done.call()

	func _draw() -> void:
		var source := Rect2(Vector2(frame * Spellbook.FRAME.x, 0), Spellbook.FRAME)
		draw_texture_rect_region(_sheet, Rect2(Vector2.ZERO, Spellbook.FRAME * Spellbook.SCALE), source)


## A mouse seen from above, drawn in the book's pixels: an outlined body split into two buttons and a wheel. The
## buttons in `mask` are lit, so the picture shows exactly which buttons a school needs.
class MouseIcon extends Control:
	var mask := 0
	var lit := Color.WHITE
	const SHAPE := [
		"..#####..",
		".#LL#RR#.",
		"#LLL#RRR#",
		"#LLLWRRR#",
		"#LLLWRRR#",
		"#LLL#RRR#",
		"#########",
		"#BBBBBBB#",
		"#BBBBBBB#",
		"#BBBBBBB#",
		".#BBBBB#.",
		"..#####..",
	]

	func _init(button_mask: int, lit_color: Color) -> void:
		mask = button_mask
		lit = lit_color
		custom_minimum_size = Vector2(9, 12) * Spellbook.SCALE * 0.6

	func _draw() -> void:
		var px := Spellbook.SCALE * 0.6
		var idle := Color("#e9d7bd")
		for y in SHAPE.size():
			var row: String = SHAPE[y]
			for x in row.length():
				var colour := Color.TRANSPARENT
				match row[x]:
					"#":
						colour = Spellbook.INK
					"L":
						colour = lit if mask & SpellData.LEFT else idle
					"R":
						colour = lit if mask & SpellData.RIGHT else idle
					"W":
						colour = lit if mask & SpellData.MIDDLE else Spellbook.SUBTLE
					"B":
						colour = idle
				if colour.a > 0.0:
					draw_rect(Rect2(Vector2(x, y) * px, Vector2(px, px)), colour)


## A gesture's shape on the book's pixel grid, scaled to fit its box: a dot where the stroke starts and an arrow
## where it ends. Spells that must start on the ground show a strip of hatched earth under the start.
class Preview extends Control:
	var points := PackedVector2Array()
	var ground := NAN
	const CELLS := 15  # the picture is this many pixels across

	func _init(pts: PackedVector2Array, ground_y := NAN) -> void:
		points = pts
		ground = ground_y
		custom_minimum_size = Vector2.ONE * CELLS * Spellbook.SCALE * 0.6

	func _draw() -> void:
		if points.size() < 2:
			return
		var px := Spellbook.SCALE * 0.6
		var low := points[0]
		var high := points[0]
		for p in points:
			low = low.min(p)
			high = high.max(p)
		var extent := maxf(maxf(high.x - low.x, high.y - low.y), 1.0)
		var middle := (low + high) * 0.5
		var to_cell := func(p: Vector2) -> Vector2:
			return ((p - middle) / extent * (CELLS - 3) + Vector2.ONE * CELLS * 0.5).floor()
		if not is_nan(ground):
			var gy: float = to_cell.call(Vector2(middle.x, ground)).y + 1.0
			for x in CELLS:
				draw_rect(Rect2(Vector2(x, gy) * px, Vector2(px, px)), Spellbook.SUBTLE)
				if x % 2 == 0:
					draw_rect(Rect2(Vector2(x, gy + 1.0) * px, Vector2(px, px)), Spellbook.PAPER_DARK)
		var filled := {}
		for i in points.size() - 1:
			var a: Vector2 = to_cell.call(points[i])
			var b: Vector2 = to_cell.call(points[i + 1])
			var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
			for k in steps + 1:
				filled[a.lerp(b, float(k) / steps).round()] = true
		for cell in filled:
			draw_rect(Rect2(cell * px, Vector2(px, px)), Spellbook.HEADING)
		var start: Vector2 = to_cell.call(points[0])
		draw_rect(Rect2((start - Vector2.ONE) * px, Vector2(px, px) * 3.0), Spellbook.INK)
		var tip: Vector2 = to_cell.call(points[points.size() - 1])
		var heading := (points[points.size() - 1] - points[maxi(0, points.size() - 4)]).normalized()
		for side in [-1.0, 1.0]:
			var barb := (tip - heading.rotated(side * 0.6) * 2.0).round()
			draw_rect(Rect2(barb * px, Vector2(px, px)), Spellbook.HEADING)
			draw_rect(Rect2(((tip + barb) * 0.5).round() * px, Vector2(px, px)), Spellbook.HEADING)


func _ready() -> void:
	visible = false
	layer = 5  # under the ritual typing box (layer 10), so the book never covers what you type

	_pages = [_page_contents]
	for school in SCHOOLS:
		_pages.append(_page_school.bind(school))
	var ritual_ids := RitualInput.RITUALS.keys()
	for first in range(0, ritual_ids.size(), INCANTATIONS_PER_PAGE):
		_pages.append(_page_incantations.bind(ritual_ids.slice(first, first + INCANTATIONS_PER_PAGE), first == 0))

	# Pixel faces to match the book: a blackletter for headings and spell names, a plain one for the rest.
	_title_font = _pixel_font("res://fonts/Jacquard24-Regular.ttf")
	_text_font = _pixel_font("res://fonts/Jersey15-Regular.ttf")

	var viewport_size := get_viewport().get_visible_rect().size
	_book = BookArt.new()
	_book.size = FRAME * SCALE
	# The open book sits in the middle of the screen; its frame has an empty margin round it, partly off screen.
	_book.position = (viewport_size * 0.5 - OPEN_MIDDLE * SCALE).floor()
	add_child(_book)
	_left = _page_column(PAGES[0])
	_right = _page_column(PAGES[1])

	_show_spread()


func _pixel_font(path: String) -> Font:
	var font: FontFile = load(path)
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	return font


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_TAB:
		_toggle()
		get_viewport().set_input_as_handled()
	elif visible and key.keycode == KEY_RIGHT:
		_turn(1)
		get_viewport().set_input_as_handled()
	elif visible and key.keycode == KEY_LEFT:
		_turn(-1)
		get_viewport().set_input_as_handled()


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


func _turn(direction: int) -> void:
	var last_spread := ceili(_pages.size() / 2.0) - 1
	var turned := clampi(_spread + direction, 0, last_spread)
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


func _show_spread() -> void:
	_fill(_left, _pages[_spread * 2])
	if _spread * 2 + 1 < _pages.size():
		_fill(_right, _pages[_spread * 2 + 1])
	else:
		_fill(_right, _page_blank)


func _fill(column: VBoxContainer, builder: Callable) -> void:
	for child in column.get_children():
		child.queue_free()
	builder.call(column)


func _ink(text: String, size := 20, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_override("font", _text_font)
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label


## A blackletter label for headings and names.
func _title_label(text: String, size: int, color := HEADING) -> Label:
	var label := _ink(text, size, color)
	label.add_theme_font_override("font", _title_font)
	return label


## A heading in red ink, with a pixel rule under it.
func _heading(text: String, size := 36) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	block.add_child(_title_label(text, size, HEADING))
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
		var s: Dictionary = SpellData.SPELLS[spell_name]
		if s["school"] == school:
			return s["buttons"]
	return 0


## A row showing a school's mouse with its buttons lit, next to the school's name.
func _school_row(school: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.add_child(MouseIcon.new(_school_mask(school), SpellData.SCHOOL_COLORS[school]))
	var name := _title_label(school, 32, HEADING)
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name)
	return row


func _page_contents(column: VBoxContainer) -> void:
	column.add_child(_heading("Spellbook", 44))
	for school in SCHOOLS:
		column.add_child(_school_row(school))
	column.add_child(_ink("Hold a school's buttons and draw its shape. Tab closes the book; the arrow keys turn the pages.", 18, SUBTLE))


func _page_school(column: VBoxContainer, school: String) -> void:
	# The school's name, with its mouse beside it.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var heading := _heading(school, 40)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	top.add_child(MouseIcon.new(_school_mask(school), SpellData.SCHOOL_COLORS[school]))
	column.add_child(top)
	for spell_name in SpellData.SPELLS:
		var s: Dictionary = SpellData.SPELLS[spell_name]
		if s["school"] == school:
			column.add_child(_spell_entry(spell_name, s))


## A spell is its name and its shape, with a small line of stats underneath.
func _spell_entry(spell_name: String, s: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var gesture: String = s.get("preview", s["gesture"])
	var preview := Preview.new(GestureTemplates.preview_points(gesture), GestureTemplates.preview_ground(gesture))
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(preview)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", -4)
	text.add_child(_title_label(spell_name, 30, HEADING))
	text.add_child(_ink("%d stamina · %s" % [roundi(s["cost"]), SpellData.DAMAGE[spell_name]], 18, SUBTLE))
	row.add_child(text)
	return row


## A page of incantations: each one's name, its words, and what it does. Every one is spoken by typing it and
## pressing Enter, which the first page says once.
func _page_incantations(column: VBoxContainer, ritual_ids: Array, first: bool) -> void:
	if first:
		column.add_child(_heading("Incantations", 40))
		column.add_child(_ink("Press Enter, type the words, press Enter.", 18, SUBTLE))
	for ritual_id in ritual_ids:
		var r: Dictionary = RitualInput.RITUALS[ritual_id]
		column.add_child(_title_label(r["name"], 28, HEADING))
		column.add_child(_ink("“%s”" % r["text"], 20, INK))
		column.add_child(_ink(_ritual_effect(ritual_id), 18, SUBTLE))


func _ritual_effect(ritual_id: String) -> String:
	match ritual_id:
		"second_wind":
			return "Heals you; a truer chant heals more."
		"minimap":
			return "Shows or hides the minimap."
		"insight":
			return "Hover a foe to see its health and weaknesses."
		"bonfire":
			return "A healing bonfire for 15 seconds."
		"boundless":
			return "Endless stamina for 15 seconds."
	return ""


func _page_blank(_column: VBoxContainer) -> void:
	pass

class_name Spellbook
extends CanvasLayer

## A pixel-art spellbook held up in front of you (Foxel Games' Pixel Art Book, drawn five times its size). Tab opens
## or closes it, and it falls open and shut; Left and Right turn the pages, which flip over. It doesn't pause
## anything, so you can keep casting and typing while you read. Buttons are drawn as a mouse with the held buttons lit
## up, and every spell's shape is drawn on the book's own pixel grid.

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
const SCHOOLS := ["Fire", "Water", "Air", "Earth", "Flora", "Shadow"]

var _spread := 0
var _pages: Array[Callable] = []
var _book: BookArt
var _left: VBoxContainer
var _right: VBoxContainer
var _text_font: Font
var _title_font: Font
var _faces: Array[Font] = []
var _title_faces: Array[Font] = []
const FACE_FILES := ["res://fonts/PirataOne-Regular.ttf"]  # the face the book is written in
var _left_number: Label  # the page numbers, at the foot of each page
var _right_number: Label


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

	var mouse_scale := 1.0

	func _init(button_mask: int, lit_color: Color, size_up := 1.0) -> void:
		mask = button_mask
		lit = lit_color
		mouse_scale = size_up
		custom_minimum_size = Vector2(9, 12) * Spellbook.SCALE * 0.6 * size_up

	func _draw() -> void:
		var px := Spellbook.SCALE * 0.6 * mouse_scale
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
						colour = lit if mask & SpellData.MIDDLE else Color("#b9a27c")
					"B":
						colour = idle
				if colour.a > 0.0:
					draw_rect(Rect2(Vector2(x, y) * px, Vector2(px, px)), colour)


## A gesture's shape, drawn as a hand would ink it: a smooth stroke with a fine second line beside it, an arrowhead
## on the tip of the ink as it is drawn, a dot where it starts. A spell that must start on the ground has a hatched line of earth under it.
class Preview extends Control:
	var points := PackedVector2Array()
	var ground := NAN

	func _init(pts: PackedVector2Array, ground_y := NAN, side := 48.0) -> void:
		points = pts
		ground = ground_y
		custom_minimum_size = Vector2.ONE * side

	# The stroke is drawn out again and again, as if the wizard were casting it: it traces itself, then rests with its arrow.
	var _clock := 0.0

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	## The first share of a stroke, measured along its length, so the pen moves at an even speed however few or
	## unevenly spaced its points are.
	func _traced(path: PackedVector2Array, share: float) -> PackedVector2Array:
		var total := 0.0
		for i in path.size() - 1:
			total += path[i].distance_to(path[i + 1])
		var left := total * share
		var out := PackedVector2Array([path[0]])
		for i in path.size() - 1:
			var step := path[i].distance_to(path[i + 1])
			if step >= left:
				out.append(path[i].lerp(path[i + 1], left / maxf(step, 0.001)))
				return out
			out.append(path[i + 1])
			left -= step
		return out

	func _draw() -> void:
		if points.size() < 2:
			return
		var bounds := GestureTemplates.bounds(points)
		var extent := maxf(maxf(bounds.size.x, bounds.size.y), 1.0)
		var middle := bounds.get_center()
		var box := size.x
		var scale_to := (box - 14.0) / extent
		var to_pic := func(p: Vector2) -> Vector2:
			return (p - middle) * scale_to + Vector2.ONE * box * 0.5
		var drawn := PackedVector2Array()
		for p in points:
			drawn.append(to_pic.call(p))
		if not is_nan(ground):
			var gy: float = to_pic.call(Vector2(middle.x, ground)).y + 3.0
			draw_line(Vector2(6.0, gy), Vector2(box - 6.0, gy), Spellbook.SUBTLE, 1.5, true)
			for x in range(10, int(box) - 6, 6):
				draw_line(Vector2(x, gy), Vector2(x - 4.0, gy + 5.0), Spellbook.PAPER_DARK, 1.0, true)
		# The ink: a soft wash underneath, then the line itself and a fainter second pass for a hand-drawn edge.
		var length := 0.0
		for i in drawn.size() - 1:
			length += drawn[i].distance_to(drawn[i + 1])
		var duration := clampf(length / 260.0, 0.3, 1.5)  # a short, simple stroke is drawn quickly, a long one slowly
		var shown := clampf(fmod(_clock, duration + 0.8) / duration, 0.0, 1.0)  # it traces itself, then rests
		var traced := _traced(drawn, shown)
		draw_polyline(traced, Color(Spellbook.INK, 0.18), 5.0, true)
		draw_polyline(traced, Spellbook.INK, 2.2, true)
		var offset := PackedVector2Array()
		for p in traced:
			offset.append(p + Vector2(0.8, -0.6))
		draw_polyline(offset, Color(Spellbook.HEADING, 0.55), 1.0, true)
		draw_circle(drawn[0], 3.0, Spellbook.INK)
		# The arrowhead rides the pen: it sits on the tip of the ink the whole time and points the way the pen is travelling
		# there (along the last stretch drawn), so it stays right on loops and spirals too.
		var tip := traced[traced.size() - 1]
		var back := traced[0]
		var walked := 0.0
		for i in range(traced.size() - 1, 0, -1):
			walked += traced[i].distance_to(traced[i - 1])
			back = traced[i - 1]
			if walked >= 14.0:
				break
		var heading := (tip - back).normalized()
		if walked >= 3.0:
			var base := tip - heading * 7.0
			draw_line(tip, base + heading.orthogonal() * 3.5, Spellbook.INK, 2.2, true)
			draw_line(tip, base - heading.orthogonal() * 3.5, Spellbook.INK, 2.2, true)


func _ready() -> void:
	visible = false
	layer = 5  # under the ritual typing box (layer 10), so the book never covers what you type

	_build_pages()

	# Each page is set in one of the candidate hands, in turn, so the pages can be compared as the book is turned.
	for path in FACE_FILES:
		var face: Font = load(path)
		var heavy := FontVariation.new()
		heavy.base_font = face
		heavy.variation_embolden = 0.5  # titles are pressed a little harder than the text
		_faces.append(face)
		_title_faces.append(heavy)

	var viewport_size := get_viewport().get_visible_rect().size
	_book = BookArt.new()
	_book.size = FRAME * SCALE
	# The open book sits in the middle of the screen; its frame has an empty margin round it, partly off screen.
	_book.position = (viewport_size * 0.5 - OPEN_MIDDLE * SCALE).floor()
	add_child(_book)
	_left = _page_column(PAGES[0])
	_right = _page_column(PAGES[1])
	_use_face(0)
	_left_number = _page_number(_left)
	_right_number = _page_number(_right)

	_show_spread()


## The pages of the book: the cheat sheet, then a page to each spell and chant that is known.
func _build_pages() -> void:
	_pages = [_page_contents]
	for school in SCHOOLS:
		for spell_name in _spells_of(school):
			if Pages.knows(spell_name):
				_pages.append(_page_spell.bind(spell_name))  # every spell has a page to itself
	for ritual_id in RitualInput.RITUALS:
		if ritual_id != "recall" and Pages.knows_chant(ritual_id):  # the Return shares the Mark's page: the two work as a pair
			_pages.append(_page_incantation.bind(ritual_id))


## Takes in the pages that have been found since the book was last made.
func refresh() -> void:
	_build_pages()
	_spread = mini(_spread, ceili(_pages.size() / 2.0) - 1)
	_show_spread()


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
		var s: Dictionary = SpellData.SPELLS[spell_name]
		if s["school"] == school:
			return s["buttons"]
	return 0


## A row showing a school's mouse with its buttons lit, next to the school's name.
func _school_row(school: String, mouse_scale := 1.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.add_child(MouseIcon.new(_school_mask(school), SpellData.SCHOOL_COLORS[school], mouse_scale))
	var name := _title_label(school, 38, TEXT_INK)
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
		if SpellData.SPELLS[spell_name]["school"] == school:
			names.append(spell_name)
	return names


## A spell's own page: its name with its school's mouse, the shape drawn out large, what it costs, what it does, how to draw it.
func _page_spell(column: VBoxContainer, spell_name: String) -> void:
	var s: Dictionary = SpellData.SPELLS[spell_name]
	var school: String = s["school"]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var heading := _heading(spell_name, 42)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	top.add_child(MouseIcon.new(_school_mask(school), SpellData.SCHOOL_COLORS[school]))
	column.add_child(top)
	var gesture: String = s.get("preview", s["gesture"])
	var preview := Preview.new(GestureTemplates.preview_points(gesture), GestureTemplates.preview_ground(gesture), 150.0)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(preview)
	column.add_child(_ink("%d stamina" % roundi(s["cost"]), 20, SUBTLE))
	column.add_child(_ink(s["effect"], 22, TEXT_INK))


## An incantation's own page: its name, its words and what it does. Every one is spoken by typing it and pressing Enter,
## which the first page says once.
func _page_incantation(column: VBoxContainer, ritual_id: String) -> void:
	var r: Dictionary = RitualInput.RITUALS[ritual_id]
	column.add_child(_heading(r["name"], 40))
	if ritual_id == RitualInput.RITUALS.keys()[0]:
		column.add_child(_ink("Press Enter, type the words, press Enter.", 18, SUBTLE))
	column.add_child(_ink("“%s”" % r["text"], 26, TEXT_INK))
	column.add_child(_ink(_ritual_effect(ritual_id), 20, SUBTLE))
	if ritual_id == "mark":
		var back: Dictionary = RitualInput.RITUALS["recall"]
		column.add_child(_heading(back["name"], 32))
		column.add_child(_ink("“%s”" % back["text"], 26, TEXT_INK))
		column.add_child(_ink(_ritual_effect("recall"), 20, SUBTLE))


func _ritual_effect(ritual_id: String) -> String:
	match ritual_id:
		"minimap":
			return "Shows or hides the minimap."
		"insight":
			return "Hover over a foe to see information about it."
		"bonfire":
			return "Lights a bonfire for 30 seconds that restores your lost maximum stamina."
		"boundless":
			return "Gives you endless stamina for 20 seconds."
		"double_jump":
			return "Lets you jump once more in mid-air for 20 seconds."
		"rift":
			return "Teleports you to a random place on the map. Costs all your stamina and lowers your maximum by 50."
		"haste":
			return "Move faster for 20 seconds."
		"deep_breath":
			return "Hold your breath for 45 seconds."
		"mark":
			return "Mark the place you stand."
		"recall":
			return "Open a portal at your mark and another where you stand. Anyone can use them."
	return ""


func _page_blank(_column: VBoxContainer) -> void:
	pass

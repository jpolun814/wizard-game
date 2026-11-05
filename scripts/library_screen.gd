class_name LibraryScreen
extends Control

## The library: what this machine remembers of the matches played on it (see Library), kept as a shelf of tomes, one for each school and one of
## incantations. A tome opens as the spellbook does: a page to each spell with its shape drawn out, and in the margin how often it was found, cast
## and won with, and how truly it is drawn. A page never found or cast is left blank with a torn corner, so the shelf does not give away what
## there is to find. Ribbons along the edge of an open tome choose which kind of world the counts are of.

const MENU := "res://scenes/menu.tscn"
const PAGE_COLOUR := Color("#ffe9a0")
const DIM := Color(0.62, 0.58, 0.72)
const JERSEY := preload("res://fonts/Jersey15-Regular.ttf")
const WORLDS := ["graveyard", "mountains", "jungle", "ashlands", "castle", "underground", "portals"]
const CHANTS := "chants"
const CHRONICLE := "chronicle"
const ART := "res://art/ui/library/"
const LEAN := 10.0                      # how far a leaning book is tilted, in degrees
const CASE_ART := Vector2(420.0, 216.0)  # the bookcase picture, in art pixels
const PIXEL := 3.0                     # one art pixel is this many screen pixels
const TOME_ART := Vector2(24.0, 60.0)  # a tome's spine in art pixels
const RIBBON_SIZE := Vector2(132.0, 44.0)

var _data: Dictionary
var _world := ""              # the kind of world the counts are of, or "" for every kind
var _tome := ""               # the tome being read: a school, CHANTS, or "" when none is open
var _spread := 0
var _shelf: Control
var _reading: Control         # the open book with its ribbons and arrows
var _book: Spellbook.BookArt
var _writing: Control         # both pages, hidden while the book falls open or a leaf turns
var _areas: Array[Control] = []
var _numbers: Array[Label] = []
var _ribbons: Control
var _back: Button


## A page with nothing on it yet: a faint hatching and a torn corner.
class Torn extends Control:
	func _draw() -> void:
		for k in 5:
			var y := size.y * (0.2 + 0.12 * k)
			draw_line(Vector2(size.x * 0.12, y), Vector2(size.x * 0.88, y), Color(Spellbook.PAPER_DARK, 0.28), 2.0)
		var corner := PackedVector2Array([Vector2(size.x, size.y - 150.0), Vector2(size.x - 120.0, size.y - 60.0), Vector2(size.x - 60.0, size.y - 40.0), Vector2(size.x, size.y)])
		draw_colored_polygon(corner, Color(Spellbook.PAPER_DARK, 0.35))


## The damage dealt and taken through a match, drawn as two inked lines. The match is cut into the worlds it went through, each named across its stretch.
class Trace extends Control:
	var dealt: Array
	var taken: Array
	var sections: Array  # [name, where it begins as a share of the match]

	func _init(dealt_line: Array, taken_line: Array, stretches: Array) -> void:
		dealt = dealt_line
		taken = taken_line
		sections = stretches
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var band := 20.0  # the strip along the top that carries the names of the worlds
		for k in sections.size():
			var from_x: float = size.x * float(sections[k][1])
			var to_x: float = size.x * float(sections[k + 1][1]) if k + 1 < sections.size() else size.x
			if k % 2 == 0:
				draw_rect(Rect2(from_x, 0.0, to_x - from_x, size.y - 2.0), Color(Spellbook.PAPER_DARK, 0.3))
			if k > 0:
				draw_line(Vector2(from_x, 0.0), Vector2(from_x, size.y - 2.0), Color(Spellbook.SUBTLE, 0.7), 2.0)
			var name: String = sections[k][0]
			var font: Font = LibraryScreen.JERSEY
			if font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17).x + 8.0 <= to_x - from_x:
				draw_string(font, Vector2(from_x + 4.0, 15.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Spellbook.TEXT_INK)
		draw_line(Vector2(0.0, size.y - 1.0), Vector2(size.x, size.y - 1.0), Color(Spellbook.PAPER_DARK, 0.7), 2.0)
		var top := 1.0
		for v: int in dealt + taken:
			top = maxf(top, float(v))
		var low := (band if not sections.is_empty() else 2.0)
		for pair in [[taken, Spellbook.SUBTLE], [dealt, Spellbook.HEADING]]:
			var line: Array = pair[0]
			if line.size() < 2:
				continue
			var points := PackedVector2Array()
			for k in line.size():
				points.append(Vector2(size.x * k / (line.size() - 1.0), low + (size.y - low - 4.0) * (1.0 - float(line[k]) / top)))
			draw_polyline(points, pair[1], 2.0, true)


func _ready() -> void:
	var dark := ColorRect.new()
	dark.color = Color(0.03, 0.01, 0.05, 1.0)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dark)
	_build_shelf()
	_build_reading()
	_back = Button.new()
	_back.text = "Back"
	_back.theme_type_variation = &"Back"
	_back.custom_minimum_size = Vector2(150.0, 0.0)
	_back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_back.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_back.offset_left = 20.0
	_back.offset_bottom = -16.0
	_back.pressed.connect(_on_back)
	add_child(_back)
	_back.grab_focus.call_deferred()
	_refresh()


func _input(event: InputEvent) -> void:
	if _tome == "":
		return
	if event.is_action_pressed("ui_right"):
		_turn(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_turn(-1)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_on_back()


## Back shuts the tome that is open; with none open it leaves for the first screen.
func _on_back() -> void:
	Sfx.play("ui_click")
	if _tome != "":
		close_tome()
	else:
		get_tree().change_scene_to_file(MENU)


# ---- the ledger ----

## Reads the counts again from the world now chosen, and writes the open pages out again from them.
func _refresh() -> void:
	_data = Library.stats_for(_world)
	if _tome != "":
		_spread = mini(_spread, ceili(_pages_of(_tome).size() / 2.0) - 1)  # a filter can leave fewer pages
		_show_spread()


## The first page of the Chronicle: what was played and won on this machine, and how much of the book is known, written as lines of a ledger.
func _write_summary(area: Control) -> void:
	var known := 0
	var every := Pages.every()
	for page in every:
		if _known(page):
			known += 1
	var figures: Array = []
	if _world == "":
		figures = [["Matches played", str(int(_data["matches"]))], ["Matches won", str(int(_data["wins"]))]]
	else:
		figures = [["Matches played here", str(int(_data["worlds"]))], ["Matches won here", str(int(_data["wins"]))]]
	figures.append(["Pages known", "%d of %d" % [known, every.size()]])
	if _world == "":
		figures.append(["Title", Library.title()])
	var told := Library.history(_world)
	if not told.is_empty():
		var time := 0
		var kills := 0
		var best := 99
		for match_told: Dictionary in told:
			time += int(match_told.get("seconds", 0))
			kills += int(match_told.get("kills", 0))
			best = mini(best, int(match_told.get("place", 99)))
		figures.append(["Time played", _clock(time)])
		figures.append(["Kills", str(kills)])
		figures.append(["Best placing", _ordinal(best)])
	var column := VBoxContainer.new()
	column.size = area.size
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(column)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 0)
	heading.add_child(_ink("Chronicle", Lettering.size_near(44), Spellbook.TEXT_INK, true))
	var rule := ColorRect.new()
	rule.color = Spellbook.HEADING
	rule.custom_minimum_size = Vector2(0.0, Spellbook.SCALE * 0.6)
	heading.add_child(rule)
	column.add_child(heading)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 24.0)
	column.add_child(gap)
	for entry in figures:
		var row := HBoxContainer.new()
		row.add_child(_ink(entry[0], 24, Spellbook.SUBTLE))
		var value := _ink(entry[1], 28, Spellbook.HEADING)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		column.add_child(row)


## True when a page has been found or its spell cast at least once, in any kind of world.
func _known(page: String) -> bool:
	if page.begins_with("chronicle:"):
		return true
	var overall := Library.stats_for("")
	return overall["pages"].has(page) or overall["casts"].has(page) or overall["won_with"].has(page)


# ---- the shelf ----

func _tomes() -> Array[String]:
	var out: Array[String] = []
	out.append_array(Spellbook.SCHOOLS)
	out.append(CHANTS)
	out.append(CHRONICLE)
	return out


## A tome's pages: those found, in their order, then the blank ones.
func _pages_of(tome: String) -> Array[String]:
	var all := _pages_in_order(tome)
	var out: Array[String] = all.filter(func(p: String) -> bool: return _known(p))
	out.append_array(all.filter(func(p: String) -> bool: return not _known(p)))
	return out


func _pages_in_order(tome: String) -> Array[String]:
	var out: Array[String] = []
	if tome == CHRONICLE:
		out.append("chronicle:summary")
		for k in Library.history(_world).size():
			out.append("chronicle:match:%d" % k)  # newest first
		return out
	if tome == CHANTS:
		for page in Pages.every():
			if page.begins_with("chant:"):
				out.append(page)
	else:
		for spell_name: String in SpellData.SPELLS:
			if SpellData.SPELLS[spell_name].school == tome:
				out.append(spell_name)
	return out


func _tome_name(tome: String) -> String:
	if tome == CHRONICLE:
		return "Chronicle"
	return "Incantations" if tome == CHANTS else SpellData.school_name(tome)


## The bookcase, drawn in pixels (tools/make_library_art.py) and scaled up whole. Books of no name stand among the named tomes, and the books do
## not all stand in one line: they lean, lie in stacks and differ in height. A named tome is a button that is drawn a little way out when pointed at.
func _build_shelf() -> void:
	_shelf = Control.new()
	_shelf.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shelf)
	# The case with the named tomes stands in the middle of the screen, and more cases continue on either side as far as the screen goes, whatever
	# its width, filled with books that cannot be taken down.
	var case_width := CASE_ART.x * PIXEL
	var middle := (get_viewport_rect().size.x - case_width) * 0.5
	var beyond := ceili(maxf(middle, 0.0) / case_width)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in range(-beyond, beyond + 1):
		var origin := Vector2(middle + k * case_width, 20.0)
		var case := TextureRect.new()
		case.texture = load(ART + "bookcase.png")
		case.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		case.stretch_mode = TextureRect.STRETCH_SCALE
		case.size = CASE_ART * PIXEL
		case.position = origin
		case.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shelf.add_child(case)
		_fill_case(origin, _rows_of_case(k), rng)


## What stands on each board of a case: "f" a book of no name, "s0".."s2" a stack lying flat, "l" a book leaning (the next must be a tall tome
## to lean on), or the name of a tome. The middle case has the tomes; the others have only books of no name.
func _rows_of_case(k: int) -> Array:
	if k == 0:
		return [
			["f", "f", "Fire", "Water", "f", "f", "Air", "f", "l", "chronicle", "f", "f"],
			["s0", "f", "f", "Earth", "f", "Flora", "f", "f", "Shadow", "f", "f"],
			["f", "f", "l", "Blood", "f", "f", chants_row(), "f", "s1", "f", "f"],
		]
	var stacks := ["s2", "s0", "s1"]
	var gap_row := posmod(k, 3)
	var rows := [[], [], []]
	rows[gap_row] = ["f", stacks[posmod(k, 3)]]
	return rows


func _fill_case(origin: Vector2, rows: Array, rng: RandomNumberGenerator) -> void:
	var board_tops := [70.0, 138.0, 206.0]
	for r in rows.size():
		var x := 14.0
		for item: String in rows[r]:
			var spot := Vector2(x, board_tops[r])
			x += _stand(item, spot, origin, rng) + rng.randf_range(0.0, 2.0)
		while x < 396.0:  # the rest of the board is filled with more books, with a gap now and then
			x += 5.0 if rng.randf() < 0.15 else 0.0
			x += _stand("f", Vector2(x, board_tops[r]), origin, rng) + rng.randf_range(0.0, 2.0)


func chants_row() -> String:
	return CHANTS


## Puts one thing on a board and says how many art pixels of the board it took.
func _stand(item: String, foot: Vector2, origin: Vector2, rng: RandomNumberGenerator) -> float:
	if item.begins_with("s"):
		var stack := _picture("stack_%s.png" % item.trim_prefix("s"))
		stack.position = origin + (foot - Vector2(0.0, stack.texture.get_height())) * PIXEL
		_shelf.add_child(stack)
		return stack.texture.get_width() + 2.0
	if item == "f" or item == "l":
		var book := _picture("filler_%d.png" % rng.randi_range(0, 13))
		var h := float(book.texture.get_height())
		var w := float(book.texture.get_width())
		book.position = origin + (foot - Vector2(0.0, h)) * PIXEL
		if item == "l":  # leaning on its neighbour: it turns about its foot
			book.pivot_offset = Vector2(w * PIXEL, h * PIXEL)  # it rests on its lower right corner, its top against the tome beside it
			book.rotation_degrees = LEAN
		_shelf.add_child(book)
		return w + (h * sin(deg_to_rad(LEAN)) if item == "l" else 0.0)
	var tome := _make_tome(item, origin + (foot - Vector2(0.0, TOME_ART.y)) * PIXEL)
	_shelf.add_child(tome)
	return TOME_ART.x


func _picture(file: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(ART + file)
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = rect.texture.get_size() * PIXEL
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## A named tome standing on a board: its spine, its name running down it, and a click that takes it down to read.
func _make_tome(tome: String, at: Vector2) -> Button:
	var button := Button.new()
	button.name = "Tome_" + tome
	button.position = at
	button.size = TOME_ART * PIXEL
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var pages := _pages_of(tome)
	var found := pages.filter(func(p: String) -> bool: return _known(p)).size()
	button.tooltip_text = _tome_name(tome) if tome == CHRONICLE else "%s: %d of %d" % [_tome_name(tome), found, pages.size()]
	var spine := _picture("tome_%s.png" % tome)
	button.add_child(spine)
	# The name runs down the spine, top to bottom, in the panel between the gold rings.
	var panel_top := 10.0 * PIXEL
	var panel_length := (TOME_ART.y - 20.0) * PIXEL
	var name_label := _ink(_tome_name(tome), 22, Color("#f0d282"), true)
	name_label.size = Vector2(panel_length, 26.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.rotation_degrees = 90.0
	name_label.position = Vector2(TOME_ART.x * PIXEL * 0.5 + 13.0, panel_top)
	button.add_child(name_label)
	button.pressed.connect(open_tome.bind(tome))
	button.mouse_entered.connect(func() -> void: create_tween().tween_property(button, "position:y", at.y - 18.0, 0.1))
	button.mouse_exited.connect(func() -> void: create_tween().tween_property(button, "position:y", at.y, 0.1))
	return button


func _school_mask(school: String) -> int:
	for spell_name in SpellData.SPELLS:
		var s: Spell = SpellData.SPELLS[spell_name]
		if s.school == school:
			return s.buttons
	return 0


# ---- the open tome ----

func _build_reading() -> void:
	_reading = Control.new()
	_reading.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reading.visible = false
	add_child(_reading)
	_book = Spellbook.BookArt.new()
	_book.size = Spellbook.FRAME * Spellbook.SCALE
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.position = (get_viewport_rect().size * 0.5 - Spellbook.OPEN_MIDDLE * Spellbook.SCALE).floor()
	_reading.add_child(_book)
	_writing = Control.new()
	_writing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(_writing)
	for rect: Rect2 in Spellbook.PAGES:
		var area := Control.new()
		area.position = rect.position * Spellbook.SCALE
		area.size = rect.size * Spellbook.SCALE
		area.clip_contents = true
		area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_writing.add_child(area)
		_areas.append(area)
		var number := _ink("", 20, Spellbook.SUBTLE)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.position = Vector2(0.0, area.size.y - 40.0)
		number.size = Vector2(area.size.x, 30.0)
		area.add_child(number)
		_numbers.append(number)
	_ribbons = Control.new()
	_ribbons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reading.add_child(_ribbons)
	var options: Array = [["", "All"]] + WORLDS.map(func(b: String) -> Array: return [b, str(SurfaceGen.LOOKS[b]["title"]).trim_prefix("The ")])
	var edge := _book.position.x + 845.0
	for k in options.size():
		_ribbons.add_child(_make_ribbon(options[k][0], options[k][1], Vector2(edge, 110.0 + k * (RIBBON_SIZE.y + 8.0))))
	for side in [-1, 1]:
		var arrow := Button.new()
		arrow.text = "<" if side < 0 else ">"
		arrow.flat = true
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		arrow.add_theme_font_override("font", JERSEY)
		arrow.add_theme_font_size_override("font_size", 40)
		arrow.add_theme_color_override("font_color", PAGE_COLOUR)
		arrow.add_theme_color_override("font_hover_color", Color.WHITE)
		arrow.size = Vector2(44.0, 44.0)
		var page: Rect2 = Spellbook.PAGES[0 if side < 0 else 1]
		var middle := _book.position.x + (page.position.x + page.size.x * 0.5) * Spellbook.SCALE
		arrow.position = Vector2(middle + (-80.0 if side < 0 else 36.0), _book.position.y + page.end.y * Spellbook.SCALE - 54.0)
		arrow.pressed.connect(_turn.bind(side))
		_reading.add_child(arrow)


func _make_ribbon(value: String, words: String, at: Vector2) -> Button:
	var ribbon := Button.new()
	ribbon.text = words
	ribbon.name = "Ribbon_" + (value if value != "" else "all")
	ribbon.position = at
	ribbon.size = RIBBON_SIZE
	ribbon.focus_mode = Control.FOCUS_NONE
	ribbon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ribbon.add_theme_font_override("font", JERSEY)
	ribbon.add_theme_font_size_override("font_size", 22)
	ribbon.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	ribbon.add_theme_color_override("font_hover_color", Color.WHITE)
	for state in ["normal", "hover", "pressed"]:
		var cloth := StyleBoxFlat.new()
		cloth.bg_color = Color("#6e1420") if state == "normal" else Color("#8c1c2a")
		cloth.border_color = Color("#2a0a10")
		cloth.border_width_bottom = 3
		cloth.border_width_right = 3
		cloth.set_corner_radius_all(2)
		ribbon.add_theme_stylebox_override(state, cloth)
	ribbon.pressed.connect(func() -> void:
		Sfx.play("ui_click", null, -8.0)
		_world = value
		_refresh()
		_lift_ribbons())
	return ribbon


## The ribbon of the world chosen sticks further out of the book than the others.
func _lift_ribbons() -> void:
	var chosen := "Ribbon_" + (_world if _world != "" else "all")
	var edge := _book.position.x + 845.0
	for ribbon: Button in _ribbons.get_children():
		ribbon.position.x = edge + (22.0 if ribbon.name == chosen else 0.0)


## Takes a tome down from the shelf and opens it at its first page.
func open_tome(tome: String) -> void:
	Sfx.play("book_open")
	_tome = tome
	_spread = 0
	_shelf.visible = false
	_reading.visible = true
	_lift_ribbons()
	_writing.visible = false
	_show_spread()
	_book.play([0, 1, 2, Spellbook.OPEN], func() -> void: _writing.visible = true)


## Puts the tome back on the shelf.
func close_tome() -> void:
	Sfx.play("book_close")
	_tome = ""
	_reading.visible = false
	_shelf.visible = true


func _turn(by: int) -> void:
	if _tome == "":
		return
	var last := ceili(_pages_of(_tome).size() / 2.0) - 1
	var turned := clampi(_spread + by, 0, last)
	if turned == _spread:
		return
	Sfx.play("page")
	_spread = turned
	_writing.visible = false
	_book.play([4, 5, 6, Spellbook.OPEN] if by > 0 else [6, 5, 4, Spellbook.OPEN], func() -> void:
		_show_spread()
		_writing.visible = true)


func _show_spread() -> void:
	var pages := _pages_of(_tome)
	for side in 2:
		var area := _areas[side]
		for child in area.get_children():
			if child != _numbers[side]:
				child.queue_free()
		var index := _spread * 2 + side
		_numbers[side].text = str(index + 1) if index < pages.size() else ""
		if index < pages.size():
			_write_page(area, pages[index])


## One page of the tome: its name, its drawing and what it says if it is known, with the counts in the margin; blank and torn if not.
func _write_page(area: Control, page: String) -> void:
	if page == "chronicle:summary":
		_write_summary(area)
		return
	if page.begins_with("chronicle:match:"):
		_write_match(area, int(page.get_slice(":", 2)))
		return
	if not _known(page):
		var blank := Torn.new()
		blank.size = area.size
		blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area.add_child(blank)
		return
	var column := VBoxContainer.new()
	column.size = area.size
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(column)
	var chant := page.begins_with("chant:")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 0)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := _ink(Pages.title_of(page), Lettering.size_near(38), Spellbook.TEXT_INK, true, true)
	heading.add_child(name_label)
	var rule := ColorRect.new()
	rule.color = Spellbook.HEADING
	rule.custom_minimum_size = Vector2(0.0, Spellbook.SCALE * 0.6)
	heading.add_child(rule)
	top.add_child(heading)
	if not chant:
		var spell: Spell = SpellData.SPELLS[page]
		top.add_child(Spellbook.MouseIcon.new(spell.buttons, SpellData.SCHOOL_COLORS[spell.school]))
	else:
		top.add_child(Spellbook.KeyCap.new("Enter"))
	column.add_child(top)
	if chant:
		var id := page.trim_prefix("chant:")
		column.add_child(_ink("“%s”" % RitualInput.RITUALS[id]["text"], 26, Spellbook.TEXT_INK, false, true))
		column.add_child(_ink(Spellbook.ritual_effect(id), 20, Spellbook.SUBTLE, false, true))
	else:
		var spell: Spell = SpellData.SPELLS[page]
		var gesture: String = spell.preview if spell.preview != "" else spell.gesture
		var picture := Spellbook.Preview.new(GestureTemplates.preview_points(gesture), GestureTemplates.preview_ground(gesture), 140.0)
		picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(picture)
		column.add_child(_ink(spell.effect, 22, Spellbook.TEXT_INK, false, true))
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(gap)
	var rows := [["Found", "pages"], ["Cast", "casts"], ["Won with", "won_with"]]
	if not chant:
		rows.append(["Accuracy", "accuracy"])
	for entry in rows:
		var row := HBoxContainer.new()
		row.add_child(_ink(entry[0], 20, Spellbook.SUBTLE))
		var count := _ink(_figure(page, entry[1]), 22, Spellbook.HEADING)
		count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(count)
		column.add_child(row)
	var foot := Control.new()  # room above the page number
	foot.custom_minimum_size = Vector2(0.0, 40.0)
	column.add_child(foot)


## One match of the Chronicle: how it ended, when, where it went and what was done, with the damage dealt and taken drawn out over its length.
func _write_match(area: Control, index: int) -> void:
	var told := Library.history(_world)
	if index >= told.size():
		return
	var m: Dictionary = told[index]
	var won := int(m.get("place", 0)) == 1
	var column := VBoxContainer.new()
	column.size = area.size
	column.add_theme_constant_override("separation", 5)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(column)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 0)
	heading.add_child(_ink("Victory" if won else "Eliminated", Lettering.size_near(40), Spellbook.HEADING if won else Spellbook.TEXT_INK, true))
	var rule := ColorRect.new()
	rule.color = Spellbook.HEADING
	rule.custom_minimum_size = Vector2(0.0, Spellbook.SCALE * 0.6)
	heading.add_child(rule)
	column.add_child(heading)
	var online := " with friends" if bool(m.get("online", false)) else ""
	column.add_child(_ink("%s of %d%s, %s" % [_ordinal(int(m.get("place", 0))), int(m.get("field", 0)), online, _date(int(m.get("when", 0)))], 20, Spellbook.SUBTLE, false, true))
	var sections: Array = []  # each world of the match, where it began (as a share of the whole) and what it is called
	var total := maxf(float(m.get("seconds", 0)), 1.0)
	for stage: Array in m.get("stages", []):
		var biome := str(stage[0])
		var title := str(SurfaceGen.LOOKS[biome]["title"]).trim_prefix("The ") if SurfaceGen.LOOKS.has(biome) else biome
		sections.append([title, clampf(float(stage[1]) / total, 0.0, 1.0)])
	var trace := Trace.new(m.get("dealt_line", []), m.get("taken_line", []), sections)
	trace.custom_minimum_size = Vector2(0.0, 96.0)
	column.add_child(trace)
	var favourite := ""
	for entry: Array in m.get("favourites", []):
		favourite = "%s, %d" % [entry[0], int(entry[1])]
		break
	var rows := [
		["Time survived", _clock(int(m.get("seconds", 0)))],
		["Kills", str(int(m.get("kills", 0)))],
		["Damage dealt", str(int(m.get("dealt", 0)))],
		["Damage taken", str(int(m.get("taken", 0)))],
		["Spells cast", str(int(m.get("casts", 0)))],
		["Accuracy", "%d%%" % roundi(float(m.get("accuracy", 0.0)) * 100.0)],
		["Pages held", str(int(m.get("pages", 0)))],
	]
	if favourite != "":
		rows.append(["Favourite", favourite])
	for entry in rows:
		var row := HBoxContainer.new()
		row.add_child(_ink(entry[0], 19, Spellbook.SUBTLE))
		var value := _ink(entry[1], 20, Spellbook.HEADING)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		column.add_child(row)


## A time as minutes and seconds.
static func _clock(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]


static func _ordinal(n: int) -> String:
	var tail: String = "th" if (n % 100) in [11, 12, 13] else {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return "%d%s" % [n, tail]


static func _date(unix: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix)
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%d %s %d" % [d["day"], months[int(d["month"]) - 1], d["year"]]


## One count in a page's margin: a number, or for accuracy the average as a percentage ("-" before any cast could be judged).
func _figure(page: String, table: String) -> String:
	if table == "accuracy":
		var average := Library.average_accuracy(page)
		return "-" if average < 0.0 else "%d%%" % roundi(average * 100.0)
	return str(int(_data[table].get(page, 0)))


## A label in the small hand, or with `title` in the heading hand.
func _ink(text: String, size: int, colour: Color, title := false, wrap := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", Lettering.FACE if title else JERSEY)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

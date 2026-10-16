class_name Spellbook
extends CanvasLayer

## An open book held up in front of you. Tab opens or closes it; Left and Right turn the pages.
## It doesn't pause anything, so you can keep casting and typing while you read.
## Buttons are drawn as a mouse with the held buttons lit up, and incantations as an Enter key.

const INK := Color("#2b1d10")
const HEADING := Color("#6b1d14")
const SUBTLE := Color("#5a4330")
const PAPER := Color("#eedcb2")
const PAPER_EDGE := Color("#8a6a3a")
const LEATHER := Color("#4a2a12")
const GOLD := Color("#c9a24a")
const BOOK_SIZE := Vector2(1000, 572)

## The schools, in the order they appear in the book.
const SCHOOLS := ["Fire", "Ice", "Force", "Lightning", "Earth"]

var _spread := 0
var _pages: Array[Callable] = []
var _book: PanelContainer
var _book_centre_y := 0.0  # where the book sits when centred on screen
var _lifted := false        # the book moves to the top while the typing box is open, so the box never covers it
var _left: VBoxContainer
var _right: VBoxContainer
var _book_font: Font
var _title_font: Font


## A mouse seen from above: an oval body split into two buttons and a scroll wheel. The buttons in
## `mask` are lit in `lit`, so the picture shows exactly which buttons a school needs.
class MouseIcon extends Control:
	var mask := 0
	var lit := Color.WHITE

	func _init(button_mask: int, lit_color: Color, icon_size := Vector2(40, 60)) -> void:
		mask = button_mask
		lit = lit_color
		custom_minimum_size = icon_size

	## Half-width of the oval at a given height.
	func _half_width(y: float, cy: float, rx: float, ry: float) -> float:
		var t := (y - cy) / ry
		return rx * sqrt(maxf(0.0, 1.0 - t * t))

	func _draw() -> void:
		var cx := size.x * 0.5
		var cy := size.y * 0.5
		var rx := size.x * 0.5 - 2.0
		var ry := size.y * 0.5 - 2.0
		var top := cy - ry
		var split := top + ry * 0.85  # where the buttons end
		var paper := Color("#f4ecd6")
		var idle := Color("#d8ccb0")
		# body
		var body := PackedVector2Array()
		for i in 48:
			var a := TAU * i / 48.0
			body.append(Vector2(cx + rx * cos(a), cy + ry * sin(a)))
		draw_colored_polygon(body, paper)
		# left button: from the top centre down the left edge to the split, then back to the centre line
		var left_btn := PackedVector2Array([Vector2(cx, top)])
		var steps := 12
		for i in steps + 1:
			var y := lerpf(top, split, float(i) / steps)
			left_btn.append(Vector2(cx - _half_width(y, cy, rx, ry), y))
		left_btn.append(Vector2(cx, split))
		draw_colored_polygon(left_btn, lit if (mask & SpellData.LEFT) else idle)
		# right button, mirrored
		var right_btn := PackedVector2Array([Vector2(cx, top)])
		for i in steps + 1:
			var y := lerpf(top, split, float(i) / steps)
			right_btn.append(Vector2(cx + _half_width(y, cy, rx, ry), y))
		right_btn.append(Vector2(cx, split))
		draw_colored_polygon(right_btn, lit if (mask & SpellData.RIGHT) else idle)
		# scroll wheel
		var wheel_h := ry * 0.35
		draw_rect(Rect2(cx - 2.0, top + ry * 0.2, 4.0, wheel_h), lit if (mask & SpellData.MIDDLE) else Color("#bfb395"))
		# outline and the dividing line between the buttons
		body.append(body[0])
		draw_polyline(body, Spellbook.INK, 2.0)
		draw_line(Vector2(cx, top), Vector2(cx, split), Spellbook.INK, 1.5)
		draw_line(Vector2(cx - rx * 0.9, split), Vector2(cx + rx * 0.9, split), Spellbook.INK, 1.0)


## Draws a gesture's shape, scaled to fit its box, with an arrowhead showing the drawing direction.
class Preview extends Control:
	var points := PackedVector2Array()

	func _init(pts: PackedVector2Array) -> void:
		points = pts
		custom_minimum_size = Vector2(46, 46)

	func _draw() -> void:
		if points.size() < 2:
			return
		var min_p := points[0]
		var max_p := points[0]
		for p in points:
			min_p = min_p.min(p)
			max_p = max_p.max(p)
		var extent := maxf(maxf(max_p.x - min_p.x, max_p.y - min_p.y), 1.0)
		var center := (min_p + max_p) * 0.5
		var scale_factor := 38.0 / extent
		var out := PackedVector2Array()
		for p in points:
			out.append((p - center) * scale_factor + size * 0.5)
		var ink := Spellbook.HEADING
		draw_polyline(out, ink, 2.5)
		var tip := out[out.size() - 1]
		var heading := (tip - out[out.size() - 2]).normalized()
		draw_line(tip, tip - heading.rotated(0.5) * 10.0, ink, 2.5)
		draw_line(tip, tip - heading.rotated(-0.5) * 10.0, ink, 2.5)
		draw_circle(out[0], 3.5, ink)


func _ready() -> void:
	visible = false
	layer = 5  # under the ritual typing box (layer 10), so the book never covers what you type

	_pages = [_page_contents]
	for school in SCHOOLS:
		_pages.append(_page_school.bind(school))
	_pages.append(_page_incantations)

	# A serif face suits a grimoire. Falls back to the system serif if none of these are installed.
	_book_font = SystemFont.new()
	_book_font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Times New Roman"])
	_title_font = SystemFont.new()
	_title_font.font_names = PackedStringArray(["Old English Text MT", "Harrington", "Papyrus", "Georgia"])

	var viewport_size := get_viewport().get_visible_rect().size
	var book := PanelContainer.new()
	var cover := StyleBoxFlat.new()
	cover.bg_color = LEATHER
	cover.set_corner_radius_all(16)
	cover.set_border_width_all(4)
	cover.border_color = GOLD
	cover.set_content_margin_all(16)
	cover.shadow_color = Color(0, 0, 0, 0.7)
	cover.shadow_size = 14
	book.add_theme_stylebox_override("panel", cover)
	book.add_theme_font_override("font", _book_font)
	book.size = BOOK_SIZE
	book.position = (viewport_size - BOOK_SIZE) * 0.5
	_book = book
	_book_centre_y = book.position.y
	add_child(book)

	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 0)
	book.add_child(spread)
	_left = _page_column(spread)
	var spine := ColorRect.new()
	spine.color = Color("#2a1608")
	spine.custom_minimum_size = Vector2(8, 0)
	spread.add_child(spine)
	_right = _page_column(spread)

	_show_spread()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_TAB:
		visible = not visible
		get_viewport().set_input_as_handled()
	elif visible and key.keycode == KEY_RIGHT:
		_turn(1)
		get_viewport().set_input_as_handled()
	elif visible and key.keycode == KEY_LEFT:
		_turn(-1)
		get_viewport().set_input_as_handled()


func _turn(direction: int) -> void:
	var last_spread := ceili(_pages.size() / 2.0) - 1
	_spread = clampi(_spread + direction, 0, last_spread)
	_show_spread()


## A sheet of parchment with a worn border. Its content goes inside the returned column.
func _page_column(parent: Control) -> VBoxContainer:
	var paper := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(3)
	style.set_border_width_all(2)
	style.border_color = PAPER_EDGE
	style.set_content_margin_all(26)
	paper.add_theme_stylebox_override("panel", style)
	paper.custom_minimum_size = Vector2((BOOK_SIZE.x - 60) * 0.5, BOOK_SIZE.y - 60)
	parent.add_child(paper)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	paper.add_child(column)
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


func _ink(text: String, size := 15, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_override("font", _book_font)
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label


## A display-face label for headings and names.
func _title_label(text: String, size: int, color := HEADING) -> Label:
	var label := _ink(text, size, color)
	label.add_theme_font_override("font", _title_font)
	return label


## A heading in the manuscript's red ink, with a gold rule under it.
func _heading(text: String, size := 22) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_child(_title_label(text, size, HEADING))
	var rule := ColorRect.new()
	rule.color = GOLD
	rule.custom_minimum_size = Vector2(0, 2)
	block.add_child(rule)
	return block


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = PAPER_EDGE
	rule.custom_minimum_size = Vector2(0, 1)
	return rule


## The Enter key, drawn as a keycap.
func _enter_key() -> PanelContainer:
	var cap := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f4ecd6")
	style.set_corner_radius_all(5)
	style.set_border_width_all(2)
	style.border_color = INK
	style.set_content_margin_all(6)
	cap.add_theme_stylebox_override("panel", style)
	cap.add_child(_ink("Enter", 14))
	return cap


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
	row.add_theme_constant_override("separation", 14)
	row.add_child(MouseIcon.new(_school_mask(school), SpellData.SCHOOL_COLORS[school], Vector2(30, 44)))
	row.add_child(_title_label(school, 18, HEADING))
	return row



func _page_contents(column: VBoxContainer) -> void:
	column.add_child(_heading("Spellbook of Spellcraft", 26))
	for school in SCHOOLS:
		column.add_child(_school_row(school))


func _page_school(column: VBoxContainer, school: String) -> void:
	column.add_child(_heading("%s school" % school, 24))
	var mouse := MouseIcon.new(_school_mask(school), SpellData.SCHOOL_COLORS[school], Vector2(44, 64))
	mouse.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # keep the mouse its own size, not the page's width
	column.add_child(mouse)
	column.add_child(_mob_row("Weak to this school", "weak", school))
	column.add_child(_mob_row("Resists this school", "resist", school))
	for spell_name in SpellData.SPELLS:
		var s: Dictionary = SpellData.SPELLS[spell_name]
		if s["school"] != school:
			continue
		column.add_child(_rule())
		column.add_child(_spell_entry(spell_name, s))


## A spell is its name and its shape, with a small line of stats underneath.
func _spell_entry(spell_name: String, s: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(Preview.new(GestureTemplates.preview_points(s.get("preview", s["gesture"]))))
	var text := VBoxContainer.new()
	text.custom_minimum_size = Vector2(340, 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	text.add_child(_title_label(spell_name, 18, HEADING))
	text.add_child(_ink("%d stamina   ·   %s" % [roundi(s["cost"]), SpellData.DAMAGE[spell_name]], 12, SUBTLE))
	row.add_child(text)
	return row


func _page_incantations(column: VBoxContainer) -> void:
	column.add_child(_heading("Incantations", 24))
	column.add_child(_enter_key())
	for ritual_id in RitualInput.RITUALS:
		var r: Dictionary = RitualInput.RITUALS[ritual_id]
		column.add_child(_rule())
		column.add_child(_title_label(r["name"], 20, HEADING))
		column.add_child(_ink("“%s”" % r["text"], 16))
		column.add_child(_ink(_ritual_effect(ritual_id), 12, SUBTLE))


func _ritual_effect(ritual_id: String) -> String:
	match ritual_id:
		"second_wind":
			return "Heals you, scaled by how true the chant is. Costs no stamina."
		"minimap":
			return "Shows or hides the minimap. Costs no stamina."
		"insight":
			return "Hover an enemy to see its health, weaknesses and resistances. Costs no stamina."
		"bonfire":
			return "A bonfire for 15 seconds. Standing near it slowly restores your health."
		"boundless":
			return "Your stamina does not run out for 15 seconds. Costs no stamina."
	return ""




func _page_blank(_column: VBoxContainer) -> void:
	pass


## A labelled row of the pictures of the enemies whose Mob.KINDS entry under key is this school.
func _mob_row(label_text: String, key: String, school: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var label := _ink(label_text, 13)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var found := false
	for kind in Mob.KINDS:
		var data: Dictionary = Mob.KINDS[kind]
		if data[key] != school:
			continue
		found = true
		# The frame is much larger than the enemy in it, so show only the part that has something drawn.
		var source: Texture2D = load("%s/%s_0.png" % [data["frames"], data["idle"]])
		var picture := TextureRect.new()
		var crop := AtlasTexture.new()
		crop.atlas = source
		crop.region = Rect2(source.get_image().get_used_rect())
		picture.texture = crop
		picture.custom_minimum_size = Vector2(44, 44)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(picture)
	if not found:
		row.add_child(_ink("none", 13, SUBTLE))
	return row


## Moves the book to the top of the screen while the typing box is open, back to the centre when it closes.
func lift_for_typing(on: bool) -> void:
	if on == _lifted or _book == null:
		return
	_lifted = on
	_book.position.y = 12.0 if on else _book_centre_y

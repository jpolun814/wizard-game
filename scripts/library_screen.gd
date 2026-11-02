class_name LibraryScreen
extends Control

## The library: what this machine remembers of the matches played on it (see Library), laid out as a shelf of cards, a row for each school.
## A card is a page of the book with its shape drawn on it. A page never found or cast is a card turned face down, so the shelf does not give
## away what there is to find. Clicking a card turns it over to what its page says and how often it was found, cast and won with, and a
## page that the filters at the top leave out is dimmed. The filters choose which kind of world the counts are of, and which count a card must have.

const MENU := "res://scenes/menu.tscn"
const PAGE_COLOUR := Color("#ffe9a0")
const PARCHMENT := Color("#e9d7bb")
const BACK := Color("#2a1a30")
const DIM := Color(0.55, 0.52, 0.65)
const CARD := Vector2(172.0, 216.0)
const WORLDS := ["graveyard", "mountains", "jungle", "ashlands", "castle", "underground", "portals"]

var _list: VBoxContainer
var _data: Dictionary
var _cards := 0
var _top: VBoxContainer       # the ledger line and the filters, made again whenever a filter changes
var _world := ""              # the kind of world the counts are of, or "" for every kind
var _measure := ""            # "pages", "casts" or "won_with": a card with none of these is dimmed; "" dims none


func _ready() -> void:
	_data = Library.stats_for(_world)
	var dark := ColorRect.new()
	dark.color = Color(0.03, 0.01, 0.05, 1.0)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dark)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 70.0
	column.offset_right = -70.0
	column.offset_top = 28.0
	column.offset_bottom = -28.0
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var title := Label.new()
	title.text = "Library"
	title.theme_type_variation = &"Heading"  # the lettering of the home screen's title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_top = VBoxContainer.new()
	_top.add_theme_constant_override("separation", 6)
	column.add_child(_top)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 18)
	scroll.add_child(_list)
	_refresh()
	var hint := _label("Click a card to turn it over", 20, DIM)
	hint.custom_minimum_size = Vector2(0.0, 30.0)
	column.add_child(hint)
	var back := Button.new()
	back.text = "Back"
	back.theme_type_variation = &"Back"
	back.custom_minimum_size = Vector2(240.0, 0.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_on_back)
	column.add_child(back)
	back.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_on_back()


func _on_back() -> void:
	Sfx.play("ui_click")
	get_tree().change_scene_to_file(MENU)


## Makes the top of the page and the shelves again from the filters as they now stand.
func _refresh() -> void:
	_data = Library.stats_for(_world)
	for child in _top.get_children():
		child.queue_free()
	for child in _list.get_children():
		child.queue_free()
	_cards = 0
	_top.add_child(_ledger())
	_top.add_child(_choices("World", [["", "All"]] + WORLDS.map(func(b: String) -> Array: return [b, str(SurfaceGen.LOOKS[b]["title"]).trim_prefix("The ")]), _world, func(v: String) -> void:
		_world = v
		_refresh()))
	_top.add_child(_choices("Show", [["", "All"], ["pages", "Found"], ["casts", "Cast"], ["won_with", "Won with"]], _measure, func(v: String) -> void:
		_measure = v
		_refresh()))
	_fill()


## One plain line of figures, written across the page with no boxes: what was played and won, and how much of the book is known.
func _ledger() -> HBoxContainer:
	var known := 0
	var every := Pages.every()
	for page in every:
		if _known(page):
			known += 1
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var figures: Array = []
	if _world == "":
		figures = [["Matches played", str(_data["matches"])], ["Matches won", str(_data["wins"])]]
	else:
		figures = [["Worlds entered", str(_data["worlds"])], ["Matches won here", str(_data["wins"])]]
	figures.append(["Pages known", "%d of %d" % [known, every.size()]])
	for k in figures.size():
		if k > 0:
			row.add_child(_label("·", 24, DIM))
		row.add_child(_label(figures[k][0], 20, DIM))
		row.add_child(_label(figures[k][1], 28, PAGE_COLOUR))
	return row


## A line of words to choose among, written plainly, the chosen one lit and underlined. Each option is [value, words].
func _choices(heading: String, options: Array, chosen: String, picked: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.add_child(_label(heading, 18, DIM))
	for option: Array in options:
		var button := Button.new()
		button.text = option[1]
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var lit: bool = option[0] == chosen
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, PAGE_COLOUR if lit else (Color(1.0, 0.95, 0.8) if state == "font_hover_color" else DIM))
		button.add_theme_font_size_override("font_size", 22)
		if lit:
			var line := StyleBoxFlat.new()
			line.bg_color = Color(0, 0, 0, 0)
			line.border_color = PAGE_COLOUR
			line.border_width_bottom = 2
			for state in ["normal", "hover", "pressed"]:
				button.add_theme_stylebox_override(state, line)
		button.pressed.connect(func() -> void:
			Sfx.play("ui_click", null, -8.0)
			picked.call(option[0]))
		row.add_child(button)
	return row


func _label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Outlined"
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## True when a page has been found or its spell cast at least once.
func _known(page: String) -> bool:
	var overall := Library.stats_for("")  # known by what was ever recorded, whichever kind of world the counts are of
	return overall["pages"].has(page) or overall["casts"].has(page) or overall["won_with"].has(page)


func _fill() -> void:
	for school in Spellbook.SCHOOLS:
		var spells: Array[String] = []
		for spell_name: String in SpellData.SPELLS:
			if SpellData.SPELLS[spell_name].school == school:
				spells.append(spell_name)
		_shelf(school, SpellData.SCHOOL_COLORS[school], spells)
	var chants: Array[String] = []
	for page in Pages.every():
		if page.begins_with("chant:"):
			chants.append(page)
	_shelf("Chants", PAGE_COLOUR, chants)


## A school's name over a rule of its colour, and a row of its cards.
func _shelf(heading: String, colour: Color, pages: Array[String]) -> void:
	var known := pages.filter(func(p: String) -> bool: return _known(p)).size()
	var banner := HBoxContainer.new()
	banner.add_theme_constant_override("separation", 14)
	banner.add_child(_label(heading, 32, colour))
	banner.add_child(_label("%d of %d" % [known, pages.size()], 20, DIM))
	var rule := ColorRect.new()
	rule.color = Color(colour, 0.55)
	rule.custom_minimum_size = Vector2(0.0, 3.0)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	banner.add_child(rule)
	_list.add_child(banner)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 14)
	_list.add_child(flow)
	for page in pages:
		flow.add_child(_card(page, colour))


## A card for one page: face up when it is known, face down when it is not. Clicking a known card turns it over, to what the page says and
## what this machine remembers of it.
func _card(page: String, colour: Color) -> Control:
	var known := _known(page)
	var card := Control.new()  # the card itself, with its two faces filling it and its star laid over a corner
	card.custom_minimum_size = CARD
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var front := _face(PARCHMENT if known else BACK, colour.darkened(0.2) if known else Color(0.3, 0.22, 0.4), known)
	card.add_child(front)
	var inside: VBoxContainer = front.get_child(0)
	if known:
		inside.add_child(_title(page, Spellbook.HEADING, 48.0))
		inside.add_child(_picture(page))
	else:
		inside.add_child(_label("?", 84, Color(0.4, 0.3, 0.55)))
	if known:
		var back := _face(BACK, colour, false)
		back.visible = false
		card.add_child(back)
		_write_back(back.get_child(0), page, colour)
	card.gui_input.connect(_on_card_input.bind(card, known))
	card.mouse_entered.connect(_pointed_at.bind(card))
	card.mouse_exited.connect(_left.bind(card))
	card.modulate.a = 0.0
	var appear := create_tween()
	appear.tween_interval(0.025 * _cards)
	appear.tween_property(card, "modulate:a", 0.3 if (known and _measure != "" and int(_data[_measure].get(page, 0)) == 0) else 1.0, 0.25)  # a card with none of what the filter asks for is dimmed
	_cards += 1
	return card


## One face of a card: a panel with its border and a column to put things in. The top edge of a face-up card is thick, in the school's colour.
func _face(fill: Color, border: Color, thick_top: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.border_width_top = 10 if thick_top else 3
	style.set_corner_radius_all(5)
	style.set_content_margin_all(8.0)
	panel.add_theme_stylebox_override("panel", style)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 4)
	inside.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(inside)
	return panel


func _title(page: String, colour: Color, height: float) -> Label:
	var name_label := Label.new()
	name_label.text = Pages.title_of(page)
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", colour)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0.0, height)
	return name_label


## The back of a card: the name, what the page says, and the three counts.
func _write_back(inside: VBoxContainer, page: String, colour: Color) -> void:
	inside.alignment = BoxContainer.ALIGNMENT_BEGIN
	inside.add_child(_title(page, colour.lightened(0.25), 30.0))
	var says := _label(_describe(page), 15, Color(0.88, 0.84, 0.95))
	says.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	says.size_flags_vertical = Control.SIZE_EXPAND_FILL
	says.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	inside.add_child(says)
	for entry in [["Found", "pages"], ["Cast", "casts"], ["Won with", "won_with"]]:
		var row := HBoxContainer.new()
		row.add_child(_label(entry[0], 16, DIM))
		var count := _label(str(int(_data[entry[1]].get(page, 0))), 20, PAGE_COLOUR)
		count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(count)
		inside.add_child(row)


## What the book says of a page.
func _describe(page: String) -> String:
	if page.begins_with("chant:"):
		var id := page.trim_prefix("chant:")
		return "“%s”  %s" % [RitualInput.RITUALS[id]["text"], Spellbook.ritual_effect(id)]
	return SpellData.SPELLS[page].effect


## What the card shows: the shape of its spell drawn out, or for a chant the key that begins it.
func _picture(page: String) -> Control:
	if page.begins_with("chant:"):
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(0.0, 96.0)
		holder.add_child(Spellbook.KeyCap.new("Enter"))
		return holder
	var spell: Spell = SpellData.SPELLS[page]
	var gesture: String = spell.preview if spell.preview != "" else spell.gesture
	var picture := Spellbook.Preview.new(GestureTemplates.preview_points(gesture), GestureTemplates.preview_ground(gesture), 96.0)
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return picture


func _on_card_input(event: InputEvent, card: Control, known: bool) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if not known:
		var shake := create_tween()  # a card face down has nothing to turn over to
		shake.tween_property(card, "rotation", 0.05, 0.05)
		shake.tween_property(card, "rotation", -0.05, 0.1)
		shake.tween_property(card, "rotation", 0.0, 0.05)
		return
	Sfx.play("page", null, -6.0)
	card.pivot_offset = card.size * 0.5
	var turn := create_tween()
	turn.tween_property(card, "scale:x", 0.0, 0.12)
	turn.tween_callback(func() -> void:
		card.get_child(0).visible = not card.get_child(0).visible
		card.get_child(1).visible = not card.get_child(1).visible)
	turn.tween_property(card, "scale:x", 1.08, 0.12)


func _pointed_at(card: Control) -> void:
	card.pivot_offset = card.size * 0.5
	card.z_index = 1
	create_tween().tween_property(card, "scale:y", 1.08, 0.12)
	if card.scale.x > 0.5:
		create_tween().tween_property(card, "scale:x", 1.08, 0.12)


func _left(card: Control) -> void:
	card.z_index = 0
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.12)

class_name LibraryScreen
extends Control

## The library: what this machine remembers of the matches played on it (see Library), laid out as a shelf of cards, a row for each school.
## A card is a page of the book with its shape drawn on it. A page never found or cast is a card turned face down, so the shelf does not give
## away what there is to find. Clicking a card turns it over to what its page says and how often it was found, cast and won with, and a
## star marks a page that has won a match.

const MENU := "res://scenes/menu.tscn"
const PAGE_COLOUR := Color("#ffe9a0")
const PARCHMENT := Color("#e9d7bb")
const BACK := Color("#2a1a30")
const DIM := Color(0.55, 0.52, 0.65)
const STAR := Color("#ffd24a")
const CARD := Vector2(172.0, 216.0)

var _list: VBoxContainer
var _data: Dictionary
var _cards := 0


func _ready() -> void:
	_data = Library.stats()
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
	title.theme_type_variation = &"Outlined"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(_summary())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 18)
	scroll.add_child(_list)
	_fill()
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


## The row of three plates at the top: matches played, matches won, and how much of the book has been found, as a bar that fills.
func _summary() -> HBoxContainer:
	var known := 0
	var every := Pages.every()
	for page in every:
		if _known(page):
			known += 1
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.add_child(_plate(str(_data["matches"]), "Matches played", null))
	row.add_child(_plate(str(_data["wins"]), "Matches won", null))
	row.add_child(_plate("%d of %d" % [known, every.size()], "Pages known", float(known) / float(every.size())))
	return row


## One plate: a big figure, what it counts, and (for a share) a bar under it.
func _plate(figure: String, what: String, share: Variant) -> PanelContainer:
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.07, 0.17)
	style.border_color = Color(0.45, 0.32, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10.0)
	plate.add_theme_stylebox_override("panel", style)
	plate.custom_minimum_size = Vector2(210.0, 0.0)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 2)
	plate.add_child(inside)
	var big := _label(figure, 34, PAGE_COLOUR)
	inside.add_child(big)
	inside.add_child(_label(what, 17, DIM))
	if share != null:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.value = share
		bar.custom_minimum_size = Vector2(0.0, 8.0)
		inside.add_child(bar)
	return plate


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
	return _data["pages"].has(page) or _data["casts"].has(page) or _data["won_with"].has(page)


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
		if int(_data["won_with"].get(page, 0)) > 0:
			var star := Label.new()
			star.text = "★"
			star.add_theme_font_size_override("font_size", 28)
			star.add_theme_color_override("font_color", STAR)
			star.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.05))
			star.add_theme_constant_override("outline_size", 6)
			star.position = Vector2(CARD.x - 36.0, -4.0)
			card.add_child(star)
	card.gui_input.connect(_on_card_input.bind(card, known))
	card.mouse_entered.connect(_pointed_at.bind(card))
	card.mouse_exited.connect(_left.bind(card))
	card.modulate.a = 0.0
	var appear := create_tween()
	appear.tween_interval(0.025 * _cards)
	appear.tween_property(card, "modulate:a", 1.0, 0.25)
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

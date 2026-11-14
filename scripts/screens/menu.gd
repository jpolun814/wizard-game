class_name Menu
extends Control

## The first screen: single player (play, or the tutorial), multiplayer (host a game for friends, or join a friend's game by its address), and
## the library. Playing, hosting and joining all lead to the waiting room, which everyone in the game then shares (see Net).
## It is the spellbook, open: each choice is an inscription with its sign beside it, and it is chosen the way a spell is cast, by drawing the
## sign with the left mouse button held. (Clicking an inscription, or the keyboard, chooses it too.) A choice that leads on turns the page.

const WAITING_ROOM := "res://scenes/lab.tscn"
const TUTORIAL := "res://scenes/tutorial.tscn"
const LIBRARY := "res://scenes/library.tscn"
const SETTINGS := "user://settings.cfg"  # remembers the last address typed, so a friend's game is one click away next time

@onready var _main: VBoxContainer = $Box/Main
@onready var _single: VBoxContainer = $Box/Single
@onready var _multi: VBoxContainer = $Box/Multi
@onready var _alone: Button = $Box/Single/Play
@onready var _single_player: Button = $Box/Main/SinglePlayer  # kept here: _dress moves the buttons into rows, and a path to them no longer finds them
@onready var _multiplayer: Button = $Box/Main/Multiplayer
@onready var _single_back: Button = $Box/Single/SingleBack
@onready var _multi_back: Button = $Box/Multi/MultiBack
@onready var _host: Button = $Box/Multi/Host
@onready var _address: LineEdit = $Box/Multi/JoinRow/Address
@onready var _join: Button = $Box/Multi/JoinRow/Join
@onready var _status: Label = $Box/Status
@onready var _tutorial: Button = $Box/Single/Tutorial
@onready var _library: Button = $Box/Main/Library
@onready var _options: Button = $Box/Main/Settings
@onready var _box: VBoxContainer = $Box

const SCENERY := "res://art/backgrounds/cemetery/"
## The sign of each choice is a picture of what it means: one stroke for one player, a 4 for a game of four, a closed book for the library,
## a house for hosting a game, an arrow for going on (to play, or to join a game), a question mark for learning, a triangle pointing back for going back and a cross for leaving. Pictures the spells already have are
## the game's own (see GestureTemplates); the others are drawn here.
const SHAPES := {
	"one": [Vector2(0, -50), Vector2(0, 50)],
	"book": [Vector2(0, 40), Vector2(0, -20), Vector2(-50, -30), Vector2(-50, 30), Vector2(0, 40), Vector2(50, 30), Vector2(50, -30), Vector2(0, -20)],  # an open book: the spine, a page either side
	"four": [Vector2(20, 50), Vector2(20, -50), Vector2(-45, 15), Vector2(50, 15)],  # the stem, the slant, the bar
	"house": [Vector2(-40, 40), Vector2(-40, -5), Vector2(0, -45), Vector2(40, -5), Vector2(40, 40), Vector2(-40, 40)],  # straight walls and a roof
	"gear": [Vector2(0, -38), Vector2(6, -50), Vector2(17, -47), Vector2(17, -34), Vector2(27, -27), Vector2(39, -31), Vector2(45, -21), Vector2(36, -12), Vector2(38, 0), Vector2(50, 6), Vector2(47, 17), Vector2(34, 17), Vector2(27, 27), Vector2(31, 39), Vector2(21, 45), Vector2(12, 36), Vector2(0, 38), Vector2(-6, 50), Vector2(-17, 47), Vector2(-17, 34), Vector2(-27, 27), Vector2(-39, 31), Vector2(-45, 21), Vector2(-36, 12), Vector2(-38, 0), Vector2(-50, -6), Vector2(-47, -17), Vector2(-34, -17), Vector2(-27, -27), Vector2(-31, -39), Vector2(-21, -45), Vector2(-12, -36), Vector2(0, -38)],  # a cog: eight teeth round a ring
	"back": [Vector2(40, -40), Vector2(-40, 0), Vector2(40, 40), Vector2(40, -40)],  # a triangle pointing the way back
	"quit": [Vector2(-40, -40), Vector2(40, 40), Vector2(-40, 40), Vector2(40, -40)],  # a cross, drawn in one stroke: the way out
}
const SIGNS := {  # the recognizer's templates that count as each sign
	"one": ["menu_one"], "four": ["menu_four"], "book": ["menu_book"], "house": ["menu_house"], "back": ["menu_back"], "quit": ["menu_quit"], "gear": ["menu_gear"],
	"arrow": ["arrow", "arrow_r2", "arrow_l", "arrow_l2"], "question": ["question", "question_r"]}
const LEAST_SCORE := 0.74  # how well a stroke must match a sign to choose it
const LEAST_STROKE := 60.0  # a stroke shorter than this is a click, not a drawing
const INK := Color("#3a1d1a")
const GLOW := Color(1.0, 0.78, 0.3)
const BOOK_ART := Rect2(12, 21, 157, 125)  # the open book's picture inside its frame, in book pixels
const LEFT_PAGE := Rect2(25, 30, 57, 100)
const RIGHT_PAGE := Rect2(98, 30, 58, 100)
const PIXEL := 3  # whole-number scale for the pixel art
const TITLE_FONT := Lettering.FACE

var _ranges: Array[TextureRect] = []  # the far and near scenery, farthest first, along the bottom
var _wizard: AnimatedSprite2D
var _embers: CPUParticles2D
var _title: Label
var _book: BookArt
var _demo: MenuSign  # on the left page: the sign of the choice the pointer or the keyboard is on, drawn out again and again
var _ink: MenuInk   # the stroke being drawn
var _recognizer := UnistrokeRecognizer.new()
var _signs: Dictionary = {}  # Button -> the name of its sign
var _small_signs: Dictionary = {}  # Button -> the little drawing of its sign beside it
var _pixel := 4
var _stroke := PackedVector2Array()
var _drawing := false
var _busy := false  # a choice has been made and is being carried out
var _clock := 0.0


func _ready() -> void:
	if Net.online():
		Net.leave()  # back here from a game: this machine plays alone again until it hosts or joins
	_status.text = Net.farewell
	Net.farewell = ""
	var settings := ConfigFile.new()
	if settings.load(SETTINGS) == OK:
		_address.text = settings.get_value("network", "address", "")
	_alone.pressed.connect(_on_alone)
	_host.pressed.connect(_on_host)
	_join.pressed.connect(_on_join)
	_tutorial.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		get_tree().change_scene_to_file(TUTORIAL))
	_library.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		get_tree().change_scene_to_file(LIBRARY))
	_options.pressed.connect(_open_settings)
	$Box/Main/Quit.pressed.connect(func() -> void: get_tree().quit())
	_single_player.pressed.connect(_show_page.bind(_single, _alone, true))
	_multiplayer.pressed.connect(_show_page.bind(_multi, _host, true))
	_single_back.pressed.connect(_show_page.bind(_main, _single_player, false))
	_multi_back.pressed.connect(_show_page.bind(_main, _multiplayer, false))
	var templates := GestureTemplates.recognizer_templates()
	for template_name: String in templates:
		_recognizer.add_template(template_name, templates[template_name])
	for shape_name: String in SHAPES:
		_recognizer.add_template("menu_" + shape_name, PackedVector2Array(SHAPES[shape_name]))
	_address.text_submitted.connect(func(_text: String) -> void: _on_join())
	Net.roster_changed.connect(_on_roster_changed)
	Net.disconnected.connect(_on_disconnected)
	var first: Button = _single_player
	(func() -> void:
		if is_instance_valid(first) and first.is_inside_tree():
			first.grab_focus()).call_deferred()
	_dress()
	_write_signs()
	resized.connect(_lay_out)
	_lay_out()
	_box.visible = false  # the book opens first
	_demo.visible = false
	_book.play([0, 1, 2, Spellbook.OPEN], _page_ready)


func _process(delta: float) -> void:
	_clock += delta
	if _title != null:
		_title.modulate.a = 0.9 + sin(_clock * 1.6) * 0.1  # the title's glow breathes
	if _wizard != null:
		_wizard.position.y += sin(_clock * 2.0) * 0.15  # and the wizard hovers a little


## The first screen has the graveyard under its blood moon behind it, a wizard standing watch, embers drifting up, and the game's name.
func _dress() -> void:
	var sky := TextureRect.new()
	sky.texture = load(SCENERY + "sky.png")
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	for file in ["far.png", "near.png"]:
		var range_rect := TextureRect.new()
		var whole: Texture2D = load(SCENERY + file)
		var trimmed := AtlasTexture.new()  # without the top row of pixels, which is a pale line across the screen
		trimmed.atlas = whole
		trimmed.region = Rect2(0, 1, whole.get_width(), whole.get_height() - 1)
		range_rect.texture = trimmed
		range_rect.stretch_mode = TextureRect.STRETCH_TILE
		range_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		range_rect.scale = Vector2(PIXEL, PIXEL)
		add_child(range_rect)
		_ranges.append(range_rect)
	_wizard = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 8.0)
	for k in 6:
		frames.add_frame("idle", load("res://art/chars/wizard/idle_%d.png" % k))
	_wizard.sprite_frames = frames
	_wizard.scale = Vector2(PIXEL + 1, PIXEL + 1)
	_wizard.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # whole pixels, sharp, not smoothed up
	add_child(_wizard)
	_wizard.play("idle")
	_embers = CPUParticles2D.new()
	_embers.amount = 60
	_embers.lifetime = 7.0
	_embers.preprocess = 7.0
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.direction = Vector2(0.2, -1.0)
	_embers.spread = 20.0
	_embers.gravity = Vector2.ZERO
	_embers.initial_velocity_min = 18.0
	_embers.initial_velocity_max = 50.0
	_embers.scale_amount_min = 2.0
	_embers.scale_amount_max = 4.0
	_embers.color = Color(1.0, 0.55, 0.25, 0.8)
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.8, 0.4, 0.0))
	fade.add_point(0.2, Color(1.0, 0.6, 0.3, 0.9))
	fade.set_color(2, Color(0.8, 0.2, 0.1, 0.0))
	_embers.color_ramp = fade
	add_child(_embers)
	_book = BookArt.new()
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_book)
	_demo = MenuSign.new()
	_demo.animated = true
	_demo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_demo)
	_ink = MenuInk.new()
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ink)
	_title = Label.new()
	_title.text = "Wizard Game"
	_title.add_theme_font_override("font", TITLE_FONT)
	_title.add_theme_font_size_override("font_size", Lettering.size_near(96))
	_title.add_theme_color_override("font_color", Color(0.9, 0.8, 1.0))
	_title.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.2))
	_title.add_theme_constant_override("outline_size", 14)
	_title.add_theme_color_override("font_shadow_color", Color(0.8, 0.1, 0.35, 0.55))
	_title.add_theme_constant_override("shadow_offset_y", 5)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	move_child(_wizard, _demo.get_index() + 1)  # the wizard stands in front of the book, not behind it
	move_child(_box, get_child_count() - 1)  # the inscriptions stay on top of it all
	move_child(_ink, get_child_count() - 1)  # and the stroke over them


## Sets everything to the window's size: the scenery along the bottom, the wizard at the left, the title across the top.
func _lay_out() -> void:
	var window := size
	for k in _ranges.size():
		var texture := _ranges[k].texture
		_ranges[k].size = Vector2(ceil(window.x / PIXEL) + 1.0, texture.get_height())
		_ranges[k].position = Vector2(0.0, window.y - texture.get_height() * PIXEL)
	_wizard.position = Vector2(window.x * 0.11, window.y - 262.0)
	_embers.position = Vector2(window.x * 0.5, window.y)
	_embers.emission_rect_extents = Vector2(window.x * 0.5, 4.0)
	_title.position = Vector2(0.0, window.y * 0.04)
	_title.size = Vector2(window.x, 110.0)
	# The open book sits low and in the middle, under the title, at a whole number of screen pixels to a pixel of its picture.
	_pixel = clampi(floori((window.y - 150.0) / BOOK_ART.size.y), 3, 8)
	var origin := Vector2((window.x - BOOK_ART.size.x * _pixel) * 0.5 - BOOK_ART.position.x * _pixel, window.y - 30.0 - BOOK_ART.end.y * _pixel).floor()
	_book.pixel = _pixel
	_book.position = origin
	_book.size = Spellbook.FRAME * _pixel
	_book.queue_redraw()
	_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_box.position = origin + RIGHT_PAGE.position * _pixel + Vector2(0.0, 6.0 * _pixel)
	_box.size = Vector2(RIGHT_PAGE.size.x * _pixel, (RIGHT_PAGE.size.y - 8.0) * _pixel)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_status.custom_minimum_size.x = RIGHT_PAGE.size.x * _pixel
	_demo.position = origin + LEFT_PAGE.position * _pixel + Vector2(0.0, 8.0 * _pixel)
	_demo.size = Vector2(LEFT_PAGE.size.x * _pixel, (LEFT_PAGE.size.y - 16.0) * _pixel)
	_ink.position = Vector2.ZERO
	_ink.size = window


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _main.visible:
		_show_page(_main, _single_player if _single.visible else _multiplayer, false)  # Esc goes back a page


## Shows one page of inscriptions (the main ones, single player's or multiplayer's), with the keyboard on one of its choices. The book turns its
## page: forward when the choice leads on, back when it goes back.
func _show_page(page: VBoxContainer, focus: Button, forward: bool) -> void:
	if _busy:
		return
	Sfx.play("ui_click")
	_status.text = ""
	_box.visible = false
	_demo.visible = false
	_book.play([4, 5, 6, Spellbook.OPEN] if forward else [6, 5, 4, Spellbook.OPEN], func() -> void:
		_main.visible = page == _main
		_single.visible = page == _single
		_multi.visible = page == _multi
		_page_ready()
		focus.grab_focus())


## The page is open: its inscriptions are written, and the sign of the first is drawn out on the left.
func _page_ready() -> void:
	_box.visible = true
	_demo.visible = true
	_lay_out()
	var page: VBoxContainer = _main if _main.visible else (_single if _single.visible else _multi)
	for button in _buttons_in(page):
		if _signs.has(button):
			_show_sign(_signs[button])
			return


func _buttons_in(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	if node is Button:
		found.append(node)
	for child in node.get_children():
		found.append_array(_buttons_in(child))
	return found


## The choices that can be made now, with the sign of each.
func _live() -> Dictionary:
	var out := {}
	for button: Button in _signs:
		if button.is_visible_in_tree() and not button.disabled:
			out[button] = _signs[button]
	return out


func _show_sign(sign_name: String) -> void:
	_demo.gesture = sign_name
	_demo.restart()


## Each choice with a sign gets it drawn beside it, small, and shows the larger one on the left page when the pointer or the keyboard comes to it.
func _write_signs() -> void:
	var table := {_single_player: "one", _multiplayer: "four", $Box/Main/Library: "book", $Box/Main/Settings: "gear", $Box/Main/Quit: "quit",
			$Box/Single/Play: "arrow", $Box/Single/Tutorial: "question", $Box/Multi/Host: "house", $Box/Multi/JoinRow/Join: "arrow", _single_back: "back", _multi_back: "back"}
	for button: Button in table:
		_signs[button] = table[button]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var parent := button.get_parent()
		parent.add_child(row)
		parent.move_child(row, button.get_index())
		var small := MenuSign.new()
		small.gesture = table[button]
		small.custom_minimum_size = Vector2(48, 48)
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.reparent(row, false)
		row.add_child(small)
		row.move_child(small, 0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_entered.connect(_show_sign.bind(table[button]))
		button.mouse_entered.connect(_show_sign.bind(table[button]))
		_small_signs[button] = small


## Drawing a sign: the left button held draws a stroke, wherever it is not over a choice (that is a click); when it is let go the stroke is read.
func _input(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var over := get_viewport().gui_get_hovered_control()
			if over is BaseButton or over is LineEdit or not _box.visible:
				return
			_drawing = true
			_stroke = PackedVector2Array([event.position])
			_ink.set_stroke(_stroke)
		elif _drawing:
			_drawing = false
			_read_stroke()
	elif event is InputEventMouseMotion and _drawing:
		if _stroke[_stroke.size() - 1].distance_to(event.position) >= 3.0:
			_stroke.append(event.position)
			_ink.set_stroke(_stroke)


func _read_stroke() -> void:
	var drawn := _stroke
	_ink.let_go()
	if UnistrokeRecognizer.path_length(drawn) < LEAST_STROKE:
		return
	var live := _live()
	var accepted: Array = []
	for sign_name: String in live.values():
		accepted.append_array(SIGNS[sign_name])
	var result := _recognizer.recognize(drawn, accepted)
	if result["score"] < LEAST_SCORE:
		return
	for button: Button in live:
		if SIGNS[live[button]].has(result["name"]):
			_choose(button)
			return


## A sign was drawn: its inscription flares, and a moment later the choice is made as if it had been clicked.
func _choose(button: Button) -> void:
	_busy = true
	_ink.flare()
	_small_signs[button].flare()
	_show_sign(_signs[button])  # the left page shows the sign that was drawn, whatever the pointer had last been over
	_demo.flare()
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		_busy = false
		button.pressed.emit())


## The page of settings opens over the book; while it is open, nothing is drawn on the book behind it.
func _open_settings() -> void:
	Sfx.play("ui_click")
	_busy = true
	var panel := SettingsPanel.new()
	panel.closed.connect(func() -> void:
		_busy = false
		_options.grab_focus())
	add_child(panel)


func _on_alone() -> void:
	Sfx.play("ui_click")
	get_tree().change_scene_to_file(WAITING_ROOM)


func _on_host() -> void:
	Sfx.play("ui_click")
	if Net.host() != OK:
		_status.text = "Close the other copy of the game that is hosting, then try again."  # the port is taken
		return
	get_tree().change_scene_to_file(WAITING_ROOM)


func _on_join() -> void:
	Sfx.play("ui_click")
	var address := _address.text.strip_edges()
	if address == "":
		_status.text = "Type the address your friend sees in their waiting room."
		return
	var settings := ConfigFile.new()
	settings.set_value("network", "address", address)
	settings.save(SETTINGS)
	if Net.join(address) != OK:
		_status.text = "Check the address and try again."
		return
	_status.text = ""
	_set_waiting(true)


## While joining, the buttons wait for the answer.
func _set_waiting(waiting: bool) -> void:
	for button: Button in [_alone, _host, _join, _tutorial, _library, _single_player, _multiplayer, _single_back, _multi_back]:
		button.disabled = waiting
	_address.editable = not waiting
	_join.text = "Joining..." if waiting else "Join"


## The host has given this machine a seat: into the waiting room. (Hosting goes there from _on_host: the roster it makes is not an answer.)
func _on_roster_changed() -> void:
	if Net.online() and not Net.is_host() and Net.seat_of(Net.my_id()) >= 0:
		get_tree().change_scene_to_file(WAITING_ROOM)


func _on_disconnected(reason: String) -> void:
	_set_waiting(false)
	_status.text = reason
	Net.farewell = ""  # said here already



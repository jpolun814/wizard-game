extends Control

## The first screen: play alone, host a game for friends, or join a friend's game by its address. Hosting and joining both lead to
## the waiting room, which everyone in the game then shares (see Net).

const WAITING_ROOM := "res://scenes/lab.tscn"
const SETTINGS := "user://settings.cfg"  # remembers the last address typed, so a friend's game is one click away next time

@onready var _alone: Button = $Box/Alone
@onready var _host: Button = $Box/Host
@onready var _address: LineEdit = $Box/JoinRow/Address
@onready var _join: Button = $Box/JoinRow/Join
@onready var _status: Label = $Box/Status

const SCENERY := "res://art/backgrounds/cemetery/"
const PIXEL := 3  # whole-number scale for the pixel art
const TITLE_FONT := preload("res://fonts/PirataOne-Regular.ttf")

var _ranges: Array[TextureRect] = []  # the far and near scenery, farthest first, along the bottom
var _wizard: AnimatedSprite2D
var _embers: CPUParticles2D
var _title: Label
var _plate: Panel  # darkens the scenery behind the buttons
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
	_address.text_submitted.connect(func(_text: String) -> void: _on_join())
	Net.roster_changed.connect(_on_roster_changed)
	Net.disconnected.connect(_on_disconnected)
	_alone.grab_focus.call_deferred()
	_dress()
	resized.connect(_lay_out)
	_lay_out()


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
	_plate = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.02, 0.08, 0.62)
	style.border_color = Color(0.45, 0.32, 0.65, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	_plate.add_theme_stylebox_override("panel", style)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	_title = Label.new()
	_title.text = "Wizard Game"
	_title.add_theme_font_override("font", TITLE_FONT)
	_title.add_theme_font_size_override("font_size", 96)
	_title.add_theme_color_override("font_color", Color(0.9, 0.8, 1.0))
	_title.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.2))
	_title.add_theme_constant_override("outline_size", 14)
	_title.add_theme_color_override("font_shadow_color", Color(0.8, 0.1, 0.35, 0.55))
	_title.add_theme_constant_override("shadow_offset_y", 5)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	move_child($Box, get_child_count() - 1)  # the buttons stay on top of it all


## Sets everything to the window's size: the scenery along the bottom, the wizard at the left, the title across the top.
func _lay_out() -> void:
	var window := size
	for k in _ranges.size():
		var texture := _ranges[k].texture
		_ranges[k].size = Vector2(ceil(window.x / PIXEL) + 1.0, texture.get_height())
		_ranges[k].position = Vector2(0.0, window.y - texture.get_height() * PIXEL)
	_wizard.position = Vector2(window.x * 0.17, window.y - 262.0)
	_embers.position = Vector2(window.x * 0.5, window.y)
	_embers.emission_rect_extents = Vector2(window.x * 0.5, 4.0)
	_title.position = Vector2(0.0, window.y * 0.1)
	_title.size = Vector2(window.x, 110.0)
	var box := Rect2($Box.position, $Box.get_combined_minimum_size()).grow(24.0)
	_plate.position = box.position
	_plate.size = box.size


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
	for button: Button in [_alone, _host, _join]:
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

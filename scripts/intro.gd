class_name Intro
extends Node2D

## The cut-scene between the waiting room and a world. Four wizards reach for the same pile of pages in a cathedral hall; in the
## scuffle every page but the few each wizard has hold of is knocked into the portal, and the portal scatters them over the world.
## The same scene plays whether the other three wizards are AI or real players. Any key skips it.

signal finished  # the scene is over, and the next one is about to load

const LOADING := "res://scenes/loading.tscn"
const PAGE := preload("res://art/props/page.png")
const PLAYER_FRAMES := preload("res://scripts/player.gd")
const FLOOR_Y := float(ArenaGen.GROUND_Y)
const PILE_X := -150.0
const PORTAL_X := 250.0
const PAGES_IN_PILE := 26
const KEPT := 4          # the pages each wizard has hold of, one shown for each wizard
const GOLD := Color("#ffe9a0")
const SKIP_HINT_AFTER := 1.0
## Each wizard: the folder of its frames, where it starts and where it stands at the pile, and which way it faces to begin with.
const WIZARDS := [
	{"art": "wizard_wand", "from": -360.0, "to": -245.0},
	{"art": "dark_wizard", "from": -320.0, "to": -190.0},
	{"art": "bone_wizard", "from": 40.0, "to": -110.0},
	{"art": "pyre_wizard", "from": 100.0, "to": -55.0},
]
const WALK := 150.0  # pixels a second, running to the pile
const RUN := 260.0   # and to the portal
const END := 10.6  # seconds, from the first frame to the world

var next_scene := LOADING  # set before it enters the tree; empty to stay on when it is over (a test does that)
var _t := 0.0
var _cues: Array = []  # [seconds, Callable], in order
var _wizards: Array[Node2D] = []
var _pile: Array[Sprite2D] = []
var _portal: Portal
var _camera: Camera2D
var _caption: Label
var _hint: Label
var _black: ColorRect
var _shake := 0.0
var _leaving := false
var _halo: Node2D


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	_build_hall(rng)
	_build_pile(rng)
	_build_wizards()
	_build_portal()
	_build_overlay()
	_cue(0.0, func() -> void: _fade(0.0, 0.8))
	_cue(0.4, func() -> void: _say("Four wizards. One pile of pages."))
	_cue(2.0, func() -> void: _say(""))
	_cue(2.1, _wizards_run_to_pile)
	_cue(3.5, _scuffle)
	_cue(4.9, func() -> void: _say("In the scuffle, the pages are knocked through the portal."))
	_cue(6.8, func() -> void: _say("Find them. Be the last wizard standing."))
	_cue(7.8, _wizards_run_to_portal)
	_cue(9.8, func() -> void: _fade(1.0, 0.7))
	_cue(END, _leave)
	_cues.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


func _process(delta: float) -> void:
	_t += delta
	while not _cues.is_empty() and _cues[0][0] <= _t:
		_cues.pop_front()[1].call()
	_shake = maxf(_shake - delta * 1.6, 0.0)
	_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * 6.0
	_hint.visible = _t > SKIP_HINT_AFTER and not _leaving
	_halo.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or not (event is InputEventKey or event is InputEventMouseButton) or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	_cues.clear()
	_fade(1.0, 0.3)
	_cue(_t + 0.3, _leave)


func _cue(seconds: float, action: Callable) -> void:
	_cues.append([seconds, action])


# --- The set ------------------------------------------------------------------------------------------------------


## A cathedral hall: the church backdrop, its stone floor, a camera that looks at the pile and the portal.
func _build_hall(rng: RandomNumberGenerator) -> void:
	var backdrop := Backdrop.new()
	add_child(backdrop)
	backdrop.build(ArenaGen.BIOMES["church"]["backdrop"])
	var flat := PackedFloat32Array()  # level ground the whole way: the arena's own heights are hills
	flat.resize(ArenaGen.RIGHT_WALL - ArenaGen.FIRST_COL)
	var cells := ArenaGen.build(rng, flat)
	for cell: Vector2i in cells.keys():  # only the floor: no props of the arena's chunks, which stand where the wizards do
		if cell.y < ArenaGen.GROUND_ROW and cell.x > ArenaGen.LEFT_WALL and cell.x < ArenaGen.RIGHT_WALL:
			cells.erase(cell)
	var ground := Terrain.new()
	add_child(ground)
	ground.build(cells, "church", rng, false)  # bare: a hooded statue among them would pass for a fifth wizard
	_camera = Camera2D.new()
	_camera.position = Vector2(30.0, FLOOR_Y - 80.0)
	_camera.zoom = Vector2(1.5, 1.5)
	_camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(_camera)


## The pile of pages on the floor, with a glow over it.
func _build_pile(rng: RandomNumberGenerator) -> void:
	_halo = Node2D.new()
	_halo.material = Fx.additive()
	_halo.z_index = 1
	_halo.draw.connect(func() -> void:
		var breathe := 1.0 + 0.06 * sin(_t * 3.0)
		if not _pile.is_empty():
			Fx.draw_glow(_halo, Vector2(PILE_X, FLOOR_Y - 22.0), 90.0 * breathe, Color(GOLD.r, GOLD.g, GOLD.b, 0.22))
			Fx.draw_glow(_halo, Vector2(PILE_X, FLOOR_Y - 14.0), 44.0 * breathe, Color(GOLD.r, GOLD.g, GOLD.b, 0.35)))
	add_child(_halo)
	for i in PAGES_IN_PILE:
		var page := Sprite2D.new()
		page.texture = PAGE
		page.offset = Vector2(0.0, -PAGE.get_height() * 0.5)
		page.position = Vector2(PILE_X + rng.randf_range(-30.0, 30.0), FLOOR_Y - 2.0 - float(i) * 0.55)
		page.rotation = rng.randf_range(-1.35, 1.35)
		page.modulate = Color(0.9 + rng.randf() * 0.1, 0.85 + rng.randf() * 0.1, 0.8)
		page.z_index = 1
		add_child(page)
		_pile.append(page)


## The four wizards, each from its own frames, standing and facing the pile.
func _build_wizards() -> void:
	for entry: Dictionary in WIZARDS:
		var body := Node2D.new()
		body.position = Vector2(entry["from"], FLOOR_Y)
		body.z_index = 2
		var sprite := AnimatedSprite2D.new()
		var art: String = entry["art"]
		var player := art.begins_with("wizard")
		sprite.sprite_frames = CharFrames.build("res://art/chars/" + art, PLAYER_FRAMES.ANIMATIONS if player else Mob.WIZARD_ANIMATIONS)
		var look: String = "wizard" if player else art
		sprite.offset = Vector2(0.0, -PixelArt.CHARACTERS[look]["size"].y * 0.5)
		sprite.scale = Vector2.ONE * (1.0 if player else float(Mob.KINDS[art].scale))
		sprite.flip_h = entry["from"] > PILE_X
		sprite.play("idle")
		sprite.set_meta("player", player)
		body.add_child(sprite)
		add_child(body)
		_wizards.append(body)


func _build_portal() -> void:
	_portal = Portal.new()
	_portal.position = Vector2(PORTAL_X, FLOOR_Y - Portal.RY - 4.0)
	add_child(_portal)
	_portal.open()
	Sfx.play("portal_open", _portal.global_position, -6.0)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_caption = Label.new()
	_caption.theme_type_variation = &"Outlined"
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_color", Color("#f2e6c4"))
	_caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.anchor_left = 0.0
	_caption.anchor_right = 1.0
	_caption.offset_left = 40.0
	_caption.offset_right = -40.0
	_caption.offset_top = -130.0
	_caption.offset_bottom = -70.0
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.modulate.a = 0.0
	layer.add_child(_caption)
	_hint = Label.new()
	_hint.theme_type_variation = &"Outlined"
	_hint.text = "Press any key to skip"
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.8, 0.78, 0.9, 0.7))
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -260.0
	_hint.offset_top = -40.0
	_hint.offset_right = -20.0
	_hint.offset_bottom = -12.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.visible = false
	layer.add_child(_hint)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_black)


# --- The story ----------------------------------------------------------------------------------------------------


## Fades the black over everything to this much (0 clear, 1 black).
func _fade(to: float, seconds: float) -> void:
	create_tween().tween_property(_black, "color:a", to, seconds)


## Changes the words at the bottom of the screen: the old ones fade out, the new ones fade in.
func _say(text: String) -> void:
	var tween := create_tween()
	tween.tween_property(_caption, "modulate:a", 0.0, 0.25)
	if text != "":
		tween.tween_callback(func() -> void: _caption.text = text)
		tween.tween_property(_caption, "modulate:a", 1.0, 0.4)


## A wizard's frames, by what it is doing: the player's wizard and the others name some of their animations differently.
func _anim(wizard: Node2D, what: String) -> String:
	var player: bool = wizard.get_child(0).get_meta("player")
	match what:
		"run":
			return "run" if player else "walk"
		"grab":
			return "release" if player else "burst"
	return what


func _play(wizard: Node2D, what: String, facing: float) -> void:
	var sprite: AnimatedSprite2D = wizard.get_child(0)
	sprite.flip_h = facing < 0.0
	sprite.play(_anim(wizard, what))


## Runs a wizard to a spot on the floor at a speed, then stands it facing a way.
func _run_to(wizard: Node2D, x: float, face: float, speed: float, then := "idle") -> Tween:
	_play(wizard, "run", signf(x - wizard.position.x))
	var tween := create_tween()
	tween.tween_property(wizard, "position:x", x, absf(x - wizard.position.x) / speed)
	tween.tween_callback(_play.bind(wizard, then, face))
	return tween


func _wizards_run_to_pile() -> void:
	for i in _wizards.size():
		var to: float = WIZARDS[i]["to"]
		_run_to(_wizards[i], to, signf(PILE_X - to), WALK)


## Four pairs of hands in one pile: the pages fly up, most of them toward the portal, and each wizard keeps one.
func _scuffle() -> void:
	_shake = 1.0
	Sfx.play("push", Vector2(PILE_X, FLOOR_Y), -2.0)
	Fx.burst(self, Vector2(PILE_X, FLOOR_Y - 20.0), GOLD, 22, 220.0, 0.6, true)
	for i in _wizards.size():
		var wizard := _wizards[i]
		var away: float = -signf(PILE_X - wizard.position.x)
		_play(wizard, "grab", -away)
		var tween := create_tween()
		tween.tween_interval(0.25)
		tween.tween_callback(_play.bind(wizard, "hit", -away))
		tween.tween_property(wizard, "position:x", wizard.position.x + away * 16.0, 0.25).set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.5)
		tween.tween_callback(_play.bind(wizard, "idle", -away))
	var keep := range(_pile.size())
	keep.shuffle()
	var kept: Array = keep.slice(0, KEPT)
	for i in _pile.size():
		var page := _pile[i]
		if kept.has(i):
			_keep(page, _wizards[kept.find(i)])
		else:
			_throw(page, i)
	_pile.clear()


## A page is knocked toward the portal in an arc, and goes in.
func _throw(page: Sprite2D, index: int) -> void:
	var start := page.position
	var end := _portal.position + Vector2(0.0, -4.0)
	var seconds := 1.1 + randf() * 0.9
	var arc := 90.0 + randf() * 150.0
	var spin := randf_range(-9.0, 9.0)
	var trail := Fx.trail(GOLD, 10, 0.4, 20.0, Vector2.ZERO, "star_04", 6.0)
	page.add_child(trail)
	var tween := create_tween()
	tween.tween_interval(randf() * 0.35)
	tween.tween_method(func(k: float) -> void:
		page.position = start.lerp(end, k) + Vector2(0.0, -sin(k * PI) * arc)
		page.rotation += spin * get_process_delta_time(), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_swallowed.bind(page))


## The portal takes a page: it shrinks into the ring and the ring flares.
func _swallowed(page: Sprite2D) -> void:
	Sfx.play("pickup", _portal.global_position, -14.0)
	Fx.burst(self, _portal.position, Color("#c8a8ff"), 8, 110.0, 0.4, true)
	_portal.modulate = Color(1.6, 1.4, 1.9)
	create_tween().tween_property(_portal, "modulate", Color.WHITE, 0.25)
	page.queue_free()


## A page a wizard keeps: it rises from the pile to hover over their head and goes with them.
func _keep(page: Sprite2D, wizard: Node2D) -> void:
	var start := page.global_position
	page.get_parent().remove_child(page)
	wizard.add_child(page)
	page.global_position = start
	page.rotation = 0.0
	var tween := create_tween()
	tween.tween_property(page, "position", Vector2(0.0, -150.0), 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(page, "modulate", Color(1.3, 1.2, 0.9), 0.9)
	var glow := Fx.trail(GOLD, 14, 1.0, 25.0, Vector2(0, -12), "star_04", 7.0)
	glow.local_coords = true
	glow.position = Vector2(0.0, -PAGE.get_height() * 0.5)
	page.add_child(glow)


func _wizards_run_to_portal() -> void:
	for wizard in _wizards:
		var tween := _run_to(wizard, PORTAL_X, 1.0, RUN, "run")
		tween.tween_callback(Sfx.play.bind("portal_enter", _portal.global_position, -8.0))
		tween.tween_property(wizard, "modulate:a", 0.0, 0.25)


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	finished.emit()
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)

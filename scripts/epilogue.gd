class_name Epilogue
extends Node2D

## The cut-scene after a win, in the waiting room's place. The last wizard standing carries the torn book back to its stand, sets it down, and
## nails a second plaque under the first, which says what they think of the whole business: the camera comes close on the stand, and a hammer drives
## the plaque in and then cuts the words into it. Then it is back to the waiting room. Any key skips it.

signal finished  # the scene is over, and the next one is about to load

const ROOM := "res://scenes/lab.tscn"
const FLOOR_Y := float(ArenaGen.GROUND_Y)
const STAND_X := 0.0
const WINNER_FROM := -520.0
const WINNER_AT := -78.0  # where the winner stands to work at the stand: just in reach of its face
const RUN := 330.0
const BLOWS := [3.6, 4.3, 5.0, 5.7]  # when the hammer comes down: the first drives the plaque in, and each of the rest cuts some of the words
const LETTERS := [0, 4, 8, 11]  # how many of the letters are cut by then
const HAMMER := preload("res://art/props/hammer.png")  # FacadeGaikan's iron hammer: head at the top left, handle running down to the right
const HAMMER_SCALE := 1.0
const HAMMER_GRIP := Vector2(31.0, 29.0)  # the end of the handle, in its picture: where a hand holds it, and what it swings about
const HAMMER_HEAD := Vector2(9.0, 9.0)    # the middle of its head
const HAMMER_STRUCK := 2.4  # turned so the handle lies level, running out to the left over the winner's side, with the head on the plaque
const HAMMER_RAISED := HAMMER_STRUCK - 0.6  # and turned back to lift the head
const END := 11.5  # seconds

static var winner_look := "wizard"  # set before the scene loads: which wizard won
static var winner_palette := 0  # and the colours they wore

var next_scene := ROOM  # empty to stay on when it is over (a test does that)
var look := ""  # who won; if it is not set, whoever World left in winner_look
var palette := -1  # in what colours; if it is not set, what World left in winner_palette
var plaque: Node2D  # the second plaque, once it is up
var _t := 0.0
var _cues: Array = []
var _leaving := false
var _camera: Camera2D
var _shot_tween: Tween
var _black: ColorRect
var _hint: Label
var _lectern: Lectern
var _winner: Node2D
var _sprite: AnimatedSprite2D
var _carried: Sprite2D  # the book, floating beside the winner
var _carried_aura: BookAura  # its glow and smoke, which go where it goes
var _hammer: Sprite2D
var _face := 1.0


func _ready() -> void:
	if look == "":
		look = winner_look
	if palette < 0:
		palette = winner_palette
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	Hall.build(self, rng)
	_lectern = Lectern.new()
	_lectern.position = Vector2(STAND_X, FLOOR_Y)
	_lectern.monitoring = false
	add_child(_lectern)
	_lectern.book.visible = false  # the book is not on its stand: it is in the winner's keeping
	_lectern.quiet()
	_build_winner()
	_carried = Sprite2D.new()
	_carried.texture = Lectern.BOOK
	_carried.scale = Vector2.ONE * Lectern.BOOK_SCALE
	_carried.offset = Vector2(0.0, -Lectern.BOOK.get_height() * 0.5)
	_carried.z_index = 3
	_carried.modulate = Color(1.2, 1.0, 1.35)
	_carried.position = _winner.position + _carried_rest()
	add_child(_carried)
	_carried_aura = BookAura.new()
	_carried_aura.z_index = 2  # behind the book, not over its face
	add_child(_carried_aura)
	_camera = Camera2D.new()
	_camera.position = Vector2(WINNER_FROM + 80.0, FLOOR_Y - 70.0)
	_camera.zoom = Vector2(2.5, 2.5)
	_camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(_camera)
	_build_overlay()
	_cue(0.0, func() -> void: _fade(0.0, 0.7))
	_cue(0.2, _walk_in)
	_cue(1.0, _shot.bind(Vector2(STAND_X - 40.0, FLOOR_Y - 75.0), 2.5, 1.2))
	_cue(2.2, _set_the_book_down)
	_cue(2.9, _shot.bind(Vector2(STAND_X + 6.0, FLOOR_Y - 32.0), 5.0, 0.9))  # in close on the face of the stand, where the work is done
	_cue(3.0, _bring_the_hammer)
	for k in BLOWS.size():
		_cue(BLOWS[k], _strike.bind(k))
	_cue(BLOWS[-1] + 0.4, _lift_the_hammer)
	_cue(END - 1.0, func() -> void: _fade(1.0, 0.9))
	_cue(END, _leave)
	_cues.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


func _cue(seconds: float, action: Callable) -> void:
	_cues.append([seconds, action])


func _process(delta: float) -> void:
	_t += delta
	while not _cues.is_empty() and _cues[0][0] <= _t:
		_cues.pop_front()[1].call()
	if is_instance_valid(_carried) and not _carried.has_meta("set"):
		var follow := 1.0 - exp(-5.0 * delta)  # it trails a little behind them, as a flare does
		_carried.position = _carried.position.lerp(_winner.position + _carried_rest(), follow)
	if is_instance_valid(_carried_aura):
		_carried_aura.position = _carried.position + Vector2(0.0, -Lectern.book_height() * 0.5)
	_hint.visible = _t > 1.0 and not _leaving


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or not (event is InputEventKey or event is InputEventMouseButton) or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	_cues.clear()
	_fade(1.0, 0.3)
	_cue(_t + 0.3, _leave)


## Where the book hangs beside the winner: up by their shoulder, bobbing as it floats.
func _carried_rest() -> Vector2:
	return Vector2(36.0 * _face + sin(_t * 1.7) * 4.0, -64.0 + sin(_t * 3.0) * 5.0)


## The winner, in whatever look they had in the match.
func _build_winner() -> void:
	var art := "wizard"
	var size := 1.0
	if look != "wizard":
		var data: MobKind = Mob.KINDS[look]
		art = data.art
		size = WizardLook.scale_of(look, data.scale)
	_winner = Node2D.new()
	_winner.position = Vector2(WINNER_FROM, FLOOR_Y)
	_winner.z_index = 2
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = CharFrames.build("res://art/chars/" + art, Wizard.ANIMATIONS)
	_sprite.offset = Vector2(0.0, -PixelArt.CHARACTERS[art]["size"].y * 0.5)
	_sprite.scale = Vector2.ONE * size
	_sprite.material = WizardLook.material_for(look, palette)
	_sprite.play("idle")
	_winner.add_child(_sprite)
	add_child(_winner)


func _walk_in() -> void:
	_face = 1.0
	_sprite.flip_h = false
	_sprite.play("run")
	var tween := create_tween()
	tween.tween_property(_winner, "position:x", WINNER_AT, (WINNER_AT - WINNER_FROM) / RUN)
	tween.tween_callback(func() -> void: _sprite.play("idle"))


## The book floats from the winner's side to its place on the stand, and settles there with its glow.
func _set_the_book_down() -> void:
	_carried.set_meta("set", true)
	var top := _lectern.global_position + Vector2(0.0, -Lectern.STAND.get_height() + Lectern.BOOK_FOOT * Lectern.BOOK_SCALE)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_carried, "position", top, 0.7)
	tween.tween_callback(func() -> void:
		_carried.queue_free()
		_carried_aura.queue_free()
		_lectern.book.visible = true
		_lectern.wake()
		Sfx.play("book_close", top)
		Fx.burst(self, top + Vector2(0.0, -30.0), Color("#b070ff"), 24, 110.0, 0.8, true)
		Fx.smoke(self, top, Color(0.5, 0.2, 0.75, 0.7), 10, 30.0, 50.0))
	Sfx.play("summon", top, -8.0)


## The hammer comes in from the side, held up over the stand. Nobody is seen holding it.
func _bring_the_hammer() -> void:
	_hammer = Sprite2D.new()
	_hammer.texture = HAMMER
	_hammer.scale = Vector2.ONE * HAMMER_SCALE
	_hammer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # a turned pixel picture stays crisp
	_hammer.offset = Vector2(HAMMER.get_size()) * 0.5 - HAMMER_GRIP  # it turns about the end of its handle
	_hammer.position = _hammer_grip()
	_hammer.rotation = HAMMER_RAISED
	_hammer.z_index = 5
	_hammer.modulate.a = 0.0
	add_child(_hammer)
	create_tween().tween_property(_hammer, "modulate:a", 1.0, 0.3)


## Where the end of the handle is held while the head is over the plaque: up and to the left of it.
func _hammer_grip() -> Vector2:
	return _target() - (HAMMER_HEAD - HAMMER_GRIP).rotated(HAMMER_STRUCK) * HAMMER_SCALE


## Where the head of the hammer comes down: on the second plaque.
func _target() -> Vector2:
	return _lectern.global_position + Lectern.SECOND_PLAQUE_AT + Vector2(0.0, -4.0)


## One blow. The first drives the plaque in; each after it cuts some of the words.
func _strike(blow: int) -> void:
	var swing := create_tween()
	swing.tween_property(_hammer, "rotation", HAMMER_STRUCK, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	swing.tween_callback(func() -> void:
		var at := _target()
		Sfx.play("stones_2" if blow == BLOWS.size() - 1 else "stones_1", at, -2.0)
		Fx.burst(self, at, Color("#ffd890"), 20 if blow == BLOWS.size() - 1 else 10, 120.0, 0.3, true)
		_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 2.0
		get_tree().create_timer(0.08).timeout.connect(func() -> void: _camera.offset = Vector2.ZERO)
		if blow == 0:
			plaque = _lectern.hang_second_plaque()
			plaque.scale = Vector2.ONE * 1.4
			create_tween().tween_property(plaque, "scale", Vector2.ONE, 0.12)
			Sfx.play("pickup", at)
		else:
			_lectern.second_words.visible_characters = LETTERS[blow])
	swing.tween_interval(0.06)
	swing.tween_property(_hammer, "rotation", HAMMER_RAISED, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _lift_the_hammer() -> void:
	var gone := create_tween()
	gone.tween_property(_hammer, "modulate:a", 0.0, 0.4)
	gone.tween_callback(_hammer.queue_free)


func _shot(at: Vector2, zoom: float, seconds: float) -> void:
	if _shot_tween != null:
		_shot_tween.kill()
	_shot_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shot_tween.tween_property(_camera, "position", at, seconds)
	_shot_tween.tween_property(_camera, "zoom", Vector2(zoom, zoom), seconds)


func _fade(to: float, seconds: float) -> void:
	create_tween().tween_property(_black, "color:a", to, seconds)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
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


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	finished.emit()
	if next_scene != "":
		World.next_seed = -1
		get_tree().change_scene_to_file(next_scene)

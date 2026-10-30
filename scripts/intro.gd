class_name Intro
extends Node2D

## The cut-scene between the waiting room and a world. In a cathedral hall a portal lies open in the ceiling, over a pile of pages, and it is
## coming apart: it flickers, spits violet bolts and shakes the hall. Four wizards walk in and square up round the pile, and each draws on the
## others. The portal surges at its worst moment; they open fire, the pages are shaken loose and go up into the portal, and the portal tears
## wide and pulls all four of them up into it, still fighting it. The same scene plays whether the other three wizards are AI or real players. Any key skips it.

signal finished  # the scene is over, and the next one is about to load

const LOADING := "res://scenes/loading.tscn"
const PAGE := preload("res://art/props/page.png")
const FLOOR_Y := float(ArenaGen.GROUND_Y)
const PILE_X := -20.0
const PORTAL_X := -20.0  # the portal is in the ceiling, right over the pile
const PORTAL_HEIGHT := 285.0  # how far over the floor
const PAGES_IN_PILE := 26
const PAGE_SCALE := 0.4  # a page is about as big as a hand
const CRACKLE_COLOUR := Color(0.55, 0.25, 1.0)  # the portal's violet
const SPELL_COLOURS := [Color("#b080ff"), Color("#ff4a4a"), Color("#e8e0c0"), Color("#ff9a3a")]  # the glow of each wizard's magic
const GOLD := Color("#ffe9a0")
const SKIP_HINT_AFTER := 1.0
## Each wizard: the folder of its frames, where it starts and where it stands in the ring round the pile (two on each side).
const WIZARDS := [
	{"art": "wizard", "from": -520.0, "to": -230.0},
	{"art": "dark_wizard", "from": -470.0, "to": -120.0},
	{"art": "bone_wizard", "from": 480.0, "to": 80.0},
	{"art": "pyre_wizard", "from": 540.0, "to": 190.0},
]
const WALK := 170.0  # pixels a second, walking in
const RUN := 260.0   # and being pulled to the portal
const FLYING_IN := [  # what the tearing portal drags in from beyond the edges of the view: creatures (a mob's id) and things from the world (a prop's name)
	{"mob": "giant"}, {"mob": "basic"}, {"mob": "basic"}, {"mob": "fire_flyer"}, {"mob": "fire_flyer"}, {"mob": "ice_ranged"}, {"mob": "ninja"},
	{"prop": "barrel"}, {"prop": "crate"}, {"prop": "grave_1"}, {"prop": "grave_3"}, {"prop": "bush_large"}, {"prop": "dead_tree_2"}, {"prop": "church_column"},
]
const END := 12.8  # seconds, from the first frame to the world

var next_scene := LOADING  # set before it enters the tree; empty to stay on when it is over (a test does that)
var _t := 0.0
var _unrest := 0.6  # how unstable the portal is: 0 to 1, and it grows when the pages go through
var _crackle := 0.0
var _portal_home := Vector2.ZERO
var _cues: Array = []  # [seconds, Callable], in order
var _wizards: Array[Node2D] = []
var _pile: Array[Sprite2D] = []
var _portal: Portal
var _camera: Camera2D
var _hint: Label
var _black: ColorRect
var _shake := 0.0
var _leaving := false
var _halo: Node2D
var _white: ColorRect


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	_build_hall(rng)
	_build_pile(rng)
	_build_wizards()
	_build_portal()
	_build_overlay()
	_cue(0.0, func() -> void: _fade(0.0, 0.8))
	for at in [1.2, 2.8, 4.1]:  # the portal is never still: it surges now and then, and everyone in the hall flinches
		_cue(at, _pulse.bind(0.5))
	_cue(0.5, _wizards_walk_in)
	for k in 4:  # each draws on the others, one after another
		_cue(4.2 + k * 0.35, _draw_on_the_others.bind(k))
	_cue(5.6, _the_hall_cracks)
	var shots := [[1, 2, 6.4], [2, 1, 6.85], [0, 3, 7.3], [3, 0, 7.6], [1, 3, 8.0], [2, 0, 8.25], [0, 2, 8.55], [3, 1, 8.8]]
	for shot: Array in shots:
		_cue(shot[2], _shoot.bind(shot[0], shot[1]))
	_cue(6.0, _pile_goes_up)
	_cue(9.4, _the_portal_tears)
	_cue(9.6, _things_fly_in)
	_cue(11.4, func() -> void: _fade(1.0, 0.9))
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
	_destabilise(delta)


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
	_camera.position = Vector2(PILE_X, FLOOR_Y - 90.0)
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
		page.scale = Vector2.ONE * PAGE_SCALE
		page.position = Vector2(PILE_X + rng.randf_range(-16.0, 16.0), FLOOR_Y - 1.0 - float(i) * 0.4)
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
		sprite.sprite_frames = CharFrames.build("res://art/chars/" + art, Wizard.ANIMATIONS if player else Wizard.LOOK_ANIMATIONS)
		var look: String = "wizard" if player else art
		sprite.offset = Vector2(0.0, -PixelArt.CHARACTERS[look]["size"].y * 0.5)
		sprite.scale = Vector2.ONE * (1.0 if player else float(Mob.KINDS[art].scale))
		sprite.flip_h = entry["from"] > PILE_X
		sprite.play("idle")
		body.add_child(sprite)
		body.set_meta("face", -1.0 if entry["from"] > PILE_X else 1.0)
		add_child(body)
		_wizards.append(body)


func _build_portal() -> void:
	_portal = Portal.new()
	_portal.position = Vector2(PORTAL_X, FLOOR_Y - PORTAL_HEIGHT)
	_portal.rotation = PI * 0.5  # lying flat in the ceiling, so nobody can walk past it
	_portal_home = _portal.position
	add_child(_portal)
	_portal.open()
	Sfx.play("portal_open", _portal.global_position, -6.0)


## The portal is growing unstable: it shakes, and bolts of its own violet light crack out of it, more of them once the pages go through.
func _destabilise(delta: float) -> void:
	if _portal == null or _leaving:
		return
	_portal.position = _portal_home + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _unrest * 3.0
	_crackle -= delta
	if _crackle > 0.0:
		return
	_crackle = lerpf(0.5, 0.12, _unrest) * randf_range(0.6, 1.4)
	var bolt := AnimatedSprite2D.new()
	bolt.sprite_frames = PixelFx.frames("lightning", 24.0, false)
	bolt.material = Fx.additive()
	bolt.modulate = CRACKLE_COLOUR
	bolt.scale = Vector2.ONE * randf_range(0.5, 0.9)
	bolt.offset = Vector2(0.0, -100.0)  # the bolt leaves from the portal, down into the hall
	bolt.rotation = randf_range(PI - 1.1, PI + 1.1)
	bolt.position = _portal.position
	bolt.z_index = 2
	bolt.animation_finished.connect(bolt.queue_free)
	add_child(bolt)
	bolt.play("default")
	if randf() < 0.4:
		Sfx.play("thunder", _portal.position, -24.0)


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
	_white = ColorRect.new()  # a flash of white when the portal tears
	_white.color = Color(1, 1, 1, 0.0)
	_white.set_anchors_preset(Control.PRESET_FULL_RECT)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_white)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_black)


# --- The story ----------------------------------------------------------------------------------------------------


## Fades the black over everything to this much (0 clear, 1 black).
func _fade(to: float, seconds: float) -> void:
	create_tween().tween_property(_black, "color:a", to, seconds)


func _play(wizard: Node2D, what: String, facing: float) -> void:
	var sprite: AnimatedSprite2D = wizard.get_child(0)
	wizard.set_meta("face", facing)
	sprite.flip_h = facing < 0.0
	sprite.play("release" if what == "grab" else what)  # (grabbing is the thrust of the staff)


## Runs a wizard to a spot on the floor at a speed, then stands it facing a way.
func _run_to(wizard: Node2D, x: float, face: float, speed: float, then := "idle") -> Tween:
	_play(wizard, "run", signf(x - wizard.position.x))
	var tween := create_tween()
	tween.tween_property(wizard, "position:x", x, absf(x - wizard.position.x) / speed)
	tween.tween_callback(_play.bind(wizard, then, face))
	return tween


## Where a wizard's staff is, for a spark or a bolt.
func _staff(index: int) -> Vector2:
	var wizard := _wizards[index]
	return wizard.position + Vector2(float(wizard.get_meta("face")) * 38.0, -62.0)


## The portal surges: it flares, the hall shakes, and everyone flinches from it.
func _pulse(power: float) -> void:
	_shake = maxf(_shake, power)
	_portal.modulate = Color(1.0 + power, 0.9 + power * 0.6, 1.2 + power)
	create_tween().tween_property(_portal, "modulate", Color.WHITE, 0.45)
	Sfx.play("thunder", _portal.global_position, -16.0 + power * 6.0)
	Fx.burst(self, _portal.position, CRACKLE_COLOUR, 10, 160.0, 0.5, true)
	for i in _wizards.size():
		if absf(_wizards[i].position.x - float(WIZARDS[i]["to"])) < 4.0:  # the ones who have walked in
			_flinch(_wizards[i])


func _flinch(wizard: Node2D) -> void:
	var face: float = wizard.get_meta("face")
	_play(wizard, "hit", face)
	var tween := create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(_play.bind(wizard, "idle", face))


## Two wizards in from the left, two from the right, to stand in a ring round the pile under the portal, each looking at the others.
func _wizards_walk_in() -> void:
	for i in _wizards.size():
		var to: float = WIZARDS[i]["to"]
		_run_to(_wizards[i], to, 1.0 if to < PILE_X else -1.0, WALK)


## A wizard raises their staff at the others: their own colour gathers on it, and they hold the pose.
func _draw_on_the_others(index: int) -> void:
	var wizard := _wizards[index]
	var face: float = wizard.get_meta("face")
	_play(wizard, "grab", face)
	Sfx.play("push", wizard.position, -14.0)
	Fx.burst(self, _staff(index), SPELL_COLOURS[index], 14, 120.0, 0.5, true)
	var glow := Fx.trail(SPELL_COLOURS[index], 12, 0.6, 20.0, Vector2(0, -20), "star_04", 6.0)  # it keeps crackling there
	glow.position = Vector2(face * 38.0, -62.0)
	glow.local_coords = true
	wizard.add_child(glow)


## The portal cracks the hall at its worst: a surge that throws every wizard's hand up and shakes the pile.
func _the_hall_cracks() -> void:
	_unrest = 0.85
	_pulse(1.0)
	_shake = 1.2
	Fx.burst(self, Vector2(PILE_X, FLOOR_Y - 10.0), GOLD, 16, 200.0, 0.6, true)


## The pile's pages lift off the floor and hang there, shaking, drawn up toward the portal.
func _pile_goes_up() -> void:
	for page in _pile:
		var tween := create_tween()
		tween.tween_property(page, "position", page.position + Vector2(randf_range(-26.0, 26.0), -randf_range(24.0, 70.0)), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## One wizard hits another with a bolt of their own colour.
func _shoot(from_index: int, to_index: int) -> void:
	var from_at := _staff(from_index)
	var to_wizard := _wizards[to_index]
	var to_at := to_wizard.position + Vector2(0.0, -55.0)
	var colour: Color = SPELL_COLOURS[from_index]
	_play(_wizards[from_index], "grab", signf(to_at.x - from_at.x))
	Sfx.play("push", from_at, -6.0)
	var bolt := Node2D.new()
	bolt.material = Fx.additive()
	bolt.z_index = 3
	bolt.position = from_at
	bolt.draw.connect(func() -> void:
		Fx.draw_glow(bolt, Vector2.ZERO, 40.0, Color(colour, 0.9))
		Fx.draw_glow(bolt, Vector2.ZERO, 16.0, Color(1, 1, 1, 0.9)))
	var trail := Fx.trail(colour, 30, 0.3, 14.0, Vector2.ZERO, "star_04", 7.0)
	trail.local_coords = false
	bolt.add_child(trail)
	add_child(bolt)
	var tween := create_tween()
	tween.tween_property(bolt, "position", to_at, 0.3)
	tween.tween_callback(_struck.bind(bolt, to_index, colour))


## A bolt lands: the wizard is thrown back and a page flies out of their hands, into the portal.
func _struck(bolt: Node2D, index: int, colour: Color) -> void:
	bolt.queue_free()
	var wizard := _wizards[index]
	var face: float = wizard.get_meta("face")
	_shake = maxf(_shake, 0.8)
	_unrest = minf(_unrest + 0.04, 1.0)
	Sfx.play("player_hurt" if index == 0 else "mob_hurt", wizard.position, -4.0)
	Fx.burst(self, wizard.position + Vector2(0.0, -55.0), colour, 16, 190.0, 0.5, true)
	_play(wizard, "hit", face)
	var tween := create_tween()
	tween.tween_property(wizard, "position:x", wizard.position.x - face * 22.0, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.25)
	tween.tween_callback(_play.bind(wizard, "grab", face))
	for k in 3:  # the shock shakes pages loose from the pile, and the portal takes them
		if not _pile.is_empty():
			var page: Sprite2D = _pile.pop_back()
			create_tween().tween_callback(_throw.bind(page, 0)).set_delay(0.12 * k)


## A page is knocked toward the portal in an arc, and goes in.
func _throw(page: Sprite2D, _index: int) -> void:
	var start := page.position
	var end := _portal.position + Vector2(0.0, -4.0)
	var seconds := 0.7 + randf() * 0.5
	var arc := 20.0 + randf() * 50.0
	var spin := randf_range(-9.0, 9.0)
	var trail := Fx.trail(GOLD, 10, 0.4, 20.0, Vector2.ZERO, "star_04", 6.0)
	page.add_child(trail)
	var tween := create_tween()
	tween.tween_method(func(k: float) -> void:
		page.position = start.lerp(end, k) + Vector2(0.0, -sin(k * PI) * arc)
		page.rotation += spin * get_process_delta_time(), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_swallowed.bind(page))


## The portal takes a page: it shrinks into the ring and the ring flares.
func _swallowed(page: Node2D) -> void:
	Sfx.play("pickup", _portal.global_position, -14.0)
	Fx.burst(self, _portal.position, Color("#c8a8ff"), 8, 110.0, 0.4, true)
	_portal.modulate = Color(1.6, 1.4, 1.9)
	create_tween().tween_property(_portal, "modulate", Color.WHITE, 0.25)
	page.queue_free()


## The portal tears wide open. The pile that is left is dragged up into it, and the four wizards, fighting it, are lifted off their feet and pulled in after it.
func _the_portal_tears() -> void:
	_unrest = 1.0
	_shake = 1.6
	Sfx.play("thunder", _portal.global_position, -2.0)
	Sfx.play("portal_open", _portal.global_position, -2.0)
	create_tween().tween_property(_portal, "scale", Vector2.ONE * 2.2, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var flash := create_tween()
	flash.tween_property(_white, "color:a", 0.75, 0.1)
	flash.tween_property(_white, "color:a", 0.0, 0.6)
	for i in _pile.size():  # whatever is hanging in the air goes first
		var tween := create_tween()
		tween.tween_interval(randf() * 0.5)
		tween.tween_callback(_throw.bind(_pile[i], i))
	_pile.clear()
	for i in _wizards.size():
		var wizard := _wizards[i]
		var tween := create_tween()
		tween.tween_interval(0.5 + i * 0.12)
		tween.tween_callback(_play.bind(wizard, "hit", float(wizard.get_meta("face"))))  # off their feet
		tween.tween_property(wizard, "position", _portal.position + Vector2(0.0, 40.0), 1.5 - i * 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tween.tween_callback(Sfx.play.bind("portal_enter", _portal.global_position, -8.0))
		tween.tween_property(wizard, "scale", Vector2.ONE * 0.2, 0.25)
		tween.parallel().tween_property(wizard, "modulate:a", 0.0, 0.25)


## Creatures and things from all over the world are torn loose and dragged in from beyond the edges of the view, tumbling up into the portal.
func _things_fly_in() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in FLYING_IN.size():
		var entry: Dictionary = FLYING_IN[k]
		var sprite: Node2D
		var size := 1.0
		if entry.has("mob"):
			var kind: MobKind = Mob.KINDS[entry["mob"]]
			var animated := AnimatedSprite2D.new()
			animated.sprite_frames = CharFrames.build("res://art/mobs/" + kind.art, Mob.CREATURE_ANIMATIONS)
			animated.play("idle")
			sprite = animated
			size = float(kind.scale)
		else:
			var picture := Sprite2D.new()
			picture.texture = load("res://art/props/%s.png" % entry["prop"])
			sprite = picture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2.ONE * size
		sprite.set_meta("size", size)
		sprite.z_index = 1
		var side := -1.0 if k % 2 == 0 else 1.0
		sprite.position = Vector2(PILE_X + side * rng.randf_range(420.0, 520.0), FLOOR_Y + rng.randf_range(-260.0, 60.0))
		add_child(sprite)
		var tween := create_tween()
		tween.tween_interval(rng.randf_range(0.0, 1.5))
		tween.tween_method(_fly.bind(sprite, sprite.position, rng.randf_range(-6.0, 6.0), rng.randf_range(30.0, 90.0)), 0.0, 1.0, rng.randf_range(0.9, 1.4) + size * 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(_swallowed.bind(sprite))


## One step of something's flight: along a curve to the portal, turning over as it goes and shrinking as it nears.
func _fly(k: float, sprite: Node2D, start: Vector2, spin: float, arc: float) -> void:
	if not is_instance_valid(sprite):
		return
	var end := _portal.position
	sprite.position = start.lerp(end, k) + Vector2(0.0, -sin(k * PI) * arc)
	sprite.rotation = spin * k
	sprite.modulate.a = clampf((1.0 - k) * 6.0, 0.0, 1.0)
	sprite.scale = Vector2.ONE * lerpf(1.0, 0.3, k) * float(sprite.get_meta("size"))


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	finished.emit()
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)

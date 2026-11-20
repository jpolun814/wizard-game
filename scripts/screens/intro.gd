class_name Intro
extends CutScene

## The cut-scene between the waiting room and a world. It opens on one wizard, whoever is watching, running through a cathedral hall at night to
## the spellbook, bound and glowing, hanging over the floor of the hall. Other wizards arrive, sixteen in all, each in a color of its own, and every one
## of them reaches for it. The pull of so many tears it apart: its pages burst loose and, with the book unbound, a portal opens in the ceiling and
## begins to come apart. They fight for the pages: bolts meet in the air and burst, and the blasts of those that land knock the pages about, and
## the portal takes the ones that are thrown high. Wizards fall one after another until the eight of the match are left. Then the portal tears wide and pulls those eight
## up into it, still firing at one another as they are lifted, in a bloom of light.
## The camera runs beside the first wizard, pulls back to show the ring, cuts in close on the duel, and looks up at the tear.
## The same scene plays whether the other seven wizards are AI or real players: on each machine the first wizard is the person at it. Any key skips it.

const LOADING := "res://scenes/loading.tscn"
const PAGE := preload("res://art/props/page.png")
const FLOOR_Y := float(ArenaGen.GROUND_Y)
const PILE_X := -16.0
const PORTAL_X := -16.0  # the portal is in the ceiling, right over the pile
const PILE_Y := FLOOR_Y - Podium.TOP_ROWS * float(Podium.TILE)  # the top of the stairs: where the book, the pages and the pedestal are
const PORTAL_HEIGHT := 260.0  # how far over the top of the stairs
const PORTAL_SCALE := 1.5  # the ring is drawn at two times its size, so this makes it three: whole pixels
const TORN_SCALE := 2.5    # and torn wide, five
const PAGES_IN_PILE := 26
const PAGE_SCALE := 0.4  # a page is about as big as a hand
const CRACKLE_COLOR := Color(0.55, 0.25, 1.0)  # the portal's violet
const GRAVITY := 760.0  # what a page falls with
const BLAST_REACH := 150.0  # how far from a blast the pages are knocked about
const FLUTTER_FALL := 70.0  # the fastest a loose page drops: it is paper, and the air holds it up
const FLUTTER_DRAG := 2.4  # how quickly the air takes the speed out of a page that has been thrown
const FLUTTER_SWAY := 190.0  # how hard it slips from side to side as it comes down
const PULL := 700.0  # how hard the portal draws at a page that has been thrown high
const PULL_HEIGHT := 150.0  # how high over the floor a page must be before it feels the portal
const TORN_PULL := 2600.0  # and once it tears, it draws at everything
const GOLD := Color("#ffe9a0")
const SKIP_HINT_AFTER := 1.0
## The sixteen wizards, in two lists. WIZARDS are the eight of the match, in the looks and colors they will wear in the world (`Net.style_of_seat`), and they are
## the ones who live to see the portal tear. EXTRAS are eight more, each a look in a set of colors no one of the match wears, and they fall in the fight.
## "to" is where it stands in the ring round the pile, "mode" how it comes (run in from the side, or blink in with a puff of light), "at" when it does, "row" how far forward it stands in the crowd, which is three deep and stands in front of the stairs (and some, "up", on the outer steps of them), so that it overlaps its neighbors, and "color" the glow
## of its magic. The first of WIZARDS is whoever is watching: it runs in from far off, and is the one the camera follows.
const WIZARDS := [
	{"color": Color("#b080ff"), "to": -196.0, "from": -1050.0, "row": 2, "mode": "run", "at": 0.00},
	{"color": Color("#d070ff"), "to": -148.0, "from": -520.0, "row": 0, "up": true, "mode": "run", "at": 1.00},
	{"color": Color("#ff4a4a"), "to": -100.0, "from": -520.0, "row": 1, "mode": "run", "at": 1.40},
	{"color": Color("#ffb040"), "to": -52.0, "from": -520.0, "row": 2, "mode": "run", "at": 1.80},
	{"color": Color("#58a8ff"), "to": 44.0, "row": 0, "mode": "blink", "at": 0.70},
	{"color": Color("#f0c040"), "to": 92.0, "row": 1, "mode": "blink", "at": 1.10},
	{"color": Color("#ff58d8"), "to": 140.0, "row": 2, "mode": "blink", "at": 1.50},
	{"color": Color("#b8ff50"), "to": 188.0, "row": 0, "up": true, "mode": "blink", "at": 1.90},
]
const EXTRAS := [
	{"color": Color("#5ae05a"), "to": -76.0, "from": -520.0, "row": 0, "mode": "run", "at": 1.60},
	{"color": Color("#38d8c8"), "to": -52.0, "from": -520.0, "row": 2, "mode": "run", "at": 1.80},
	{"color": Color("#58a8ff"), "to": 20.0, "row": 1, "mode": "blink", "at": 0.50},
	{"color": Color("#ff80b0"), "to": 44.0, "row": 0, "mode": "blink", "at": 0.70},
	{"color": Color("#ffa050"), "to": -220.0, "from": -520.0, "row": 0, "up": true, "mode": "run", "at": 0.60},
	{"color": Color("#7080ff"), "to": -148.0, "from": -520.0, "row": 0, "up": true, "mode": "run", "at": 1.00},
	{"color": Color("#40e0ff"), "to": 116.0, "row": 0, "up": true, "mode": "blink", "at": 1.30},
	{"color": Color("#c0c0d0"), "to": 188.0, "row": 0, "up": true, "mode": "blink", "at": 1.90},
]
const RUN := 330.0   # pixels a second, running in
const ROW_DEPTH := 7.0  # how much lower each row of the crowd stands than the one behind it
const WIDE := 1.4    # how far the camera is zoomed when it shows the whole ring
## The fight: when, who fires, at whom, and what comes of it. Numbers are places in `_all`: the eight of the match, then the eight more. A kill drops the wizard
## it hits for good; a hit throws one of the eight back; in a clash two bolts meet over the pile; a stray one misses and lands on the floor at x.
const FIGHT := [
	{"at": 5.4, "kind": "kill", "a": 0, "b": 8},
	{"at": 5.5, "kind": "stray", "a": 2, "x": -35.0},
	{"at": 5.6, "kind": "kill", "a": 12, "b": 13},
	{"at": 5.8, "kind": "kill", "a": 3, "b": 11},
	{"at": 5.9, "kind": "kill", "a": 14, "b": 9},
	{"at": 6.0, "kind": "stray", "a": 1, "x": 5.0},
	{"at": 6.2, "kind": "kill", "a": 4, "b": 10},
	{"at": 6.4, "kind": "kill", "a": 5, "b": 14},
	{"at": 6.6, "kind": "stray", "a": 3, "x": -25.0},
	{"at": 6.8, "kind": "kill", "a": 6, "b": 12},
	{"at": 7.0, "kind": "kill", "a": 7, "b": 15},
	{"at": 7.5, "kind": "clash", "a": 1, "b": 2},
	{"at": 7.6, "kind": "clash", "a": 5, "b": 6},
	{"at": 8.1, "kind": "hit", "a": 0, "b": 2},
	{"at": 8.2, "kind": "hit", "a": 3, "b": 4},
	{"at": 8.3, "kind": "hit", "a": 7, "b": 5},
	{"at": 8.5, "kind": "stray", "a": 2, "x": -15.0},
	{"at": 8.8, "kind": "clash", "a": 0, "b": 4},
	{"at": 8.9, "kind": "hit", "a": 6, "b": 3},
]
const END := 14.1  # seconds, from the first frame to the world

## The sounds of the shots: a real attack spell cast each time (see `_cast_sound`).
const _CASTS := [["Ignite", "cast"], ["Frostbolt", "cast"], ["Pebble", "whoosh"], ["Barbs", "whoosh"], ["Eldritch Blast", "blast"], ["Spark", "spark"]]

var _unrest := 0.6  # how unstable the portal is: 0 to 1, and it grows as the fight goes on
var _crackle := 0.0
var _portal_home := Vector2.ZERO
var _wizards: Array[IntroWizard] = []  # the eight of the match
var _extras: Array[IntroWizard] = []   # the eight more
var _all: Array[IntroWizard] = []      # the eight of the match, then the eight more
var _pile: Array[IntroPage] = []
var _portal: Portal
var _shake := 0.0
var _halo: Node2D
var _bloom: Node2D
var _bloom_k := 0.0  # how far the light of the tearing portal has spread: 0 to 1
var _lectern: Lectern
var _book: Sprite2D  # the spellbook, until it is torn apart
var _stream_k := 0.0  # how far the smoke that pours out of the torn book has reached toward where the portal will be
var _stream_from := Vector2.ZERO
var _stream: Node2D  # the strands of smoke between the book and the portal, which stay until the portal tears wide
var _plume: Tween  # and the smoke that keeps rising from where the book was
var _opened := false  # the book has come apart and the portal is open
var _torn := false  # the portal has torn, and draws at everything


func _init() -> void:
	next_scene = LOADING


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	_build_hall(rng)
	_build_pile(rng)
	_build_wizards()
	_build_portal()
	_build_overlay()
	_cue(0.0, func() -> void: _fade(0.0, 0.7))
	_follow_the_first()
	for entry: Dictionary in WIZARDS + EXTRAS:  # each comes in by its own way, at its own time
		var body: IntroWizard = _all[(WIZARDS + EXTRAS).find(entry)]
		_cue(entry["at"], _arrive.bind(body, entry))
	_cue(2.4, _pull_back)  # the first has arrived, and the shot opens out on the whole ring
	for at in [3.0, 4.6]:  # the portal is never still: it surges now and then, and everyone in the hall flinches
		_cue(at, _pulse.bind(0.4))
	for k in _all.size():  # each draws on the others, one after another
		_cue(4.9 + k * 0.035, _draw_on_the_others.bind(k))
	_cue(5.7, _the_hall_cracks)  # the book gives way only once the first shots have been fired
	for event: Dictionary in FIGHT:
		match event["kind"]:
			"clash":
				_cue(event["at"], _clash.bind(event["a"], event["b"]))
			"kill":
				_cue(event["at"], _shoot.bind(event["a"], event["b"], true))
			"stray":
				_cue(event["at"], _stray.bind(event["a"], event["x"]))
			_:
				_cue(event["at"], _shoot.bind(event["a"], event["b"], false))
	_cue(3.7, _shot.bind(Vector2(PILE_X, PILE_Y - 30.0), 6.0, 0.5))  # in close on the plaque the book stands over, while the others are still gathering and standing quiet; it stays long enough to read
	_cue(5.2, _shot.bind(Vector2(PILE_X, PILE_Y - 94.0), WIDE, 0.6))  # and out again for the fight
	_cue(10.2, _the_portal_tears)  # a beat after the camera is back out, so the whole ring is seen before it is pulled in
	for volley in [[11.0, 0, 3], [11.3, 5, 1], [11.6, 2, 6], [11.1, 4, 7], [11.4, 6, 0], [11.7, 7, 2]]:  # lifted off their feet, they are still firing at each other
		_cue(volley[0], _shoot.bind(volley[1], volley[2], false))
	_cue(12.6, func() -> void: _fade(1.0, 0.9))
	_cue(END, _leave)
	_cues.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


func _process(delta: float) -> void:
	_run_cues(delta)
	_shake = maxf(_shake - delta * 1.6, 0.0)
	_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * 4.0
	if _following != null:
		_camera.position = _camera.position.lerp(_following.position + Vector2(70.0, -80.0), minf(delta * 8.0, 1.0))
	_hint.visible = _t > SKIP_HINT_AFTER and not _leaving
	_hint.modulate.a = lerpf(1.0, 0.35, smoothstep(4.0, 6.0, _t))  # it says it once, then keeps out of the way
	_move_pages(delta)
	_halo.queue_redraw()
	_bloom.queue_redraw()
	_destabilise(delta)


# --- The set ------------------------------------------------------------------------------------------------------


## The waiting room place again, so it looks the same as the room the book was touched in: its backdrop, its floor, and a camera that starts close beside the first wizard.
func _build_hall(rng: RandomNumberGenerator) -> void:
	Hall.build(self, rng)
	_camera = Camera2D.new()
	_camera.position = Vector2(float(WIZARDS[0]["from"]) + 70.0, FLOOR_Y - 80.0)
	_camera.zoom = Vector2(3.0, 3.0)  # close: the first wizard fills a third of the height
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
			Fx.draw_glow(_halo, Vector2(PILE_X, PILE_Y - 22.0), 90.0 * breathe, Color(GOLD.r, GOLD.g, GOLD.b, 0.22))
			Fx.draw_glow(_halo, Vector2(PILE_X, PILE_Y - 14.0), 44.0 * breathe, Color(GOLD.r, GOLD.g, GOLD.b, 0.35)))
	add_child(_halo)
	for i in PAGES_IN_PILE:
		var page := IntroPage.new()
		page.texture = PAGE
		page.offset = Vector2(0.0, -PAGE.get_height() * 0.5)
		page.scale = Vector2.ONE * PAGE_SCALE
		page.position = Vector2(PILE_X + rng.randf_range(-16.0, 16.0), PILE_Y - 1.0 - float(i) * 0.4)
		page.rotation = rng.randf_range(-1.35, 1.35)
		page.modulate = Color(0.9 + rng.randf() * 0.1, 0.85 + rng.randf() * 0.1, 0.8)
		page.z_index = 1
		page.visible = false  # it is still in the book
		add_child(page)
		_pile.append(page)
	add_child(Podium.new(PILE_X, FLOOR_Y))  # the marble stairs the pedestal stands on, as in the waiting room
	_lectern = Lectern.new()  # the book the person touched in the waiting room, on the stand it stood on
	_lectern.position = Vector2(PILE_X, PILE_Y)
	_lectern.monitoring = false
	add_child(_lectern)
	_book = _lectern.book


## The sixteen wizards, each from its own frames, standing where they will arrive and facing the pile.
func _build_wizards() -> void:
	var styles := _seat_styles()
	var worn := {}  # the looks of the match, so that none of the eight more repeats one
	for k in WIZARDS.size():
		var entry: Dictionary = WIZARDS[k].duplicate()
		entry["look"] = styles[k]["look"]
		entry["palette"] = styles[k]["palette"]
		worn[entry["look"]] = true
		_wizards.append(_make_wizard(entry))
	for k in EXTRAS.size():
		var entry: Dictionary = EXTRAS[k].duplicate()
		var look := PartsLook.seeded_look(MatchState.seed_base * 977 + 4001 + k)
		while worn.has(look):
			look = PartsLook.seeded_look(look.hash() + k)
		worn[look] = true
		entry["look"] = look
		entry["palette"] = 0
		_extras.append(_make_wizard(entry))
	_all.append_array(_wizards)
	_all.append_array(_extras)


## The look and colors of the eight wizards of the match, the person at this machine first: the same ones that will stand in the world.
func _seat_styles() -> Array:
	var mine := maxi(Net.seat_of(Net.my_id()), 0) if Net.online() else 0
	var out := [Net.style_of_seat(mine)]
	for seat in Net.SEATS:
		if seat != mine:
			out.append(Net.style_of_seat(seat))
	return out


func _make_wizard(entry: Dictionary) -> IntroWizard:
	var to: float = entry["to"]
	var body := IntroWizard.new()
	body.lane = FLOOR_Y + ROW_DEPTH * int(entry["row"])
	body.climbs = entry.get("up", false)
	_stand_at(float(entry.get("from", to)), body)
	body.z_index = 2 + int(entry["row"])
	var sprite := AnimatedSprite2D.new()
	var magic := WizardLook.dress_sprite(sprite, entry["look"], int(entry["palette"]), true)
	var face := 1.0 if to < PILE_X else -1.0
	sprite.flip_h = face < 0.0
	sprite.play("idle")
	body.add_child(sprite)
	if magic != null:
		magic.paint(entry["color"])  # the glow of its staff is the color its wizard has in this scene
		body.add_child(magic)
		body.magic = magic
	body.sprite = sprite
	body.face = face
	body.color = entry["color"]
	if entry["mode"] == "blink":
		body.modulate.a = 0.0  # it is not there until it steps out of the light
	add_child(body)
	return body


func _build_portal() -> void:
	_portal = Portal.new()
	_portal.position = Vector2(PORTAL_X, PILE_Y - PORTAL_HEIGHT)
	_portal.scale = Vector2.ONE * PORTAL_SCALE
	_portal.rotation = PI * 0.5  # lying flat in the ceiling, so nobody can walk past it
	_portal_home = _portal.position
	_portal.visible = false  # there is no portal until the book comes apart
	add_child(_portal)
	_bloom = Node2D.new()  # the light that pours out of it when it tears
	_bloom.material = Fx.additive()
	_bloom.z_index = 5
	_bloom.draw.connect(func() -> void:
		if _bloom_k > 0.0:
			Fx.draw_glow(_bloom, _portal_home, 90.0 + 700.0 * _bloom_k, Color(0.7, 0.5, 1.0, 0.5 * _bloom_k))
			Fx.draw_glow(_bloom, _portal_home, 40.0 + 320.0 * _bloom_k, Color(1.0, 0.95, 1.0, 0.7 * _bloom_k)))
	add_child(_bloom)


## The portal is growing unstable: it shakes, and bolts of its own violet light crack out of it, more of them once the pages go through.
func _destabilise(delta: float) -> void:
	if _portal == null or _leaving or not _opened or not _portal.visible:
		return
	_portal.position = _portal_home + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _unrest * 3.0
	_crackle -= delta
	if _crackle > 0.0:
		return
	_crackle = lerpf(0.5, 0.12, _unrest) * randf_range(0.6, 1.4)
	var bolt := AnimatedSprite2D.new()
	bolt.sprite_frames = PixelFx.frames("lightning", 24.0, false)
	bolt.material = Fx.additive()
	bolt.modulate = CRACKLE_COLOR
	bolt.scale = Vector2.ONE * randf_range(0.5, 0.9)
	bolt.offset = Vector2(0.0, -100.0)  # the bolt leaves from the portal, down into the hall
	bolt.rotation = randf_range(PI - 1.1, PI + 1.1)
	bolt.position = _portal.position
	bolt.z_index = 2
	bolt.animation_finished.connect(bolt.queue_free)
	add_child(bolt)
	bolt.play("default")
	if randf() < 0.4:
		Sfx.cue("intro", "thunder", _portal.position, -24.0)


# --- The camera ---------------------------------------------------------------------------------------------------


## The camera runs beside the first wizard.
func _follow_the_first() -> void:
	_following = _wizards[0]


## The first wizard has come in: the camera lets go of it and opens out on the whole ring.
func _pull_back() -> void:
	_shot(Vector2(PILE_X, PILE_Y - 94.0), WIDE, 1.5)


# --- The story ----------------------------------------------------------------------------------------------------


func _play(wizard: IntroWizard, what: String, facing: float) -> void:
	wizard.face = facing
	wizard.sprite.flip_h = facing < 0.0
	if wizard.magic != null:
		wizard.magic.flip_h = wizard.sprite.flip_h
	wizard.sprite.play("release" if what == "grab" else what)  # (grabbing is the thrust of the staff)


## Runs a wizard to a spot on the floor at a speed, then stands it facing a way.
func _run_to(wizard: IntroWizard, x: float, face: float, speed: float, then := "idle") -> Tween:
	_play(wizard, "run", signf(x - wizard.position.x))
	var tween := create_tween()
	tween.tween_method(_stand_at.bind(wizard), wizard.position.x, x, absf(x - wizard.position.x) / speed)
	tween.tween_callback(_play.bind(wizard, then, face))
	tween.tween_callback(func() -> void: wizard.here = true)
	return tween


## A wizard comes into the hall the way its entry says: running, walking, or stepping out of a puff of light where it stands.
func _arrive(wizard: IntroWizard, entry: Dictionary) -> void:
	var to: float = entry["to"]
	var face := 1.0 if to < PILE_X else -1.0
	match entry["mode"]:
		"run":
			_run_to(wizard, to, face, RUN)
		_:
			wizard.modulate.a = 0.0
			var spot: Vector2 = wizard.position + Vector2(0.0, -50.0)
			Sfx.cue("intro", "blink", spot, -8.0)
			Fx.burst(self, spot, CRACKLE_COLOR, 12, 140.0, 0.5, true)
			create_tween().tween_property(wizard, "modulate:a", 1.0, 0.25)
			wizard.here = true


## The height of the ground at an x position: the floor, or the stairs the pedestal stands on.
func _ground_at(x: float) -> float:
	return Podium.top_at(x, PILE_X, FLOOR_Y)


## Puts a wizard at an x position: on the floor of its row of the crowd, or, for one that stands on the stairs, on the stairs where they are under it.
func _stand_at(x: float, wizard: IntroWizard) -> void:
	wizard.position = Vector2(x, _ground_at(x) if wizard.climbs else wizard.lane)


## Where a wizard's staff is, for a spark or a bolt.
func _staff(index: int) -> Vector2:
	var wizard := _all[index]
	return wizard.position + Vector2(wizard.face * 38.0, -62.0)


## The portal surges: it flares, the hall shakes, and everyone flinches from it.
func _pulse(power: float) -> void:
	_shake = maxf(_shake, power)
	if not _opened:  # the book shudders in the air
		_book.modulate = Color(1.0 + power, 1.0 + power * 0.7, 1.0 + power * 0.4)
		create_tween().tween_property(_book, "modulate", Color.WHITE, 0.45)
		Sfx.cue("intro", "thunder", _book.global_position, -16.0 + power * 6.0)
		Fx.burst(self, _book.global_position, GOLD, 10, 140.0, 0.5, true)
		for wizard in _all:
			if wizard.alive and wizard.here:
				_flinch(wizard)
		return
	_portal.modulate = Color(1.0 + power, 0.9 + power * 0.6, 1.2 + power)
	create_tween().tween_property(_portal, "modulate", Color.WHITE, 0.45)
	Sfx.cue("intro", "thunder", _portal.global_position, -16.0 + power * 6.0)
	Fx.burst(self, _portal.position, CRACKLE_COLOR, 10, 160.0, 0.5, true)
	for wizard in _all:
		if wizard.alive and wizard.here:
			_flinch(wizard)


func _flinch(wizard: IntroWizard) -> void:
	var face := wizard.face
	_play(wizard, "hit", face)
	var tween := create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(func() -> void:
		if wizard.alive:
			_play(wizard, "idle", face))


## A wizard raises their staff at the others: their own color gathers on it, and they hold the pose.
func _draw_on_the_others(index: int) -> void:
	var wizard := _all[index]
	var face := 1.0 if (index * 7) % 5 < 2 else -1.0  # each turns on whoever is nearest on a side of its own: this is a free-for-all, not two sides of the pile
	var color := wizard.color
	_play(wizard, "grab", face)
	_cast_sound(wizard.position, -14.0)
	Fx.burst(self, _staff(index), color, 14, 120.0, 0.5, true)
	var glow := Fx.trail(color, 12, 0.6, 20.0, Vector2(0, -20), "star_04", 6.0)  # it keeps crackling there
	glow.position = Vector2(face * 38.0, -62.0)
	glow.local_coords = true
	wizard.add_child(glow)


## The portal cracks the hall at its worst: a surge that throws every wizard's hand up and shakes the pile.
func _the_hall_cracks() -> void:
	_pulse(1.0)  # the book flares, pulled at from every side
	_opened = true
	_unrest = 0.7  # the portal is not yet strong enough to draw at what is thrown
	_shake = 1.2
	var at := _book.global_position + Vector2(0.0, -Lectern.book_height() * 0.5)
	_book.visible = false
	_lectern.quiet()
	for page: IntroPage in _pile:  # the pages burst out of it, where it hung
		page.position = at + Vector2(randf_range(-10.0, 10.0), randf_range(-14.0, 14.0))
		page.visible = true
	_blast(at, 2.2)
	Fx.burst(self, at, GOLD, 30, 260.0, 0.7, true)
	Sfx.cue("intro", "volcano", _portal.global_position, -4.0, 0.05, 0.6)  # a low groan, as of something giving way
	_unbound_stream(at)


## What the book was bound to pours out of it as a purple smoke, winds up toward the ceiling in two strands, and gathers there into the portal.
func _unbound_stream(from: Vector2) -> void:
	_stream_from = from
	_stream_k = 0.0
	Fx.smoke(self, from, Color(0.5, 0.2, 0.75, 0.7), 14, 34.0, 70.0)
	Fx.burst(self, from, Color("#b070ff"), 24, 120.0, 0.9, true)
	var stream := Node2D.new()
	stream.material = Fx.additive()
	stream.z_index = 3
	stream.draw.connect(func() -> void:
		var to := _portal.position
		var across := (to - _stream_from).orthogonal().normalized()
		var head := _stream_k * 1.15
		for strand in 2:
			for i in 44:
				var s := float(i) / 43.0  # 0 at the book, 1 at the ceiling
				if s > head:
					break
				var sway := sin(s * TAU * 2.5 - _t * 9.0 + float(strand) * PI) * 24.0 * sin(s * PI)
				var at := _stream_from.lerp(to, s) + across * sway
				var strength := smoothstep(0.0, 0.12, head - s)
				Fx.draw_glow(stream, at, 9.0 + 4.0 * sin(s * 20.0 + _t * 6.0), Color(0.62, 0.3, 1.0, 0.55 * strength))
				Fx.draw_glow(stream, at, 3.5, Color(0.95, 0.85, 1.0, 0.7 * strength)))
	add_child(stream)
	_stream = stream
	_plume = create_tween().set_loops()
	_plume.tween_interval(0.35)
	_plume.tween_callback(func() -> void: Fx.smoke(self, _stream_from, Color(0.5, 0.2, 0.75, 0.6), 4, 30.0, 60.0))
	var rise := create_tween()
	rise.tween_method(_reach_for_the_ceiling.bind(stream), 0.0, 1.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rise.parallel().tween_callback(_open_the_portal).set_delay(1.0)


func _reach_for_the_ceiling(k: float, stream: Node2D) -> void:
	_stream_k = k
	stream.queue_redraw()


## The smoke has gathered: the portal opens where it ended.
func _open_the_portal() -> void:
	_portal.visible = true
	_portal.open()
	Sfx.cue("intro", "volcano", _portal.global_position, -2.0, 0.05, 0.5)
	_portal.scale = Vector2.ONE * 0.2
	create_tween().tween_property(_portal, "scale", Vector2.ONE * PORTAL_SCALE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A bolt of a wizard's own color, leaving a trail, at a place.
func _make_bolt(at: Vector2, color: Color) -> Node2D:
	var bolt := Node2D.new()
	bolt.material = Fx.additive()
	bolt.z_index = 3
	bolt.position = at
	bolt.draw.connect(func() -> void:
		Fx.draw_glow(bolt, Vector2.ZERO, 40.0, Color(color, 0.9))
		Fx.draw_glow(bolt, Vector2.ZERO, 16.0, Color(1, 1, 1, 0.9)))
	var trail := Fx.trail(color, 30, 0.3, 14.0, Vector2.ZERO, "star_04", 7.0)
	trail.local_coords = false
	bolt.add_child(trail)
	add_child(bolt)
	return bolt


## Every shot in the scene makes the sound of a real attack spell being cast (a fireball, an ice spear, a stone, thorns, a dark blast, a spark), a different one each time.
func _cast_sound(at: Vector2, volume_db: float) -> void:
	var spell: Array = _CASTS[randi() % _CASTS.size()]
	Sfx.cue(spell[0], spell[1], at, volume_db)


## One wizard fires at another with a bolt of their own color. If it kills, the other goes down for good.
func _shoot(from_index: int, to_index: int, kills := false) -> void:
	var from_at := _staff(from_index)
	var to_wizard := _all[to_index]
	var to_at := to_wizard.position + Vector2(0.0, -55.0)
	var color: Color = _all[from_index].color
	_play(_all[from_index], "grab", signf(to_at.x - from_at.x))
	_cast_sound(from_at, -6.0)
	var bolt := _make_bolt(from_at, color)
	var tween := create_tween()
	tween.tween_property(bolt, "position", to_at, 0.3)
	tween.tween_callback(_struck.bind(bolt, to_index, color, kills))


## Two wizards fire at once and the bolts meet over the pile and burst.
func _clash(a: int, b: int) -> void:
	var from_a := _staff(a)
	var from_b := _staff(b)
	var middle := (from_a + from_b) * 0.5 + Vector2(0.0, -10.0)
	_play(_all[a], "grab", signf(from_b.x - from_a.x))
	_play(_all[b], "grab", signf(from_a.x - from_b.x))
	_cast_sound(from_a, -6.0)
	_cast_sound(from_b, -6.0)
	var color_a: Color = _all[a].color
	var color_b: Color = _all[b].color
	var bolt_a := _make_bolt(from_a, color_a)
	var bolt_b := _make_bolt(from_b, color_b)
	create_tween().tween_property(bolt_b, "position", middle, 0.35)
	var tween := create_tween()
	tween.tween_property(bolt_a, "position", middle, 0.35)
	tween.tween_callback(func() -> void:
		bolt_a.queue_free()
		bolt_b.queue_free()
		_shake = maxf(_shake, 0.9)
		_unrest = minf(_unrest + 0.04, 1.0)
		Sfx.cue("intro", "explosion", middle, -10.0)
		Fx.burst(self, middle, color_a, 14, 200.0, 0.5, true)
		Fx.burst(self, middle, color_b, 14, 200.0, 0.5, true)
		Fx.burst(self, middle, Color.WHITE, 8, 120.0, 0.3, true)
		_blast(middle, 1.3))


## A bolt lands. One of the eight is thrown back and a page flies out of their hands, into the portal; one of the eight more falls and does not get up.
func _struck(bolt: Node2D, index: int, color: Color, kills: bool) -> void:
	bolt.queue_free()
	var wizard := _all[index]
	var face := wizard.face
	_shake = maxf(_shake, 0.8)
	_unrest = minf(_unrest + 0.04, 1.0)
	Sfx.cue("intro", "hurt_wizard" if index == 0 else "hurt", wizard.position, -4.0)
	Fx.burst(self, wizard.position + Vector2(0.0, -55.0), color, 16, 190.0, 0.5, true)
	if kills:
		wizard.alive = false
		for child in wizard.get_children():
			if child is GPUParticles2D or child is CPUParticles2D:
				child.emitting = false  # the glow on its staff goes out
		_play(wizard, "death", face)
		create_tween().tween_method(_stand_at.bind(wizard), wizard.position.x, wizard.position.x - face * 30.0, 0.35).set_ease(Tween.EASE_OUT)
		create_tween().tween_property(wizard, "modulate", Color(0.55, 0.55, 0.62), 1.2)  # and the light goes out of it
		_blast(wizard.position + Vector2(0.0, -30.0), 0.3)
		return
	if _torn:
		return  # lifted into the portal: a bolt that finds them does not push them off their way up
	_play(wizard, "hit", face)
	_blast(wizard.position + Vector2(0.0, -30.0), 0.9)
	var tween := create_tween()
	tween.tween_method(_stand_at.bind(wizard), wizard.position.x, wizard.position.x - face * 22.0, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.25)
	tween.tween_callback(_play.bind(wizard, "grab", face))


## A blast of something that lands: every page near it is shoved away from it and tossed up, tumbling.
func _blast(at: Vector2, power: float) -> void:
	for page: IntroPage in _pile:
		var away := page.position - at
		var near := 1.0 - away.length() / BLAST_REACH
		if near <= 0.0:
			continue
		near *= power
		var vel: Vector2 = page.vel
		vel += away.normalized() * 260.0 * near + Vector2(randf_range(-40.0, 40.0), -randf_range(180.0, 380.0) * near)
		page.vel = vel
		page.landed = false
		page.spin += randf_range(-14.0, 14.0) * near


## A bolt that misses and lands on the floor at x, and throws the pages about where it lands.
func _stray(index: int, x: float) -> void:
	var from_at := _staff(index)
	var to_at := Vector2(x, _ground_at(x) - 6.0)
	var color: Color = _all[index].color
	_play(_all[index], "grab", signf(to_at.x - from_at.x))
	_cast_sound(from_at, -6.0)
	var bolt := _make_bolt(from_at, color)
	var tween := create_tween()
	tween.tween_property(bolt, "position", to_at, 0.35)
	tween.tween_callback(func() -> void:
		bolt.queue_free()
		_shake = maxf(_shake, 0.7)
		_unrest = minf(_unrest + 0.03, 1.0)
		Sfx.cue("intro", "explosion", to_at, -10.0)
		Fx.burst(self, to_at, color, 16, 220.0, 0.5, true)
		_blast(to_at, 1.0))


## The pages fall, tumble, and slide on the floor; the portal draws at the ones that have been thrown high, and at all of them once it tears.
func _move_pages(delta: float) -> void:
	for page: IntroPage in _pile.duplicate():
		var vel: Vector2 = page.vel
		var height := PILE_Y - 1.0 - page.position.y
		var floor_y := _ground_at(page.position.x)
		var drawn := _torn or (height > PULL_HEIGHT and _unrest > 0.8)
		if vel == Vector2.ZERO and not drawn:
			continue  # still lying where it was
		if not drawn:
			vel = _flutter(page, vel, delta)
		else:
			vel.y += GRAVITY * delta
		if drawn:
			var toward := _portal.position - page.position
			vel += toward.normalized() * (TORN_PULL if _torn else PULL) * delta
			if _torn:
				vel = vel.lerp(toward.normalized() * 700.0, minf(delta * 3.0, 1.0))  # so it flies in and does not circle
			else:
				vel *= 1.0 - minf(delta * 1.2, 1.0)
			if toward.length() < 34.0:
				_swallowed(page)
				continue
		page.position += vel * delta
		if drawn:
			page.rotation += page.spin * delta
		if page.position.y >= floor_y - 1.0 and vel.y > 0.0 and not _torn:
			page.position.y = floor_y - 1.0  # it lands flat, with no bounce, slides a little, and lies still
			vel = Vector2(vel.x * 0.5 if not page.landed else move_toward(vel.x, 0.0, 420.0 * delta), 0.0)
			if not page.landed:
				page.landed = true
				var settle := create_tween().set_parallel(true)
				settle.tween_property(page, "rotation", randf_range(-1.2, 1.2), 0.25)
				settle.tween_property(page, "scale:x", PAGE_SCALE, 0.25)
			if absf(vel.x) < 12.0:
				vel = Vector2.ZERO
		page.vel = vel


## How a loose sheet of paper moves through the air: the air takes its speed away, it drops slowly and slips from side to side as it comes down, it
## tips over one way and then the other, and it turns over, so it is sometimes seen edge on.
func _flutter(page: IntroPage, vel: Vector2, delta: float) -> Vector2:
	if page.position.y >= _ground_at(page.position.x) - 1.5:
		return vel  # it is on the floor: sliding, not drifting
	var phase: float = page.flutter + delta * 4.5
	page.flutter = phase
	vel *= 1.0 - minf(delta * FLUTTER_DRAG, 1.0)
	vel.y = minf(vel.y + GRAVITY * 0.5 * delta, FLUTTER_FALL)
	vel.x += cos(phase) * FLUTTER_SWAY * delta
	page.rotation = lerp_angle(page.rotation, sin(phase) * 0.9, minf(delta * 8.0, 1.0))  # tips with the sway
	page.scale.x = PAGE_SCALE * maxf(absf(cos(phase * 0.8)), 0.08)  # turns over
	return vel


## The portal takes a page: it shrinks into the ring and the ring flares.
func _swallowed(page: IntroPage) -> void:
	_pile.erase(page)
	Sfx.cue("intro", "page", _portal.global_position, -10.0)
	Fx.burst(self, _portal.position, Color("#c8a8ff"), 8, 110.0, 0.4, true)
	_portal.modulate = Color(1.6, 1.4, 1.9)
	create_tween().tween_property(_portal, "modulate", Color.WHITE, 0.25)
	page.queue_free()


## The portal tears wide open. The pile that is left is dragged up into it, and the eight who are left, fighting it, are lifted off their feet and
## pulled in after it, in a flood of its light. The camera looks up to watch.
func _the_portal_tears() -> void:
	if _plume != null:
		_plume.kill()
	if _stream != null:
		var gone := create_tween()  # the smoke has done its work: it is drawn up into the portal
		gone.tween_property(_stream, "modulate:a", 0.0, 0.6)
		gone.tween_callback(_stream.queue_free)
	_unrest = 1.0
	_shake = 1.6
	Sfx.cue("intro", "thunder", _portal.global_position, -2.0)
	Sfx.cue("intro", "volcano", _portal.global_position, -2.0, 0.05, 0.5)
	create_tween().tween_property(_portal, "scale", Vector2.ONE * TORN_SCALE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	create_tween().tween_method(func(k: float) -> void: _bloom_k = k, 0.0, 1.0, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shot(Vector2(PILE_X, PILE_Y - 190.0), 2.0, 1.8)
	_torn = true  # whatever is still on the floor is dragged up into it
	_blast(Vector2(PILE_X, PILE_Y), 1.5)
	for i in _wizards.size():
		var wizard := _wizards[i]
		var tween := create_tween()
		tween.tween_interval(0.5 + i * 0.09)
		tween.tween_callback(_play.bind(wizard, "hit", wizard.face))  # off their feet
		tween.tween_property(wizard, "position", _portal.position + Vector2(0.0, 40.0), 1.4 - i * 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tween.tween_callback(Sfx.cue.bind("intro", "dark_whoosh", _portal.global_position, -6.0, 0.05, 0.8))
		tween.tween_property(wizard, "scale", Vector2.ONE * 0.2, 0.25)
		tween.parallel().tween_property(wizard, "modulate:a", 0.0, 0.25)



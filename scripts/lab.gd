class_name Lab
extends "res://scripts/arena.gd"

## The waiting room: the place before a run, where every spell can be tried. It is one long map with something to
## try each spell on: dummies that never fall, a turret that shoots, a pond, a pit of lava, a gap, and a hill. You
## never run out of stamina or health, and the portal at the far right starts a real run.
## N turns night on and off (for flares and eclipses), and R puts the room back as it was.

const START_COL := -31
const LAVA := Vector2i(-24, -16)   # first and last column of the lava pit
const GAP := Vector2i(-11, -2)     # a dry pit to cross
const POND := Vector2i(3, 13)      # the pond
const HILL := Vector2i(21, 28)     # a hill above the water's reach
const CEILING := Vector2i(14, 20)   # an overhang for icicles
const PIT_ROWS := 3.0
const GAP_ROWS := 4.0
const HILL_ROWS := 3.0
const NIGHT := Color(0.22, 0.2, 0.34)
const HEAL_PER_SECOND := 40.0
const HEAL_AFTER := 4.0  # seconds without a hit before health starts coming back, so damage can be seen

var _heal := 0.0
var _since_hurt := HEAL_AFTER
var _night: CanvasModulate
var _player_light: PointLight2D


func _where_are_we() -> Dictionary:
	return {"level": 0, "wave": 0, "count": 0, "biome": "cemetery"}


## The ground: flat, with a pit for lava, a gap, a pond's bed and a hill, each with gentle sides so it can be walked out of.
func _build_map() -> Dictionary:
	var heights := PackedFloat32Array()
	heights.resize(ArenaGen.RIGHT_WALL - ArenaGen.FIRST_COL)
	_dig(heights, LAVA, PIT_ROWS)
	_dig(heights, GAP, GAP_ROWS)
	_dig(heights, POND, PIT_ROWS)
	_dig(heights, HILL, -HILL_ROWS)
	var cells := ArenaGen.build(_rng, heights)
	for col in range(CEILING.x, CEILING.y + 1):
		for row in [-3, -2]:
			cells[Vector2i(col, row)] = ArenaGen.STONE  # a slab overhead, for icicles to hang from
	return cells


## Pushes the ground down (or up, if rows is negative) between two columns, with a smooth slope into it at each end.
func _dig(heights: PackedFloat32Array, span: Vector2i, rows: float) -> void:
	for col in range(span.x, span.y + 1):
		var edge := mini(col - span.x, span.y - col)
		var t := clampf((edge + 0.5) / 3.0, 0.0, 1.0)
		heights[col - ArenaGen.FIRST_COL] = rows * t * t * (3.0 - 2.0 * t)


func _begin_encounter(camera: Camera2D) -> void:
	player.position = Vector2(ArenaGen.column_x(START_COL), ArenaGen.surface_y(_cells, START_COL))
	camera.reset_smoothing()
	player.focus = "wand"
	Levels.wave_index = 0  # so the portal's banner and the run it starts begin at the first wave
	player.grant_unlimited(1.0e7)  # nothing here costs stamina
	player.damaged.connect(func(_amount: int) -> void: _since_hurt = 0.0)
	_director = WaveDirector.new()  # there are no waves; the director only has to exist
	_director.arena = self
	_director.set_process(false)
	add_child(_director)
	ritual.seed_spoken.connect(_on_seed_spoken)
	_add_ponds()
	_add_targets()
	_add_signs()
	_night = CanvasModulate.new()
	_night.color = NIGHT
	_night.visible = false
	_night.add_to_group("darkness")
	add_child(_night)
	_player_light = PointLight2D.new()
	_player_light.texture = Fx.tex("light_01")
	_player_light.texture_scale = 2.4
	_player_light.energy = 0.7
	_player_light.enabled = false
	player.add_child(_player_light)
	hud.set_title("Waiting room")
	hud.banner("The waiting room", "Try every spell. N is night, R resets, Tab is the spellbook, the portal on the right starts a run")
	_on_wave_cleared()  # the portal is open from the start


## The pond and the pit of lava, each filling the hollow dug for it.
func _add_ponds() -> void:
	for entry in [[POND, false], [LAVA, true]]:
		var span: Vector2i = entry[0]
		var pond := Pond.new()
		pond.lava = entry[1]
		pond.width = (span.y - span.x + 1) * float(ArenaGen.TILE)
		pond.depth = PIT_ROWS * ArenaGen.TILE + 16.0
		pond.position = Vector2(span.x * float(ArenaGen.TILE), ArenaGen.GROUND_Y)
		add_child(pond)


## Dummies to hit, a turret to shoot at you, and something standing on the hill.
func _add_targets() -> void:
	for entry in [["dummy", 16], ["dummy", 18], ["turret", 20], ["dummy", 25], ["dummy", 31], ["dummy", 33]]:
		var col: int = entry[1]
		var mob := _add_mob(entry[0], Vector2(ArenaGen.column_x(col), ArenaGen.surface_y(_cells, col)))
		mob.facing = -1.0


## Words on the ground, to say what each part of the room is for.
func _add_signs() -> void:
	var notes := [
		[START_COL, "Draw anything. Tab shows how."],
		[(LAVA.x + LAVA.y) / 2, "Lava"],
		[(GAP.x + GAP.y) / 2, "A gap"],
		[(POND.x + POND.y) / 2, "A pond"],
		[19, "Dummies, a turret, a ceiling"],
		[(HILL.x + HILL.y) / 2, "High ground"],
	]
	for note in notes:
		var label := Label.new()
		label.text = note[1]
		label.add_theme_font_override("font", FloatText.font())
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95, 0.8))
		label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.12))
		label.add_theme_constant_override("outline_size", 6)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(320, 30)
		label.scale = Vector2.ONE * 0.5
		var col: int = note[0]
		label.position = Vector2(ArenaGen.column_x(col) - 80.0, ArenaGen.GROUND_Y - 150.0)
		label.z_index = -1
		add_child(label)


func _process(delta: float) -> void:
	super(delta)
	# Health comes back by itself a few seconds after a hit, so nothing here can end the visit.
	_since_hurt += delta
	if _since_hurt < HEAL_AFTER:
		return
	_heal += HEAL_PER_SECOND * delta
	if _heal >= 1.0 and not player.dead:
		player.heal(int(_heal))
		_heal -= int(_heal)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and not ritual.visible:
		if key.keycode == KEY_N:
			_night.visible = not _night.visible
			_player_light.enabled = _night.visible
		elif key.keycode == KEY_R and not hud.is_game_over():
			get_tree().reload_current_scene()
	super(event)


## The portal opens a world at once: a random one, or the one named by four words spoken earlier (Enter opens the box).
func _on_portal_entered(body: Node2D) -> void:
	if body != player or _leaving or ritual.visible:
		return
	_leaving = true
	Sfx.play("portal_enter")
	Levels.wave_index = 0
	Levels.held_focus = "wand"
	var fade := create_tween()
	fade.tween_property(player, "modulate:a", 0.0, 0.25)
	fade.tween_callback(get_tree().change_scene_to_file.bind("res://scenes/world.tscn"))


## Four words of a world's name, typed into the ritual box, tune the portal to that world.
func _on_seed_spoken(text: String) -> void:
	World.next_seed = Incantation.seed_of(text)
	_on_feedback("The portal hums: %s" % Incantation.words_for(World.next_seed), Color("#c8a8ff"))
	Sfx.play("ritual_ok", player.center(), -6.0)

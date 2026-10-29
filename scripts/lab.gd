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

var _portal: Portal
var _leaving := false
var _heal := 0.0
var _since_hurt := HEAL_AFTER
var _night: CanvasModulate
var _player_light: PointLight2D


## The ground: flat, with a pit for lava, a gap, a pond's bed and a hill, each with gentle sides so it can be walked out of.
func _build_map() -> Variant:
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
	player.grant_unlimited(1.0e7)  # nothing here costs stamina
	player.damaged.connect(func(_amount: int) -> void: _since_hurt = 0.0)
	ritual.seed_spoken.connect(_on_seed_spoken)
	_add_ponds()
	_add_targets()
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
	hud.set_title("Waiting room
Walk into the portal to start the game, or chant your seed")
	_open_portal()  # the portal is open from the start


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
	if not ritual.visible:
		if event.is_action_pressed("night_toggle"):
			_night.visible = not _night.visible
			_player_light.enabled = _night.visible
		elif event.is_action_pressed("restart") and not hud.is_game_over():
			get_tree().reload_current_scene()
	super(event)


## The portal stands at the far end of the room, open from the start.
func _open_portal() -> void:
	_portal = Portal.new()
	var far_right: bool = player.global_position.x < 0.0
	var col := ArenaGen.RIGHT_WALL - 3 if far_right else ArenaGen.LEFT_WALL + 3
	_portal.position = Vector2(ArenaGen.column_x(col), ArenaGen.surface_y(_cells, col) - Portal.RY - 4.0)
	_portal.body_entered.connect(_on_portal_entered)
	add_child(_portal)
	_portal.open()
	hud.point_to_portal(_portal)
	Sfx.play("portal_open", _portal.global_position)


## The portal opens a world at once: a random one, or the one named by four words spoken earlier (Enter opens the box).
func _on_portal_entered(body: Node2D) -> void:
	if body != player or _leaving or ritual.visible:
		return
	_leaving = true
	Sfx.play("portal_enter")
	var fade := create_tween()
	fade.tween_property(player, "modulate:a", 0.0, 0.25)
	# The world takes a few seconds to build, and the window cannot draw while it does: go dark first, so it reads as a wait and not a hang.
	var cover := CanvasLayer.new()
	cover.layer = 100
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.add_child(black)
	add_child(cover)
	fade.tween_property(black, "color:a", 1.0, 0.4)
	fade.tween_interval(0.15)
	fade.tween_callback(get_tree().change_scene_to_file.bind("res://scenes/intro.tscn"))


## Four words of a world's name, typed into the ritual box, tune the portal to that world.
func _on_seed_spoken(text: String) -> void:
	World.next_seed = Incantation.seed_of(text)
	_on_feedback("Walk into the portal to enter that world.", Color("#c8a8ff"))
	Sfx.play("ritual_ok", player.center(), -6.0)

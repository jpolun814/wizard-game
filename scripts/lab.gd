class_name Lab
extends "res://scripts/arena.gd"

## The waiting room: the place before a run, where every spell can be tried. It is one long map with something to
## try each spell on: dummies that never fall, a turret that shoots, a pond, a pit of lava, a gap, and a hill. You
## never run out of stamina or health, and the spellbook on its stand at the far right starts a real run when it is touched.
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

var _lectern: Lectern
var _making: LikenessPanel  # the wizard maker, while it is open
var _mark: LikenessMark  # its circle, in the waiting room only
var _chant_guide: LikenessGuide  # the page with its words, while the player stands on the circle
var _leaving := false
var _touched := {}  # on the host, in a network game: the people who have touched the book
var _heal := 0.0
var _since_hurt := HEAL_AFTER
var _night: CanvasModulate
var _player_light: PointLight2D


## The ground: flat, with a pit for lava, a gap, a pond's bed and a hill, each with gentle sides so it can be walked out of.
func _build_map() -> Variant:
	var heights := PackedFloat32Array()
	heights.resize(ArenaGen.right_wall - ArenaGen.FIRST_COL)
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
	player.position = _start_for(Net.my_id())
	camera.reset_smoothing()
	player.grant_unlimited(1.0e7)  # nothing here costs stamina
	player.damaged.connect(func(_amount: int) -> void: _since_hurt = 0.0)
	ritual.seed_spoken.connect(_on_seed_spoken)
	if _scene_name() == "lab":
		_add_likeness_mark()
	_add_ponds()
	_add_targets()
	_night = CanvasModulate.new()
	_night.color = NIGHT
	_night.visible = false
	_night.add_to_group("darkness")
	add_child(_night)
	add_child(Grade.new())  # the same colour grade as every world
	_player_light = PointLight2D.new()
	_player_light.texture = Fx.tex("light_01")
	_player_light.texture_scale = 2.4
	_player_light.energy = 0.7
	_player_light.enabled = false
	player.add_child(_player_light)
	hud.set_title(_title())
	_place_lectern()
	if Net.dedicated:
		_touched[Net.my_id()] = true  # the server has nobody to touch the book: the match begins when the people who joined have
		player.hide()
	if Net.online():
		Net.set_open(true)  # friends may join while the host is in the waiting room
		Net.roster_changed.connect(_meet_people)
		_meet_people()


## The pond and the pit of lava, each filling the hollow dug for it.
func _add_ponds() -> void:
	for entry in [[POND, false], [LAVA, true]]:
		var span: Vector2i = entry[0]
		var pond := Pond.new()
		pond.lava = entry[1]
		pond.width = (span.y - span.x + 1) * float(ArenaGen.TILE)
		pond.depth = PIT_ROWS * ArenaGen.TILE + 16.0
		pond.position = Vector2(span.x * float(ArenaGen.TILE), ArenaGen.GROUND_Y)
		pond.ground = _ground
		add_child(pond)


## Dummies to hit, a turret to shoot at you, and something standing on the hill.
func _add_targets() -> void:
	for entry in [["dummy", 16], ["dummy", 18], ["turret", 20], ["dummy", 25], ["dummy", 31], ["dummy", 33]]:
		var col: int = entry[1]
		var mob := _add_mob(entry[0], Vector2(ArenaGen.column_x(col), ArenaGen.surface_y(_cells, col)))
		mob.facing = -1.0


## Whether lost maximum stamina grows back by itself. The tutorial turns this off, so a Necromancy spell's cost is seen and kept.
var heals_wounds := true


func _process(delta: float) -> void:
	super(delta)
	if _mark != null and _making == null:
		_show_guide(_mark.is_near(player.center()))
	# Health comes back by itself a few seconds after a hit, so nothing here can end the visit.
	_since_hurt += delta
	if not heals_wounds or _since_hurt < HEAL_AFTER:
		return
	_heal += HEAL_PER_SECOND * delta
	if _heal >= 1.0 and not player.dead:
		player.heal(int(_heal))
		_heal -= int(_heal)


## Nothing here can end the visit: whoever falls is on their feet again at once.
func _on_player_died() -> void:
	player.revive.call_deferred()


func _input(event: InputEvent) -> void:
	if not ritual.visible:
		if event.is_action_pressed("night_toggle"):
			_night.visible = not _night.visible
			_player_light.enabled = _night.visible
		elif event.is_action_pressed("restart") and not hud.is_game_over() and not Net.online():  # the room is shared in a network game
			get_tree().reload_current_scene()
	super(event)


## A glowing circle on top of the floating slab stands for the wizard maker: on it, the page with the words comes up.
func _add_likeness_mark() -> void:
	_mark = LikenessMark.new()
	var col := (CEILING.x + CEILING.y) / 2
	_mark.position = Vector2(ArenaGen.column_x(col), -3.0 * ArenaGen.TILE)  # the top of the slab
	add_child(_mark)
	ritual.likeness_listens = true
	ritual.likeness_spoken.connect(_open_likeness)


## The wizard maker is open beside the player, who walks and casts as they like: a stroke that starts on its plate is not a spell.
func _visible_hud_rects() -> Array[Rect2]:
	var rects := super()
	if _making != null:
		rects.append(_making.plate_rect())
	return rects


## The page with the words comes up while the player is on the circle, and goes when they leave it.
func _show_guide(wanted: bool) -> void:
	if wanted and _chant_guide == null:
		_chant_guide = LikenessGuide.new()
		add_child(_chant_guide)
	elif not wanted and _chant_guide != null:
		_chant_guide.queue_free()
		_chant_guide = null


## The wizard maker opens beside the person, who goes on walking and casting while it is open.
func _open_likeness() -> void:
	if _making != null:
		return
	Sfx.play("ritual_ok", player.center(), -6.0)
	_making = LikenessPanel.new()
	_making.wizard = player
	_show_guide(false)
	_making.closed.connect(func() -> void: _making = null)
	add_child(_making)


## The book stands on its stand at the far end of the room.
func _place_lectern() -> void:
	_lectern = Lectern.new()
	var far_right: bool = player.global_position.x < 0.0
	var col := ArenaGen.right_wall - 3 if far_right else ArenaGen.LEFT_WALL + 3
	_lectern.position = Vector2(ArenaGen.column_x(col), ArenaGen.surface_y(_cells, col))
	_lectern.body_entered.connect(_on_book_touched)
	add_child(_lectern)
	hud.point_to_portal(_lectern)  # the arrow at the edge of the screen points at it


## Touching the book starts the cut-scene and the run: of a random world, or the one named by four words spoken earlier (Enter opens the box). In a
## network game the wizard waits at the book, and the cut-scene opens for everyone once every person has touched it.
func _on_book_touched(body: Node2D) -> void:
	if body != player or _leaving or ritual.visible:
		return
	_leaving = true
	Sfx.play("book_open", _lectern.global_position)
	if not Net.online():
		_go(World.next_seed)
		return
	player.movement_enabled = false
	if Net.is_host():
		_stepped_in()
	else:
		_stepped_in.rpc_id(1)
	if _waiting_for().size() > 0:
		hud.set_title("Waiting room
Wait for the others to touch the book")


## Into the world, everyone at once. The world takes a few seconds to build, and the window cannot draw while it does: it goes dark first,
## so it reads as a wait and not a hang.
@rpc("authority", "call_remote", "reliable")
func _go(seed_value: int) -> void:
	World.next_seed = seed_value
	_leaving = true
	_leave_network_scene()
	var cover := CanvasLayer.new()
	cover.layer = 100
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.add_child(black)
	add_child(cover)
	var fade := create_tween()
	fade.tween_interval(0.25)
	fade.tween_property(black, "color:a", 1.0, 0.4)
	fade.tween_interval(0.15)
	fade.tween_callback(get_tree().change_scene_to_file.bind(Intro.LOADING if GameSettings.skip_opening() or Net.dedicated else "res://scenes/intro.tscn"))


## On the host: a person has touched the book. When the last one has, the match begins for everyone, in one world, from one seed.
@rpc("any_peer", "call_remote", "reliable")
func _stepped_in() -> void:
	var who := multiplayer.get_remote_sender_id()
	_touched[who if who != 0 else Net.my_id()] = true
	_start_if_all_in()


## On the host: once every person has touched the book, the match begins.
func _start_if_all_in() -> void:
	if _touched.is_empty() or not _waiting_for().is_empty():
		return
	if Net.dedicated and Net.roster.filter(func(peer: int) -> bool: return peer != 0 and peer != Net.my_id()).is_empty():
		return  # a server with nobody in the room does not begin a match
	Net.set_open(false)  # nobody joins a match under way
	var seed_value := World.next_seed if World.next_seed >= 0 else randi() % Incantation.seed_count()
	for peer in Net.peers_here():
		_go.rpc_id(peer, seed_value)
	_go(seed_value)


## The people who have not touched the book yet.
func _waiting_for() -> Array[int]:
	var out: Array[int] = []
	for peer in Net.roster:
		if peer != 0 and not _touched.has(peer):
			out.append(peer)
	return out


## Four words of a world's name, typed into the ritual box, tune the book to that world. In a network game the host's book is the
## one that counts, so it is tuned there.
func _on_seed_spoken(text: String) -> void:
	_tune(Incantation.seed_of(text))
	if Net.online() and not Net.is_host():
		_tune.rpc_id(1, Incantation.seed_of(text))
	_on_feedback("Touch the book to enter that world.", Color("#c8a8ff"))
	Sfx.play("ritual_ok", player.center(), -6.0)


@rpc("any_peer", "call_remote", "reliable")
func _tune(seed_value: int) -> void:
	World.next_seed = seed_value


func _scene_name() -> String:
	return "lab"


## Where a person starts in the room: side by side, by seat.
func _start_for(peer_id: int) -> Vector2:
	var col := START_COL + 2 * maxi(Net.seat_of(peer_id), 0)
	return Vector2(ArenaGen.column_x(col), ArenaGen.surface_y(_cells, col))


## The words at the top of the room. The host is told the address their friends type to join.
func _title() -> String:
	var lines := "Waiting room"
	if Net.online() and Net.is_host():
		var addresses := Net.local_addresses()
		if not addresses.is_empty():
			lines += "
Give your friends this address: " + ", ".join(addresses)
	return lines


## Everyone in the game stands in the room, and anyone who has left is gone from it.
func _meet_people() -> void:
	for peer in Net.roster:
		if peer != 0 and peer != Net.my_id() and get_node_or_null(Wizard.name_for(peer)) == null:
			_add_person(peer, _start_for(peer))
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if wizard.human and wizard.is_likeness() and not Net.roster.has(wizard.peer):
			wizard.queue_free()
			_touched.erase(wizard.peer)
	if Net.is_host():
		_start_if_all_in()  # the last one who had not walked in may have left the game

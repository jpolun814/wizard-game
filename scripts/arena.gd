class_name Arena
extends Node2D


## Arena: the map, the player,
## fast spells, rituals and the spellbook.

const MOB_SCENE := preload("res://scenes/mob.tscn")
const WIZARD_SCENE := preload("res://scenes/wizard.tscn")
const TILE := ArenaGen.TILE
const STROKE_STEP := 8.0  # the points of a stroke the other machines are sent are this far apart

@onready var player: Wizard = $Player

var caster: Caster
var ritual: RitualInput
var spellbook: Spellbook
var hud: Hud
var _minimap: Minimap
var grade_biome := ""  # the cast of colour the world is seen through (see Grade), the same for anything that shows a second view of it
var greyed := false  # the world is seen without colour (the graveyard), and so is anything that shows a second view of it
var _eye: ScryingEye  # the window of the Chant of the Scrying Eye, bottom right
var insight := InsightTip.new(self)  # the hover tooltip Insight shows over an enemy
## The minimap is hidden until its chant brings it into view. Health and stamina are always shown.
var revealed := {"minimap": false, "insight": false, "scrying_eye": false}
var _rng := RandomNumberGenerator.new()
var debug_panel: DebugPanel  # F1 opens it: buttons that summon enemies for testing
var _cells: Variant = {}  # the generated arena's tiles: a Dictionary (see ArenaGen) or a TileGrid
var _ground: Terrain
var spawner := SpellSpawner.new(self)  # what each spell makes
var rituals := Rituals.new(self)  # the chants
var casting := Casting.new(self)  # what happens when a stroke has been read
var tiled_ground := false  # true when the ground is tiles all the way, as in a generated world; set by _build_map

func _ready() -> void:
	if Net.online():
		# In a network game each wizard is named after the machine that drives it, so it is at the same path on every machine.
		player.name = Wizard.name_for(Net.my_id())
	player.look = Net.look_of(Net.my_id())
	player.palette = Net.palette_of(Net.my_id())
	# A new random arena each run, in the level's land. Build it before anything that reads the terrain.
	_rng.randomize()
	var biome := _biome()
	_cells = _build_map()
	var backdrop := Backdrop.new()
	add_child(backdrop)
	move_child(backdrop, 0)
	backdrop.build(ArenaGen.BIOMES[biome]["backdrop"])
	_ground = Terrain.new()
	_ground.tiled = tiled_ground
	add_child(_ground)
	move_child(_ground, 1)
	_ground.build(_cells, biome, _rng)
	# The camera follows the player but never shows past the walls at either end of the map.
	var camera: Camera2D = player.get_node("Camera2D")
	if ArenaGen.world_size.x > 0:
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = ArenaGen.world_size.x * TILE
		camera.limit_bottom = ArenaGen.world_size.y * TILE
	else:
		camera.limit_left = ArenaGen.LEFT_WALL * TILE + TILE / 2
		camera.limit_right = (ArenaGen.right_wall + 1) * TILE - TILE / 2
		camera.limit_bottom = (ArenaGen.GROUND_ROW + ArenaGen.DEPTH) * TILE  # the ground ends here; never look below it

	hud = preload("res://scenes/hud.tscn").instantiate()
	hud.player = player
	add_child(hud)
	_build_overlays()

	caster = Caster.new()
	add_child(caster)
	caster.cast_resolved.connect(casting.by_person)
	caster.misfired.connect(casting.misfire)
	caster.ground_check = _is_ground_at

	ritual = RitualInput.new()
	add_child(ritual)
	ritual.finished.connect(rituals.finished)
	player.damaged.connect(_on_player_damaged)
	PlayRecorder.attach(self, player, ritual)  # F9 records how this person plays, through every world (see PlayRecorder)
	player.debuff_applied.connect(_on_debuff_applied)
	player.died.connect(_on_player_died)

	spellbook = Spellbook.new()
	add_child(spellbook)
	debug_panel = DebugPanel.new()
	debug_panel.arena = self
	add_child(debug_panel)

	_begin_encounter(camera)
	if Net.online():
		player.share()
		Net.enter_scene(_scene_name())  # only now is anything about this scene sent here


func _exit_tree() -> void:
	Library.flush()
	leave_network_scene()


## In a network game a machine says it is leaving a scene a moment before it lets go of it (as the screen fades), so that nothing more
## about the scene is sent to it once it is gone.
func leave_network_scene() -> void:
	if Net.online() and Net.scene != "":
		Net.enter_scene("")


## What this scene is called in a network game: each machine says which one it is in (see Net.enter_scene).
func _scene_name() -> String:
	return "arena"


## A likeness of a person who plays on another machine, standing at a point (see Net).
func add_person(peer_id: int, feet: Vector2) -> Wizard:
	var wizard: Wizard = WIZARD_SCENE.instantiate()
	wizard.name = Wizard.name_for(peer_id)
	wizard.peer = peer_id
	wizard.look = Net.look_of(peer_id)
	wizard.palette = Net.palette_of(peer_id)
	wizard.position = feet
	add_child(wizard)
	wizard.share()
	return wizard


## A page has been found: the book takes it in.
func on_page_found(page: String) -> void:
	spellbook.refresh()
	Sfx.play("pickup", player.center())
	FloatText.spawn(self, player.center() + Vector2(0, -70), "Page: %s" % Pages.title_of(page), Color("#ffe9a0"), 1.1)


## A wizard reads the page it stands under. In a network game the host says who gets each page, so two never read the same one: a
## person on another machine asks it, and the page is read on every machine once it answers.
func read_page(pickup: PagePickup, wizard: Wizard) -> void:
	if Net.online() and not Net.is_host():
		_ask_to_read.rpc_id(1, String(pickup.name))
		return
	_page_read(String(pickup.name), String(wizard.name))
	Net.send(self, &"_page_read", [String(pickup.name), String(wizard.name)])


## On the host: a person on another machine asks to read a page. Someone else may have read it first.
@rpc("any_peer", "call_remote", "reliable")
func _ask_to_read(pickup_name: String) -> void:
	var asker := get_node_or_null(Wizard.name_for(multiplayer.get_remote_sender_id())) as Wizard
	var pickup := get_node_or_null(NodePath(pickup_name)) as PagePickup
	if asker == null or asker.dead or pickup == null or pickup.is_queued_for_deletion() or not pickup.gives(asker.ledger):
		return
	read_page(pickup, asker)


## A page is read into a wizard's book and taken off the ground. The person whose wizard it is sees it go into their book.
@rpc("authority", "call_remote", "reliable")
func _page_read(pickup_name: String, wizard_name: String) -> void:
	var pickup := get_node_or_null(NodePath(pickup_name)) as PagePickup
	var wizard := get_node_or_null(NodePath(wizard_name)) as Wizard
	if pickup == null or wizard == null:
		return
	var fresh := pickup.gives(wizard.ledger)
	var page := pickup.take(wizard.ledger)
	if wizard == player:
		if fresh:
			on_page_found(page)  # takes the page into the book
		spellbook.show_page(page)


## Every page is known at once, those on the map left where they lie.
func learn_every_page() -> void:
	player.ledger.learn_all()
	spellbook.refresh()


## The land the map is in.
## A point lifted out of any rock it is in. The waiting room has no rock to be in; a world overrides this.
func lifted_out_of_rock(point: Vector2) -> Vector2:
	return point


## Where a point lands when it is over a ridge of the snowy peaks: on the ridge's top, not on the ground behind it, which the ridge hides.
## A point above the ridge, or only a little way into it, is on it; one far below the top is on the ground in front. `ground` is where it
## would land otherwise.
func on_ridge(point: Vector2, ground: Vector2) -> Vector2:
	var ridges := get_tree().get_first_node_in_group("ridges") as MountainRidges
	if ridges == null:
		return ground
	var top := ridges.top_at(point.x)
	if top < INF and point.y <= top + 48.0 and top < ground.y - 4.0:
		return Vector2(point.x, top)
	return ground


## Where something placed at a point stands: the ground under it, or a ridge's top where it is over one.
func landing(point: Vector2) -> Vector2:
	return on_ridge(point, _surface_under(point))


## The ground a point sits over. A world with rock a physics query cannot see inside overrides this.
func _surface_under(point: Vector2) -> Vector2:
	return SpellTargets.surface_over(get_world_2d(), point)


func _biome() -> String:
	return ArenaGen.WAITING_ROOM_BIOME


## The map's tiles. The waiting room builds its own.
func _build_map() -> Variant:
	return ArenaGen.build(_rng)


## Puts the player on the map. The waiting room and the world each do this in their own way.
func _begin_encounter(_camera: Camera2D) -> void:
	pass


func add_mob(kind: String, feet: Vector2) -> Node2D:
	if Mob.KINDS[kind].role == "wizard":
		return add_wizard(kind, feet)
	var mob := MOB_SCENE.instantiate()
	mob.kind = kind
	mob.player = player
	mob.position = feet
	add_child(mob)
	return mob


## A wizard that a brain plays, in one of the looks in res://mobs, standing at a point on the ground. One with a name of its own is a
## seat of a match, which a network game shows on every machine (see World).
func add_wizard(look: String, feet: Vector2, seat_name := "") -> Wizard:
	var wizard: Wizard = WIZARD_SCENE.instantiate()
	wizard.look = look
	wizard.human = false
	wizard.brain = new_brain(wizard)
	wizard.flying = flies()
	wizard.fly_box = fly_box()
	wizard.position = feet
	if seat_name != "":
		wizard.name = seat_name
	add_child(wizard)
	if seat_name != "" and Net.online():
		wizard.share()
	return wizard


## The brain that plays a wizard here: the one that walks. A world with no ground has a brain of its own (World.new_brain).
func new_brain(body: Wizard) -> WizardBrain:
	return WizardBrain.new(body)


## The screen goes black over everything (a layer above the interface), and then `then` is called: the way out of a world.
func fade_to_black(seconds: float, then: Callable) -> void:
	var black := _black_cover(0.0)
	var tween := black.create_tween()
	tween.tween_property(black, "color:a", 1.0, seconds)
	tween.tween_callback(then)


## The world comes out of the dark.
func fade_from_black(seconds: float) -> void:
	var black := _black_cover(1.0)
	var tween := black.create_tween()
	tween.tween_property(black, "color:a", 0.0, seconds)
	tween.tween_callback(black.get_parent().queue_free)


## A black cover over the whole screen, on a layer above the interface, as clear or as dark as `alpha` says.
func _black_cover(alpha: float) -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, alpha)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	add_child(layer)
	return black


## True in a world with no ground, where every wizard flies (World).
func flies() -> bool:
	return false


## Where a flying wizard's feet may go, in pixels: it stops at the edge of this (World). Empty where no one flies.
func fly_box() -> Rect2:
	return Rect2()


func _on_player_died() -> void:
	end_run()


func end_run() -> void:
	caster.set_casting_enabled(false)
	ritual.cancel()
	Sfx.play("game_over")
	hud.show_game_over()


func _input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.double_click and event.is_action("school_left") and not ritual.visible and not hud.is_paused() and not player.dead:
		Flare.snuff_near(get_tree(), get_global_mouse_position(), 0.0)  # a double click on a flare puts it out
		if player.ledger.knows_spell("Stone Wall"):
			StoneWall.crumble_at(get_tree(), get_global_mouse_position())  # and one on a stone wall brings it down
	if event.is_action_pressed("debug_menu"):
		debug_panel.visible = not debug_panel.visible
		return
	if event.is_action_pressed("pause") and not ritual.visible and not hud.is_game_over():
		hud.toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if ritual.visible or hud.is_paused() or player.dead:
		return
	if event.is_action_pressed("start_ritual"):
		rituals.start()


func _process(_delta: float) -> void:
	# Casting and movement pause while the ritual box is open, so typing doesn't move or cast.
	# The spellbook doesn't pause anything, so it can stay open while you play.
	# In a network game the menu does not stop the world, so it stops the wizard instead.
	var busy: bool = ritual.visible or player.dead or player.fainted or hud.is_paused()
	if player.is_frozen():  # in a block of ice no spell is drawn and no chant is said
		ritual.cancel()
	caster.set_casting_enabled(not busy and not player.is_frozen() and not player.silenced() and player.rage_time <= 0.0)
	player.movement_enabled = not busy
	caster.anchor = player.center()
	caster.blocked_rects = _visible_hud_rects()
	caster.hide_trail = player.is_blind()
	player.shown_words = ritual.typed()  # and the words of a chant, as they are typed
	player.casting = caster.is_drawing()  # the wizard holds the staff up while a stroke is drawn
	player.cast_color = caster.drawing_color()  # and the crystal shows the school being drawn
	if Net.online():
		player.shown_stroke = _thinned(caster.stroke())  # the others see the stroke being drawn, as you see theirs
	for module: String in revealed:
		revealed[module] = revealed[module] or player.ledger.is_settled(module)  # a later world of the match keeps what was said in an earlier one
	_minimap.visible = revealed["minimap"]
	_eye.visible = revealed["scrying_eye"]
	insight.update()


## A stroke with its points at least STROKE_STEP apart, which is all a likeness needs to draw it: a fraction of what is sent.
func _thinned(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		if out.is_empty() or point.distance_to(out[out.size() - 1]) >= STROKE_STEP:
			out.append(point)
	if not points.is_empty() and out[out.size() - 1] != points[points.size() - 1]:
		out.append(points[points.size() - 1])  # the end is where the pointer is now
	return out


## The minimap and the Insight tooltip, which their chants reveal.
func _build_overlays() -> void:
	_minimap = Minimap.new()
	_minimap.arena = self
	_minimap.visible = false
	_minimap.gui_input.connect(_on_hud_clicked.bind("minimap"))
	hud.add_child(_minimap)
	_eye = ScryingEye.new()
	_eye.arena = self
	_eye.visible = false
	hud.add_child(_eye)
	insight.build(hud)


## The map as tile blocks. Cell (0, 0) is the top-left corner of the arena, and y grows downward.
func map_cells() -> Variant:
	return _cells


## Clicking a HUD module hides it again.
func _on_hud_clicked(event: InputEvent, module: String) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	revealed[module] = false


## The visible HUD modules on screen. The caster ignores presses that start over them.
func _visible_hud_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for control in [hud.stamina_bar, _minimap, _eye]:
		if control.visible:
			rects.append(control.get_global_rect())
	if debug_panel.visible:
		rects.append(debug_panel.panel.get_global_rect())
	return rects


## Another machine's cast arrives (see Casting).
@rpc("any_peer", "call_remote", "reliable")
func spawn_seen(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary, wizard_name: String, luck: int) -> void:
	casting.seen(spell, targeting, origin, aim, info, wizard_name, luck)


## The ground the wizards stand on, for the spells that dig it or cut into it.
func terrain() -> Terrain:
	return _ground


## The biome's earth, which a stone wall is made of: the same texture the ground is cut from.
func earth_texture() -> Texture2D:
	return _ground.earth_texture


## Makes a spell take effect in the world. Every wizard's spells come through here, whoever plays them.
func spawn_spell(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary, caster_node: Wizard) -> void:
	var before := get_child_count()
	spawner.spawn(spell, targeting, origin, aim, info, caster_node)
	for index in range(before, get_child_count()):
		get_child(index).set_meta("caster", caster_node)  # whatever the spell made belongs to its caster, for the count of what each wizard has done (see MatchStats)




## A bonfire burns at a spot, on every machine of a network game.
@rpc("any_peer", "call_remote", "reliable")
func kindle(spot: Vector2, power: float) -> void:
	rituals.kindle(spot, power)


## A little eye floats over a wizard while another watches them through the Chant of the Scrying Eye. Every machine shows it.
func eye_on(wizard: Wizard, on: bool) -> void:
	show_eye(String(wizard.name), on)
	Net.send(self, &"show_eye", [String(wizard.name), on])


@rpc("any_peer", "call_remote", "reliable")
func show_eye(wizard_name: String, on: bool) -> void:
	rituals.show_eye(wizard_name, on)


## A chant takes hold: a ring of light under the speaker, seen and heard on every machine of a network game.
@rpc("any_peer", "call_remote", "reliable")
func show_chant(speaker_name: String) -> void:
	rituals.show_chant(speaker_name)


## A brain's wizard speaks a chant (see Rituals.said_by).
func chant_by(speaker: Wizard, id: String) -> bool:
	return rituals.said_by(speaker, id)


## Where a Rift sets the wizard down: somewhere along the floor of this room. A world picks one of its halls instead.
func rift_spot(from: Vector2) -> Vector2:
	return Vector2(randf_range(ArenaGen.left_edge() + 80.0, ArenaGen.right_edge() - 80.0), from.y)


func _on_player_damaged(_amount: int) -> void:
	ritual.cancel()


func _on_debuff_applied(kind: String) -> void:
	match kind:
		"mute":
			ritual.cancel()
			feedback("Wait for your voice to return.", Color.ORANGE)


func feedback(text: String, color: Color) -> void:
	hud.show_message(text, color)


## True when a point is on or just above solid ground, within one tile. Platforms count.
## True when a point is on something a stone wall can grow out of: the ground, a platform, or another stone wall.
func _is_ground_at(point: Vector2) -> bool:
	var col := floori(point.x / TILE)
	var row := floori(point.y / TILE)
	if _cells.has(Vector2i(col, row)):
		return true  # the stroke has to begin inside the ground itself, not above it
	var probe := CircleShape2D.new()
	probe.radius = 12.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.transform = Transform2D(0.0, point)
	query.collision_mask = 1
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 8):
		if hit["collider"].has_meta("stone_wall"):
			return true
	return false


## The surface directly below a point (the floor or a platform), so things placed there sit on the ground.
func ground_below(point: Vector2) -> Vector2:
	return on_ridge(point, SpellTargets.ground_below(get_world_2d(), point))


## Debug: summons one enemy of a kind on the far side of the screen, ahead of where the wizard is facing.
func summon_far_side(kind: String) -> void:
	var zoom: float = player.get_node("Camera2D").zoom.x
	var half_view := get_viewport().get_visible_rect().size.x * 0.5 / zoom
	var x := clampf(player.global_position.x + player.facing * half_view * 0.75, ArenaGen.left_edge() + 24.0, ArenaGen.right_edge() - 24.0)
	var ground := SpellTargets.solid_below(get_world_2d(), Vector2(x, ArenaGen.GROUND_Y - 4.0 * TILE))
	add_mob(kind, ground)


## Debug: removes every enemy at once.
func clear_enemies() -> void:
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.take_damage(9999)
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if wizard != player:
			wizard.take_damage(9999)

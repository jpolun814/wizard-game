class_name Arena
extends Node2D


## Arena: the map, the player,
## fast spells, rituals and the spellbook.

const RIFT_WEAR := 35.0  # what a Rift takes off the most stamina you can have
const RIFT_LEAST := 20.0  # the least stamina a Rift can be cast with, and the least it leaves as the most
const PERFECT_CAST := 0.95  # accuracy a cast needs for the flourish
const MOB_SCENE := preload("res://scenes/mob.tscn")
const WIZARD_SCENE := preload("res://scenes/wizard.tscn")
const TILE := ArenaGen.TILE
const MISFIRE_COST := 10.0
const INSIGHT_REACH := 40.0  # how close the pointer must be to an enemy for Insight to show it
const STROKE_STEP := 8.0  # the points of a stroke the other machines are sent are this far apart
const HOODED_WIZARD := "Hooded Wizard"  # what Insight calls the wizard in the player's own look

@onready var player: Wizard = $Player

var caster: Caster
var ritual: RitualInput
var spellbook: Spellbook
var hud: Hud
var _minimap: Minimap
var grade_biome := ""  # the cast of colour the world is seen through (see Grade), the same for anything that shows a second view of it
var greyed := false  # the world is seen without colour (the graveyard), and so is anything that shows a second view of it
var _eye: ScryingEye  # the window of the Chant of the Scrying Eye, bottom right
var _insight_tip: PanelContainer  # the hover tooltip Insight shows over an enemy
var _insight_text: RichTextLabel
## The minimap is hidden until its chant brings it into view. Health and stamina are always shown.
var _revealed := {"minimap": false, "insight": false, "scrying_eye": false}
var _rng := RandomNumberGenerator.new()
var debug_panel: DebugPanel  # F1 opens it: buttons that summon enemies for testing
var _cells: Variant = {}  # the generated arena's tiles: a Dictionary (see ArenaGen) or a TileGrid
var _ground: Terrain
var spawner := SpellSpawner.new(self)  # what each spell makes
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
	caster.cast_resolved.connect(_on_cast_resolved)
	caster.misfired.connect(_on_misfire)
	caster.ground_check = _is_ground_at

	ritual = RitualInput.new()
	add_child(ritual)
	ritual.finished.connect(_on_ritual_finished)
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
		_start_ritual()


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
	for module: String in _revealed:
		_revealed[module] = _revealed[module] or player.ledger.is_settled(module)  # a later world of the match keeps what was said in an earlier one
	_minimap.visible = _revealed["minimap"]
	_eye.visible = _revealed["scrying_eye"]
	_update_insight()


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
	_insight_tip = PanelContainer.new()
	_insight_tip.visible = false
	_insight_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_insight_text = RichTextLabel.new()
	_insight_text.bbcode_enabled = true
	_insight_text.fit_content = true
	_insight_text.custom_minimum_size = Vector2(260, 0)
	_insight_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_insight_tip.add_child(_insight_text)
	hud.add_child(_insight_tip)


## The map as tile blocks. Cell (0, 0) is the top-left corner of the arena, and y grows downward.
func map_cells() -> Variant:
	return _cells


## Clicking a HUD module hides it again.
func _on_hud_clicked(event: InputEvent, module: String) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	_revealed[module] = false


## The visible HUD modules on screen. The caster ignores presses that start over them.
func _visible_hud_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for control in [hud.stamina_bar, _minimap, _eye]:
		if control.visible:
			rects.append(control.get_global_rect())
	if debug_panel.visible:
		rects.append(debug_panel.panel.get_global_rect())
	return rects


## The player's stroke has been read.
func _on_cast_resolved(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary) -> void:
	cast_by(spell, targeting, origin, aim, info, player)
	if not player.ledger.knows_spell(spell):
		_misfire_puff()  # a spell whose page has not been found is a shape that matches nothing


## A wizard's stroke has been read, the player's or a brain's: the same rules for both. It pays for the spell first. What tells a
## person that a cast came to nothing is said at the pointer; a rival's wizard has nobody to tell.
func cast_by(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary, wizard: Wizard) -> void:
	if not is_instance_valid(wizard) or wizard.dead:
		return
	var person := wizard == player
	if person:
		wizard.play_cast_release()
	if not wizard.ledger.knows_spell(spell):
		return
	if spell == "Icicles" and spawner.icicle_spots(info).is_empty():
		if person:
			FloatText.spawn(self, get_global_mouse_position() + Vector2(0, -22), "Aim under a ceiling", Color("#dff6ff"), 0.9)
			Sfx.play("misfire", wizard.center(), -6.0)
		return
	if wizard.fainted or wizard.is_frozen():
		return
	var label_at := get_global_mouse_position() + Vector2(0, -22) if person else wizard.center() + Vector2(0, -60)
	var limit := SpellLimits.refusal(wizard, spell)  # the place forbids it (no ground to work on in the sky, no fire under the sea): nothing is paid
	if limit != "":
		if person:
			FloatText.spawn(self, label_at, limit, Color("#ffb86b"), 0.9)
			Sfx.play("misfire", wizard.center(), -6.0)
		return
	if spell == "Faint" and spawner.blood_target(spell, origin) == null:
		if person:
			FloatText.spawn(self, label_at, "Aim at someone", Color("#ff9a9a"), 0.9)  # nothing is paid for a cut that finds no one
		return
	if spell == "Leech" and Leech.pick(get_tree(), wizard, aim) == null:
		if person:
			FloatText.spawn(self, label_at, "Aim at someone", Color("#ff9a9a"), 0.9)  # nothing is paid for a tether that finds no one
		return
	var spell_data: Spell = SpellData.SPELLS[spell]
	var cost := spell_data.cost_for(info)
	if not spell_data.pays_max():
		cost = Leech.cost_after(get_tree(), wizard, cost)  # on a tether, half of it falls on the other end
	var colour := spell_data.glow()
	if spell_data.pays_max():
		if not wizard.pay_max(cost):
			FloatText.spawn(self, label_at, "Too weak", Color("#ff9a9a"), 0.9)  # blood is never spent to the last drop
			Sfx.play("misfire", wizard.center(), -6.0)
			if person and is_in_group(&"world"):
				MatchStats.miss()
			return
	elif not wizard.spend(cost):
		FloatText.spawn(self, label_at, "Too tired", Color("#ffb86b"), 0.9)
		Sfx.play("misfire", wizard.center(), -6.0)
		if person and is_in_group(&"world"):
			MatchStats.miss()
		return
	wizard.last_spell = spell
	if person:
		FloatText.spawn(self, label_at, spell, colour.lightened(0.25), 0.9)
		if info.get("accuracy", 0.0) >= PERFECT_CAST:
			_flourish(colour)
	_spawn_everywhere(spell, targeting, origin, aim, info, wizard)


## A cast goes off on every machine of a network game, sent by the one that drives the wizard: the same spell in the same place, with
## the same throw of the dice for whatever it scatters. Each machine then decides what it does to the wizards that machine drives.
func _spawn_everywhere(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary, wizard: Wizard) -> void:
	var luck := randi()
	Net.send(self, &"_spawn_seen", [spell, targeting, origin, aim, info, String(wizard.name), luck])
	seed(luck)
	spawn_spell(spell, targeting, origin, aim, info, wizard)


@rpc("any_peer", "call_remote", "reliable")
func _spawn_seen(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary, wizard_name: String, luck: int) -> void:
	var wizard := get_node_or_null(NodePath(wizard_name)) as Wizard
	if wizard == null or wizard.get_multiplayer_authority() != multiplayer.get_remote_sender_id():
		return  # only the machine that drives a wizard casts for it
	seed(luck)
	spawn_spell(spell, targeting, origin, aim, info, wizard)


## A perfect cast: a ring of the school's light opens round the wizard, sparks fly off it and a gold "Perfect" rises.
func _flourish(colour: Color) -> void:
	var at: Vector2 = player.center()
	# A ring of light in the school's colour, opening round the wizard. It is a white texture, so the tint is the school's.
	var ring := Sprite2D.new()
	ring.texture = Fx.tex("circle_03")
	ring.material = Fx.additive()
	ring.modulate = colour.lightened(0.35)
	ring.position = at
	ring.z_index = 8
	ring.scale = Vector2.ONE * (30.0 / Fx.TEX_SIZE)
	add_child(ring)
	var open := create_tween().set_parallel(true)
	open.tween_property(ring, "scale", Vector2.ONE * (150.0 / Fx.TEX_SIZE), 0.45).set_ease(Tween.EASE_OUT)
	open.tween_property(ring, "modulate:a", 0.0, 0.45)
	open.chain().tween_callback(ring.queue_free)
	Fx.burst(self, at, colour.lightened(0.6), 14, 170.0, 0.5, true, "star_04")
	FloatText.spawn(self, at + Vector2(0, -52), "Perfect", Color("#ffe27a"), 1.0)
	Sfx.play("pickup", at, -6.0)


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




func _on_misfire() -> void:
	player.drain(MISFIRE_COST)
	_misfire_puff()


## A brain's wizard drew a stroke that means nothing: it pays what a person pays (no word is drawn: no person reads it).
func misfire_by(wizard: Wizard) -> void:
	if not is_instance_valid(wizard) or wizard.dead:
		return
	wizard.drain(MISFIRE_COST)
	Sfx.play("misfire", wizard.center(), -6.0)


## What a shape or a chant that means nothing does: a puff, a sound and one word, so a player with the sound off still knows.
func _misfire_puff() -> void:
	if is_in_group(&"world"):
		MatchStats.miss()  # a stroke that matched nothing is a try that did not go off
	Sfx.play("misfire", player.center())
	Fx.burst(self, get_global_mouse_position(), Color(0.6, 0.6, 0.65), 8, 80.0, 0.3)
	FloatText.spawn(self, get_global_mouse_position() + Vector2(0, -22), "Misfire", Color(0.75, 0.75, 0.82), 0.9)  # for a player with the sound off


func _start_ritual() -> void:
	if player.is_frozen():
		return
	if player.is_muted():
		_on_feedback("Wait for your voice to return.", Color.ORANGE)
		return
	if player.holding_breath():
		return  # the bubbles over the head say why
	ritual.open()
	# Stop this key press from also reaching the text box it just opened.
	get_viewport().set_input_as_handled()


func _on_ritual_finished(id: String, acc: float, unfinished: bool) -> void:
	var data: Dictionary = RitualInput.RITUALS[id]
	if not player.ledger.knows_chant(id):
		_misfire_puff()
		return
	if player.holding_breath():
		return
	if unfinished:
		# Stopping a chant partway lets the words fade harmlessly; only a garbled chant backfires.
		return
	player.break_sneak()
	player.ledger.mark_cast("chant:" + id)
	if data["kind"] == "toggle":
		_on_toggle_chant(data, acc)
		return

	if id == "rift" and (player.max_stamina - RIFT_WEAR < RIFT_LEAST or player.stamina < RIFT_LEAST):
		_on_feedback("Too frail." if player.stamina >= RIFT_LEAST else "Too tired.", Color("#ffb86b"))
		Sfx.play("misfire", player.center(), -6.0)
		return
	var power := RitualInput.power_for(acc)
	if power <= 0.0:
		player.take_damage(15)
		Sfx.play("explosion", player.center())
		Fx.impact(self, player.center(), Color("#ff4a4a"), 50.0)
		return

	_show_chant(String(player.name))
	Net.send(self, &"_show_chant", [String(player.name)])
	_grant_chant(player, id)
	match id:
		"rift":
			_rift()
		"dowsing":
			_dowse()
		"bonfire":
			var spot := _bonfire_spot()  # beside the wizard, not under them
			_kindle(spot, power)
			Net.send(self, &"_kindle", [spot, power])


## The Chant of Dowsing: an arrow points to the nearest page the player has not read, until they read it. Chanting again looks for another.
func _dowse() -> void:
	for old in get_tree().get_nodes_in_group("dowsings"):
		old.queue_free()
	var page := Dowsing.nearest_unread(get_tree(), player.center(), player.ledger)
	if page == null:
		_on_feedback("Nothing left to find.", Color("#ffe9a0"))
		return
	var dowsing := Dowsing.new()
	dowsing.target = page
	dowsing.ledger = player.ledger
	add_child(dowsing)


## A bonfire burns at a spot, on every machine of a network game.
@rpc("any_peer", "call_remote", "reliable")
func _kindle(spot: Vector2, power: float) -> void:
	if Bonfire.drowned(get_tree(), spot):  # under water it is out as soon as it is lit: a puff of steam, as a fire shot that falls in
		Fx.smoke(self, spot + Vector2(0.0, -12.0), Color(0.9, 0.95, 1.0, 0.6), 5, 24.0, 40.0)
		return
	var fire := Bonfire.new()
	add_child(fire)
	fire.power = power
	fire.global_position = spot


## The chants that give their speaker something, for a while or (see Ledger.LASTING) for the rest of the match.
func _grant_chant(speaker: Wizard, id: String) -> void:
	speaker.ledger.settle(id)
	match id:
		"boundless":
			speaker.grant_unlimited(20.0)
		"double_jump":
			speaker.grant_air_jump(20.0)
		"haste":
			speaker.grant_haste(20.0)
		"deep_breath":
			speaker.grant_deep_breath(speaker.DEEP_BREATH)
		"bonfire":
			if speaker.brain != null:  # (the person's own bonfire is made by their ritual, with the power of how well they said it)
				var spot := _bonfire_spot(speaker)
				_kindle(spot, 1.0)
				Net.send(self, &"_kindle", [spot, 1.0])


## A brain's wizard says one of the chants that give a gift, or lights a bonfire (the others make marks and portals, which have only the player's own).
## It says it perfectly. False when it does not know the chant, cannot speak or is under water.
func chant_by(speaker: Wizard, id: String) -> bool:
	if not is_instance_valid(speaker) or speaker.dead or not speaker.ledger.knows_chant(id) or speaker.is_muted() or speaker.is_frozen() or speaker.holding_breath():
		return false
	speaker.break_sneak()
	_show_chant(String(speaker.name))
	Net.send(self, &"_show_chant", [String(speaker.name)])
	_grant_chant(speaker, id)
	return true


## A little eye floats over a wizard while another watches them through the Chant of the Scrying Eye. Every machine shows it.
func eye_on(wizard: Wizard, on: bool) -> void:
	_show_eye(String(wizard.name), on)
	Net.send(self, &"_show_eye", [String(wizard.name), on])


@rpc("any_peer", "call_remote", "reliable")
func _show_eye(wizard_name: String, on: bool) -> void:
	var wizard := get_node_or_null(NodePath(wizard_name)) as Wizard
	if wizard == null:
		return
	var mark := wizard.get_node_or_null("EyeMark")
	if on and mark == null:
		mark = EyeMark.new()
		mark.name = "EyeMark"
		wizard.add_child(mark)
	elif not on and mark != null:
		mark.queue_free()


## A chant takes hold: a ring of light under the speaker, seen and heard on every machine of a network game.
@rpc("any_peer", "call_remote", "reliable")
func _show_chant(speaker_name: String) -> void:
	var speaker := get_node_or_null(NodePath(speaker_name)) as Wizard
	if speaker == null:
		return
	Sfx.play("ritual_ok", speaker.center())
	Fx.pop(self, speaker.global_position + Vector2(0, -2), "magic_02", Color(1.0, 0.9, 0.6), 80.0, 0.8, 1.3, 2.0)


## Where a bonfire is made: on the ground 80 px in front of the wizard, or behind them when there is a drop or a wall there.
func _bonfire_spot(of: Wizard = null) -> Vector2:
	var who: Wizard = of if of != null else player
	for side: float in [float(who.facing), -float(who.facing)]:
		var from: Vector2 = who.global_position + Vector2(side * 80.0, -48.0)  # above the ground there, even where it rises
		var hit := ground_below(from)
		if hit.y < from.y + 200.0 and absf(hit.y - who.global_position.y) < 120.0:
			return hit
	return who.global_position


## The Rift: the wizard is torn away and set down somewhere else, with no stamina left and 20 less to ever have.
func _rift() -> void:
	var colour: Color = SpellData.SCHOOL_COLORS["Shadow"]
	var start: Vector2 = player.global_position
	player.max_stamina -= RIFT_WEAR
	player.drain(player.stamina)
	player.stamina = minf(player.stamina, player.max_stamina)
	player.global_position = _rift_spot(start)
	player.reset_physics_interpolation()
	player.velocity = Vector2.ZERO
	Fx.pop(self, start + Vector2(0, -24), "twirl_02", colour, 60.0, 0.3, 0.3, 8.0)
	Fx.burst(self, start + Vector2(0, -24), colour, 16, 140.0, 0.3, true)
	Fx.pop(self, player.global_position + Vector2(0, -24), "twirl_02", colour, 24.0, 0.3, 2.4, -8.0)
	Fx.burst(self, player.global_position + Vector2(0, -24), colour, 16, 140.0, 0.3, true)
	Sfx.play("gravity", player.global_position, -2.0)


## Where a Rift sets the wizard down: somewhere along the floor of this room. A world picks one of its halls instead.
func _rift_spot(from: Vector2) -> Vector2:
	return Vector2(randf_range(ArenaGen.left_edge() + 80.0, ArenaGen.right_edge() - 80.0), from.y)


## A toggle chant shows or hides a HUD module. Incantations cost no stamina.
func _on_toggle_chant(data: Dictionary, acc: float) -> void:
	if acc < RitualInput.BACKFIRE_BELOW:
		_on_feedback("Check the words and try again.", Color.GRAY)
		return
	var module: String = data["module"]
	_revealed[module] = true  # said once, it holds for the rest of the match
	player.ledger.settle(module)
	Sfx.play("ritual_ok", player.center(), -6.0)


func _on_player_damaged(_amount: int) -> void:
	ritual.cancel()


func _on_debuff_applied(kind: String) -> void:
	match kind:
		"mute":
			ritual.cancel()
			_on_feedback("Wait for your voice to return.", Color.ORANGE)


func _on_feedback(text: String, color: Color) -> void:
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


## While Insight is on, hovering an enemy or a wizard shows its health, weaknesses and resistances in a small tooltip.
func _update_insight() -> void:
	var body: Node2D = _body_under_pointer() if _revealed["insight"] else null
	_insight_tip.visible = body != null
	if body == null:
		return
	if body is Wizard:  # a rival wizard's stamina is shown nowhere else, and the spells it has pages for, each in the colour of its school
		var wizard: Wizard = body
		var title := HOODED_WIZARD  # the hooded look has no MobKind: only a person wears it, and in a network game another may
		var desc: String = Mob.KINDS["dark_wizard"].desc
		if Mob.KINDS.has(wizard.look):
			title = Mob.KINDS[wizard.look].display_name
			desc = Mob.KINDS[wizard.look].desc
		_insight_text.text = "[b]%s[/b]   Stamina %d / %d
[i]%s[/i]" % [title, wizard.stamina, wizard.max_stamina, desc]
		var lines := ""
		for spell_name: String in SpellData.SPELLS:
			if wizard.ledger.knows_spell(spell_name):
				var colour: Color = SpellData.SCHOOL_COLORS[SpellData.SPELLS[spell_name].school]
				lines += "
[color=#%s]%s[/color]" % [colour.lightened(0.15).to_html(false), spell_name]
		_insight_text.text += "

Knows:" + lines
	else:
		var mob: Mob = body
		var data: MobKind = Mob.KINDS[mob.kind]
		var weak := _school_bb(data.weak) if data.weak != "" else "nothing"
		var resist := _school_bb(data.resist) if data.resist != "" else "nothing"
		_insight_text.text = "[b]%s[/b]   Stamina %d / %d
Weak to %s
Resists %s
[i]%s[/i]" % [
			data.display_name, mob.hp, mob.max_hp,
			weak, resist, data.desc,
		]
	var screen := get_viewport().get_visible_rect().size
	var tip_size := _insight_tip.get_combined_minimum_size()
	_insight_tip.position = (get_viewport().get_mouse_position() + Vector2(18, 18)).min(screen - tip_size - Vector2(8, 8)).max(Vector2(8, 8))  # kept on the screen, even with a long list


## The enemy or the other wizard closest to the pointer, if it is within reach.
func _body_under_pointer() -> Node2D:
	var pointer := get_global_mouse_position()
	var best: Node2D = null
	var best_distance := INSIGHT_REACH
	for body: Node2D in get_tree().get_nodes_in_group("mobs") + get_tree().get_nodes_in_group("wizards"):
		if body == player or (body is Wizard and body.is_unseen()):
			continue
		var distance: float = body.center().distance_to(pointer)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best


func _school_bb(school: String) -> String:
	return "[color=#%s]%s[/color]" % [SpellData.SCHOOL_COLORS[school].to_html(false), school]


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

extends Node2D

## Arena: a random map in the level's land, the player, waves of enemies, foci to pick up,
## fast spells, rituals and the spellbook.

const PERFECT_CAST := 0.95  # accuracy a cast needs for the flourish
const MOB_SCENE := preload("res://scenes/mob.tscn")
const TILE := ArenaGen.TILE
const ICICLE_REACH := 420.0  # a ceiling this far above a V can hang its icicle
const ICICLE_MAX := 240.0    # the longest an icicle grows
const MUZZLE_OFFSET := 26.0  # spawn directional spells just outside the caster's body
const BARRIER_SECONDS := 6.0
const MISFIRE_COST := 10.0
const PICKUP_RANGE := 48.0
const STEP_DAMAGE := 8
const INSIGHT_REACH := 40.0  # how close the pointer must be to an enemy for Insight to show it
const FLYER_HEIGHT := 150.0  # flyers arrive this far above the ground

@onready var player: CharacterBody2D = $Player

var caster: Caster
var ritual: RitualInput
var spellbook: Spellbook
var hud: Hud
var _minimap: Minimap
var _insight_tip: PanelContainer  # the hover tooltip Insight shows over an enemy
var _insight_text: RichTextLabel
## The minimap is hidden until its chant brings it into view. Health and stamina are always shown.
var _revealed := {"minimap": false, "insight": false}
var _rng := RandomNumberGenerator.new()
var debug_panel: DebugPanel  # F1 opens it: buttons that summon enemies for testing
var _cells := {}  # the generated arena's tiles, see ArenaGen
var _director: WaveDirector
var _place := {}  # which level and wave this is, see Levels.place_of
var _portal: Portal
var _leaving := false
var _ground: Terrain
var tiled_ground := false  # true when the ground is tiles all the way, as in a generated world; set by _build_map


func _ready() -> void:
	# A new random arena each run, in the level's land. Build it before anything that reads the terrain.
	_rng.randomize()
	_place = _where_are_we()
	var biome: String = _place["biome"]
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
		camera.limit_right = (ArenaGen.RIGHT_WALL + 1) * TILE - TILE / 2
		camera.limit_bottom = ArenaGen.GROUND_Y + TILE * 4

	hud = Hud.new()
	hud.player = player
	add_child(hud)
	hud.restart_requested.connect(_restart_run)
	_build_overlays()

	caster = Caster.new()
	add_child(caster)
	caster.cast_resolved.connect(_on_cast_resolved)
	caster.feedback.connect(_on_feedback)
	caster.misfired.connect(_on_misfire)
	caster.ground_check = _is_ground_at

	ritual = RitualInput.new()
	add_child(ritual)
	ritual.finished.connect(_on_ritual_finished)
	ritual.cancelled.connect(_on_ritual_cancelled)
	player.damaged.connect(_on_player_damaged)
	player.debuff_applied.connect(_on_debuff_applied)
	player.died.connect(_on_player_died)

	spellbook = Spellbook.new()
	add_child(spellbook)
	debug_panel = DebugPanel.new()
	debug_panel.arena = self
	add_child(debug_panel)

	_begin_encounter(camera)


## Which level and wave this is.
func _where_are_we() -> Dictionary:
	return Levels.place_of(Levels.wave_index)


## The map's tiles. The waiting room builds its own.
func _build_map() -> Dictionary:
	return ArenaGen.build(_rng)


## Puts the player on the map and starts the wave. The waiting room does something else here.
func _begin_encounter(camera: Camera2D) -> void:
	# The player starts on open ground near the middle. The waves come from the director, one at a time.
	var open := _clear_columns()
	var middle := open.filter(func(c: int) -> bool: return absi(c) < 12)
	var pool: Array = middle if not middle.is_empty() else open
	var start: int = pool[_rng.randi() % pool.size()]
	player.position = Vector2(ArenaGen.column_x(start), ArenaGen.surface_y(_cells, start))
	camera.reset_smoothing()
	# You keep your focus from map to map. The other one lies somewhere in each map, to swap for with E.
	player.focus = Levels.held_focus
	var other := "staff" if player.focus == "wand" else "wand"
	var spots := open.filter(func(c: int) -> bool: return absi(c - start) > 8)
	if not spots.is_empty():
		var spot: int = spots[_rng.randi() % spots.size()]
		_spawn_focus(other, Vector2(ArenaGen.column_x(spot), ArenaGen.surface_y(_cells, spot)))
	_director = WaveDirector.new()
	_director.arena = self
	add_child(_director)
	_director.wave_cleared.connect(_on_wave_cleared)
	var wave: Dictionary = Levels.all_waves()[Levels.wave_index]
	_director.start(wave)
	hud.set_wave(_place["level"], _place["wave"], _place["count"])
	if not wave.is_empty():
		var subtitle := "The Dark Wizard has come for you" if wave.has("dark_wizard") else ""
		hud.banner("Wave %d" % _place["wave"] if _place["wave"] > 1 else "Level %d" % _place["level"], subtitle)
		Sfx.play("wave_start")
	elif _place["wave"] == 1:
		hud.banner("Level %d" % _place["level"], "Press Esc for the controls, Tab for your spellbook")


## Adds one enemy of a kind on open ground, away from the player and from the other enemies.
## Returns false if no spot was found.
func spawn_mob(kind: String) -> bool:
	var open := _clear_columns()
	var player_col := ArenaGen.column_of(player.global_position.x)
	var taken: Array[int] = []
	for mob in get_tree().get_nodes_in_group("mobs"):
		taken.append(ArenaGen.column_of(mob.global_position.x))
	var near_view: float = get_viewport_rect().size.x * 0.5 / player.get_node("Camera2D").zoom.x
	for attempt in 60:
		var c: int = open[_rng.randi() % open.size()]
		var gap := absi(c - player_col) * TILE
		# Enemies arrive within sight, so you can see them come, but not on top of you.
		var ok := gap >= 200 and (gap <= near_view * 1.3 or attempt > 40)
		if ok and not _too_close(c, taken):
			_add_mob(kind, Vector2(ArenaGen.column_x(c), ArenaGen.surface_y(_cells, c)))
			return true
	return false


func _add_mob(kind: String, feet: Vector2) -> Node2D:
	var mob := MOB_SCENE.instantiate()
	mob.kind = kind
	mob.player = player
	mob.position = feet - Vector2(0, FLYER_HEIGHT if Mob.KINDS[kind]["role"] == "flyer" else 0.0)
	add_child(mob)
	return mob


## Once a wave is cleared, a portal opens at the far end of the map. Walking through it brings the next wave, in a new map.
func _on_wave_cleared() -> void:
	get_tree().call_group("lasting", "queue_free")  # clouds, mud, ice, snow and volcanoes end with the wave
	_portal = Portal.new()
	var far_right: bool = player.global_position.x < 0.0
	var col := ArenaGen.RIGHT_WALL - 3 if far_right else ArenaGen.LEFT_WALL + 3
	_portal.position = Vector2(ArenaGen.column_x(col), ArenaGen.surface_y(_cells, col) - Portal.RY - 4.0)
	_portal.body_entered.connect(_on_portal_entered)
	add_child(_portal)
	_portal.open()
	hud.point_to_portal(_portal)
	if not Levels.all_waves()[Levels.wave_index].is_empty():
		hud.banner("Wave cleared")
	Sfx.play("portal_open", _portal.global_position)


func _on_portal_entered(body: Node2D) -> void:
	if body != player or _leaving:
		return
	_leaving = true
	Sfx.play("portal_enter")
	# The map ends with the last wave; going through the portal after it starts the run again from the first.
	Levels.wave_index = (Levels.wave_index + 1) % Levels.all_waves().size()
	var fade := create_tween()
	fade.tween_property(player, "modulate:a", 0.0, 0.25)
	fade.tween_callback(get_tree().reload_current_scene)


func _on_player_died() -> void:
	caster.set_casting_enabled(false)
	ritual.cancel()
	Sfx.play("game_over")
	hud.show_game_over(_place["level"], _place["wave"])


## A death ends the run; the next one starts from the first wave.
func _restart_run() -> void:
	Levels.wave_index = 0
	Levels.held_focus = "wand"
	get_tree().reload_current_scene()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F1:
		debug_panel.visible = not debug_panel.visible
		return
	if key.keycode == KEY_ESCAPE and not ritual.visible and not hud.is_game_over():
		hud.toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if ritual.visible or hud.is_paused() or player.dead:
		return
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_start_ritual()
		KEY_E:
			_try_pickup()


func _process(_delta: float) -> void:
	# Casting and movement pause while the ritual box is open, so typing doesn't move or cast.
	# The spellbook doesn't pause anything, so it can stay open while you play.
	var busy: bool = ritual.visible or player.dead
	caster.set_casting_enabled(not busy)
	player.movement_enabled = not busy
	caster.anchor = player.center()
	caster.blocked_rects = _visible_hud_rects()
	caster.hide_trail = player.is_blind()
	player.casting = caster.is_drawing()  # the wizard holds the staff up while a stroke is drawn
	player.cast_color = caster.drawing_color()  # and the crystal shows the school being drawn
	caster.tolerance = FocusItem.FOCI[player.focus]["tolerance"]
	_minimap.visible = _revealed["minimap"]
	_update_insight()
	hud.set_foes(_director.remaining(), _director.is_cleared())


## The minimap and the Insight tooltip, which their chants reveal.
func _build_overlays() -> void:
	_minimap = Minimap.new()
	_minimap.arena = self
	_minimap.visible = false
	_minimap.gui_input.connect(_on_hud_clicked.bind("minimap"))
	hud.add_child(_minimap)
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
func map_cells() -> Dictionary:
	return _cells


## Floor columns with room to stand, away from the map's ends.
func _clear_columns() -> Array[int]:
	var cols: Array[int] = []
	for c in ArenaGen.open_columns(_cells):
		if c > ArenaGen.LEFT_WALL + 1 and c < ArenaGen.RIGHT_WALL - 1:
			cols.append(c)
	return cols


## Clicking a HUD module hides it again.
func _on_hud_clicked(event: InputEvent, module: String) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	_revealed[module] = false
	_on_feedback("Minimap hidden. Say its chant again to bring it back.", Color.WHITE)


## The visible HUD modules on screen. The caster ignores presses that start over them.
func _visible_hud_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for control in [hud.health_bar, hud.stamina_bar, _minimap]:
		if control.visible:
			rects.append(control.get_global_rect())
	if debug_panel.visible:
		rects.append(debug_panel.panel.get_global_rect())
	return rects


func _on_cast_resolved(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary) -> void:
	player.play_cast_release()
	if spell == "Icicles" and _icicle_spots(info).is_empty():
		FloatText.spawn(self, get_global_mouse_position() + Vector2(0, -22), "Needs a ceiling", Color("#dff6ff"), 0.9)
		Sfx.play("misfire", player.center(), -6.0)
		return
	var cost := SpellData.cost_for(spell, info)
	if player.focus == "staff":
		cost *= 0.75  # a staff channels spells better: a quarter off every cast
	var colour := SpellData.color_of(spell)
	var label_at := get_global_mouse_position() + Vector2(0, -22)
	if not player.spend(cost):
		_on_feedback("Not enough stamina for %s (needs %d)" % [spell, cost], Color.ORANGE)
		FloatText.spawn(self, label_at, "Too tired", Color("#ffb86b"), 0.9)
		Sfx.play("misfire", player.center(), -6.0)
		return
	FloatText.spawn(self, label_at, spell, colour.lightened(0.25), 0.9)
	if info.get("accuracy", 0.0) >= PERFECT_CAST:
		_flourish(colour)
	spawn_spell(spell, targeting, origin, aim, info, player)


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


## The biome's earth, which a stone wall is made of: the same texture the ground is cut from.
func _earth_texture() -> Texture2D:
	return _ground.earth_texture


## Makes a spell take effect in the world. The player's spells and the dark wizard's both come through here.
## caster is whoever cast it: the player or a dark wizard.
func spawn_spell(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary, caster_node: Node2D) -> void:
	var from: Vector2 = caster_node.center()
	match spell:
		"Earthquake":
			add_child(Earthquake.new())
			return
		"Barrier":
			# Barrier wraps the caster rather than appearing somewhere in the world.
			caster_node.raise_shield(BARRIER_SECONDS)
			return
		"Shadow Step":
			# A step zips the caster along the stroke, so it starts from the caster, not the stroke.
			_shadow_step(caster_node, aim, info.get("length", 0.0))
			return
		"Fire Breath":
			# The fire pours out of the caster, toward the cone's open end.
			var breath := FireBreath.new()
			breath.caster_node = caster_node
			breath.aim = aim
			breath.spread = info.get("spread", 0.8)
			breath.reach = info.get("reach", 160.0)
			add_child(breath)
			return
		"Abyss":
			var abyss := Abyss.new()
			abyss.reach = info.get("radius", 60.0) * 2.0
			abyss.position = origin
			add_child(abyss)
			return
		"Tsunami":
			var wave := Tsunami.new()
			wave.direction = 1.0 if cos(aim) >= 0.0 else -1.0
			add_child(wave)
			return
		"Flare":
			# The flare hovers by the caster and follows them wherever it was drawn.
			var flare := Flare.new()
			flare.caster_node = caster_node
			add_child(flare)
			return
		"Spore Puff":
			# The spores pour out of the caster, toward the cone's open end, like Fire Breath.
			var spores := SporePuff.new()
			spores.caster_node = caster_node
			spores.aim = aim
			spores.spread = info.get("spread", 0.8)
			spores.reach = info.get("reach", 160.0)
			add_child(spores)
			return
		"Flytrap":
			var trap := Flytrap.new()
			trap.position = origin
			add_child(trap)
			return
		"Eclipse":
			var eclipse := Eclipse.new()
			var size: Vector2 = info.get("extent", Vector2(100, 100))
			eclipse.radius = maxf(size.x, size.y) * 0.6
			eclipse.position = origin
			add_child(eclipse)
			return
		"Decoy":
			var decoy := Decoy.new()
			decoy.position = _ground_below(origin)
			add_child(decoy)
			return
		"Hex":
			var cursed := Hex.nearest_under(get_tree(), origin)
			if cursed == null:
				FloatText.spawn(self, origin + Vector2(0, -20), "No one under the star", Color("#c8a8ff"), 0.9)
				return
			var hex := Hex.new()
			hex.target = cursed
			add_child(hex)
			return
	# Icicles, snowfall, tornados, volcanoes and the rest are placed where they were drawn, not at one point.
	if targeting == "shape":
		_place_shapes(spell, info)
		return
	# Stone Wall rises from where the stroke began, on the ground. Other directional spells leave the caster
	# along the stroke; positional ones appear where drawn.
	if targeting == "directional" and spell != "Stone Wall":
		origin = from + Vector2.from_angle(aim) * MUZZLE_OFFSET
	if spell == "Stonefall":
		# A boulder falls onto the ground under the stroke and stays where it lands, as a loose rock.
		var boulder := Boulder.new()
		boulder.global_position = origin + Vector2(0, -260)
		add_child(boulder)
		return
	var effect := _new_effect(spell)
	effect.caster = caster_node
	if effect is PushZone:
		effect.zone_radius = info.get("radius", 0.0)
	elif effect is StoneWall:
		effect.wall_length = info.get("length", 0.0)
		effect.wall_texture = _earth_texture()
	add_child(effect)
	effect.setup(spell, origin, aim)


## A new effect of the kind a spell needs.
func _new_effect(spell: String) -> SpellEffect:
	match spell:
		"Ignite", "Frostbolt":
			return Projectile.new()
		"Firewall":
			return Firewall.new()
		"Push":
			return PushZone.new()
		"Gust":
			return Gust.new()
		"Stone Wall":
			return StoneWall.new()
		"Spark":
			return SparkStrike.new()
	push_error("No spell effect for %s" % spell)
	return SpellEffect.new()


## The last spot on the way from start to end where a body fits: feet, middle and head all clear of the ground. A step
## never ends inside rock, so it never leaves anyone stuck.
func _out_of_rock(start: Vector2, end: Vector2) -> Vector2:
	var steps := maxi(1, int(start.distance_to(end) / 8.0))
	for i in range(steps, -1, -1):
		var at := start.lerp(end, float(i) / steps)
		var free := true
		for lift in [-4.0, -36.0, -70.0]:
			var probe := PhysicsPointQueryParameters2D.new()
			probe.position = at + Vector2(0.0, lift)
			probe.collision_mask = 1
			if not get_world_2d().direct_space_state.intersect_point(probe, 1).is_empty():
				free = false
				break
		if free:
			return at
	return start


## Shadow Step: the caster slips along the stroke, stopping short of walls. Whoever is in the way takes damage, the
## caster aside.
func _shadow_step(caster_node: Node2D, aim: float, length: float) -> void:
	var dir := Vector2.from_angle(aim)
	var start: Vector2 = caster_node.global_position
	var end := start + dir * minf(length, SpellData.STEP_MAX)
	var query := PhysicsRayQueryParameters2D.create(start + Vector2(0, -20), end + Vector2(0, -20))
	query.collision_mask = 1
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit["position"] + Vector2(0, 20) - dir * 16.0
	end.x = clampf(end.x, ArenaGen.left_edge() + 14.0, ArenaGen.right_edge() - 14.0)
	end = _out_of_rock(start, end)
	for body in SpellTargets.all(get_tree()):
		if body == caster_node:
			continue
		var middle := SpellTargets.center_of(body)
		var closest := Geometry2D.get_closest_point_to_segment(middle, start + Vector2(0, -20), end + Vector2(0, -20))
		if closest.distance_to(middle) <= 24.0:
			SpellTargets.hurt(body, STEP_DAMAGE, "Shadow")
	var colour: Color = SpellData.SCHOOL_COLORS["Shadow"]
	Fx.pop(self, start + Vector2(0, -24), "twirl_02", colour, 60.0, 0.3, 0.3, 8.0)
	Fx.burst(self, start + Vector2(0, -24), colour, 12, 120.0, 0.25, true)
	if caster_node.has_method("free_from_ground"):
		caster_node.free_from_ground()  # a blink moves you out of the ground too
	caster_node.global_position = end
	caster_node.reset_physics_interpolation()
	if caster_node is CharacterBody2D:
		caster_node.velocity = Vector2.ZERO
	Fx.pop(self, end + Vector2(0, -24), "twirl_02", colour, 24.0, 0.3, 2.4, -8.0)
	Fx.burst(self, end + Vector2(0, -24), colour, 12, 120.0, 0.25, true)
	Sfx.play("gravity", end, -2.0)  # a low whoosh like the other Shadow spells


## Where each drawn V can hang an icicle: from the ceiling straight above it. A V with no ceiling over it grows nothing.
## The icicle reaches down toward the V's tip, no longer than ICICLE_MAX.
func _icicle_spots(info: Dictionary) -> Array:
	var spots := []
	for tri in info.get("shapes", []):
		var top := Vector2(tri[1].x, minf(tri[0].y, tri[2].y))
		var query := PhysicsRayQueryParameters2D.create(top, top + Vector2(0.0, -ICICLE_REACH))
		query.collision_mask = 1
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var length := clampf(tri[1].y - hit["position"].y, 40.0, ICICLE_MAX)
		var width := clampf(absf(tri[2].x - tri[0].x), 14.0, length * 0.6)
		spots.append({"base": hit["position"] + Vector2(0.0, 6.0), "width": width, "length": length})
	return spots


## The spells whose shape says where they go: icicles stand as the triangles they were drawn as, snow falls over
## the drawn line, a tornado or volcano forms under the middle of the drawing, a storm cloud hangs along its line,
## quicksand opens under the U, and an ice
## prison fills the drawn box.
func _place_shapes(spell: String, info: Dictionary) -> void:
	var line: PackedVector2Array = info.get("line", PackedVector2Array())
	var centre := Vector2.ZERO
	for p in line:
		centre += p / line.size()
	match spell:
		"Icicles":
			for spot in _icicle_spots(info):
				var half: float = spot["width"] * 0.5
				var icicle := Icicle.new()
				icicle.polygon = PackedVector2Array([Vector2(-half, 0.0), Vector2(half, 0.0), Vector2(0.0, spot["length"])])
				add_child(icicle)
				icicle.setup(spell, spot["base"], 0.0)  # the base sits just inside the ceiling, hidden by it
		"Tornado":
			var tornado := Tornado.new()
			tornado.position = centre
			add_child(tornado)
		"Volcano":
			var volcano := Volcano.new()
			volcano.position = SpellTargets.surface_over(get_world_2d(), centre)  # always on the surface, never under it
			add_child(volcano)
		"Blizzard":
			var left := line[0].x
			var right := line[0].x
			for p in line:
				left = minf(left, p.x)
				right = maxf(right, p.x)
			var snow := Blizzard.new()
			snow.polygon = PackedVector2Array([Vector2(0, -60), Vector2(right - left, -60), Vector2(right - left, 60), Vector2(0, 60)])
			add_child(snow)
			snow.setup(spell, Vector2(left, centre.y), 0.0)
		"Smoke Screen":
			var smoke := SmokeScreen.new()
			smoke.line = line
			add_child(smoke)
		"Frost Bridge":
			var bridge := FrostBridge.new()
			bridge.line = line
			add_child(bridge)
		"Geyser":
			var geyser := Geyser.new()
			geyser.position = SpellTargets.surface_over(get_world_2d(), centre)  # under the middle of the peak, on the surface
			add_child(geyser)
		"Bramble":
			var thorns := Bramble.new()
			thorns.line = line
			add_child(thorns)
		"Liana":
			var vine := Liana.new()
			vine.line = line
			add_child(vine)
		"Great Oak":
			var oak := GreatOak.new()
			oak.position = line[0]  # the trunk's foot
			add_child(oak)
		"Lily Pads":
			var pads := LilyPads.new()
			pads.line = line
			add_child(pads)
		"Mudslide":
			var sand := Mudslide.new()
			sand.width = SpellData.width_of(line)
			sand.position = centre
			add_child(sand)
		"Ice Prison":
			var prison := IcePrison.new()
			prison.rect = info["rect"]
			add_child(prison)


## A dark wizard's spell resolves here, placed from the wizard rather than the player. It pays for it first.
func _on_wizard_cast(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary, wizard: Node2D) -> void:
	if not is_instance_valid(wizard) or wizard.is_dead():
		return
	wizard.stamina -= SpellData.cost_for(spell, info)
	wizard.last_spell = spell
	spawn_spell(spell, targeting, origin, aim, info, wizard)


func _on_misfire() -> void:
	player.drain(MISFIRE_COST)
	Sfx.play("misfire", player.center())
	FloatText.spawn(self, get_global_mouse_position() + Vector2(0, -22), "Misfire", Color("#ff6b6b"), 0.9)
	Fx.burst(self, get_global_mouse_position(), Color(0.6, 0.6, 0.65), 8, 80.0, 0.3)


func _start_ritual() -> void:
	if player.is_muted():
		_on_feedback("Muted: no rituals for %.0f more seconds" % player.mute_time, Color.ORANGE)
		return
	ritual.open()
	# Stop this key press from also reaching the text box it just opened.
	get_viewport().set_input_as_handled()


func _on_ritual_finished(id: String, acc: float, unfinished: bool) -> void:
	var data: Dictionary = RitualInput.RITUALS[id]
	if unfinished:
		# Stopping a chant partway lets the words fade harmlessly; only a garbled chant backfires.
		_on_feedback("The chant trails off unfinished. Nothing happens.", Color.GRAY)
		return
	if data["kind"] == "toggle":
		_on_toggle_chant(data, acc)
		return

	var power := RitualInput.power_for(acc)
	var acc_text := "accuracy %d%%" % roundi(acc * 100.0)
	if power <= 0.0:
		player.take_damage(15)
		Sfx.play("explosion", player.center())
		Fx.impact(self, player.center(), Color("#ff4a4a"), 50.0)
		_on_feedback("RITUAL BACKFIRED (%s)" % acc_text, Color.RED)
		return

	var ritual_name: String = RitualInput.RITUALS[id]["name"]
	var power_text := "%s, power %d%%" % [acc_text, roundi(power * 100.0)]
	Sfx.play("ritual_ok", player.center())
	Fx.pop(self, player.global_position + Vector2(0, -2), "magic_02", Color(1.0, 0.9, 0.6), 80.0, 0.8, 1.3, 2.0)
	match id:
		"second_wind":
			player.heal(roundi(45.0 * power))
			Sfx.play("heal", player.center())
			Fx.burst(self, player.center(), Color("#7dff9a"), 20, 90.0, 0.8, true, "star_04")
		"boundless":
			player.grant_unlimited(20.0)
		"double_jump":
			player.grant_air_jump(20.0)
		"bonfire":
			var fire := Bonfire.new()
			add_child(fire)
			fire.power = power
			fire.global_position = _ground_below(player.center())
	_on_feedback("RITUAL %s (%s)" % [ritual_name, power_text], Color.GREEN)


## A toggle chant shows or hides a HUD module. Incantations cost no stamina.
func _on_toggle_chant(data: Dictionary, acc: float) -> void:
	if acc < RitualInput.BACKFIRE_BELOW:
		_on_feedback("The words don't take hold.", Color.GRAY)
		return
	var module: String = data["module"]
	_revealed[module] = not _revealed[module]
	var label: String = {"minimap": "Minimap", "insight": "Insight"}[module]
	Sfx.play("ritual_ok", player.center(), -6.0)
	_on_feedback("%s %s." % [label, "revealed" if _revealed[module] else "hidden"], Color.WHITE)


func _on_ritual_cancelled() -> void:
	_on_feedback("Ritual interrupted.", Color.ORANGE)


func _on_player_damaged(_amount: int) -> void:
	ritual.cancel()


func _on_debuff_applied(kind: String) -> void:
	match kind:
		"mute":
			ritual.cancel()
			_on_feedback("Muted! No rituals for %.0f seconds." % player.mute_time, Color.ORANGE)
		"root":
			_on_feedback("Rooted! You can't move for a moment.", Color.ORANGE)
		"blind":
			_on_feedback("Blinded! Your gesture trail is hidden.", Color.ORANGE)


## Swap the held focus for the nearest one on the floor; the held one is dropped where you stand.
func _try_pickup() -> void:
	var nearest: FocusItem = null
	for item in get_tree().get_nodes_in_group("items"):
		if item.global_position.distance_to(player.global_position) < PICKUP_RANGE:
			nearest = item
			break
	if nearest == null:
		_on_feedback("Nothing to pick up here.", Color.GRAY)
		return
	var held: String = player.focus
	player.focus = nearest.focus_id
	Levels.held_focus = player.focus
	nearest.queue_free()
	_spawn_focus(held, _ground_below(player.center()))
	Sfx.play("pickup", player.center())
	_on_feedback("Picked up the %s. Dropped the %s." % [
		FocusItem.FOCI[player.focus]["name"], FocusItem.FOCI[held]["name"]], Color.WHITE)


func _spawn_focus(id: String, pos: Vector2) -> void:
	var item := FocusItem.new()
	add_child(item)
	item.setup(id, pos)


func _on_feedback(text: String, color: Color) -> void:
	hud.show_message(text, color)


## True when a point is on or just above solid ground, within one tile. Platforms count.
## True when a point is on something a stone wall can grow out of: the ground, a platform, or another stone wall.
func _is_ground_at(point: Vector2) -> bool:
	var col := floori(point.x / TILE)
	var row := floori(point.y / TILE)
	if _cells.has(Vector2i(col, row)) or _cells.has(Vector2i(col, row + 1)):
		return true
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


## True when a column is within two columns of one already taken.
func _too_close(col: int, taken: Array[int]) -> bool:
	for other in taken:
		if absi(col - other) < 2:
			return true
	return false


## While Insight is on, hovering an enemy shows its health, weaknesses and resistances in a small tooltip.
func _update_insight() -> void:
	var mob: Node2D = _mob_under_pointer() if _revealed["insight"] else null
	_insight_tip.visible = mob != null
	if mob == null:
		return
	var data: Dictionary = Mob.KINDS[mob.kind]
	var weak := _school_bb(data["weak"]) if data["weak"] != "" else "nothing"
	var resist := _school_bb(data["resist"]) if data["resist"] != "" else "nothing"
	_insight_text.text = "[b]%s[/b]   Health %d / %d\nWeak to %s\nResists %s\n[i]%s[/i]" % [
		data["name"], mob.hp, mob.max_hp,
		weak, resist, data["desc"],
	]
	_insight_tip.position = get_viewport().get_mouse_position() + Vector2(18, 18)


## The enemy closest to the pointer, if it is within reach.
func _mob_under_pointer() -> Node2D:
	var pointer := get_global_mouse_position()
	var best: Node2D = null
	var best_distance := INSIGHT_REACH
	for mob in get_tree().get_nodes_in_group("mobs"):
		var distance: float = mob.center().distance_to(pointer)
		if distance < best_distance:
			best_distance = distance
			best = mob
	return best


func _school_bb(school: String) -> String:
	return "[color=#%s]%s[/color]" % [SpellData.SCHOOL_COLORS[school].to_html(false), school]


## The surface directly below a point (the floor or a platform), so things placed there sit on the ground.
func _ground_below(point: Vector2) -> Vector2:
	return SpellTargets.ground_below(get_world_2d(), point)


## Debug: summons one enemy of a kind on the far side of the screen, ahead of where the wizard is facing.
func summon_far_side(kind: String) -> void:
	var zoom: float = player.get_node("Camera2D").zoom.x
	var half_view := get_viewport().get_visible_rect().size.x * 0.5 / zoom
	var x := clampf(player.global_position.x + player.facing * half_view * 0.75, ArenaGen.left_edge() + 24.0, ArenaGen.right_edge() - 24.0)
	var ground := SpellTargets.solid_below(get_world_2d(), Vector2(x, ArenaGen.GROUND_Y - 4.0 * TILE))
	_add_mob(kind, ground)


## Debug: removes every enemy at once.
func clear_enemies() -> void:
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.take_damage(9999)

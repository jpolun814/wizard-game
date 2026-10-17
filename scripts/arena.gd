extends Node2D

## Arena: a flat hand-built floor, the player, mobs with different debuffs, foci to pick up,
## fast spells, rituals and the spellbook.

const MOB_SCENE := preload("res://scenes/mob.tscn")
const TILE := 16

## Tile indexes in res://art/tiles.png, left to right.
const GRASS := 0
const DIRT := 1
const STONE := 2
const WOOD := 3
const FLOOR_Y := 176.0       # where dropped items rest
const MUZZLE_OFFSET := 30.0  # spawn directional spells just outside the player body
const BARRIER_SECONDS := 2.5
const MISFIRE_COST := 10.0
const PICKUP_RANGE := 48.0

@onready var player: CharacterBody2D = $Player

var caster: Caster
var ritual: RitualInput
var spellbook: Spellbook
var _feedback_label: Label
var _status_label: Label
var _hp_bar: ProgressBar
var _stamina_bar: ProgressBar
var _minimap: Minimap
var _insight_tip: PanelContainer  # the hover tooltip Insight shows over an enemy
var _insight_text: RichTextLabel
## The minimap is hidden until its chant brings it into view. Health and stamina are always shown.
var _revealed := {"minimap": false, "insight": false}
var _rng := RandomNumberGenerator.new()
var debug_panel: DebugPanel  # F1 opens it: buttons that summon enemies for testing
var _cells := {}  # the generated arena's tiles, see ArenaGen


func _ready() -> void:
	# A new random arena each run. Build it before anything that reads the terrain.
	_rng.randomize()
	_cells = ArenaGen.build(_rng)
	_build_ground()
	# The camera follows the player but never shows past the walls at either end of the map.
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_left = ArenaGen.LEFT_WALL * TILE
	camera.limit_right = (ArenaGen.RIGHT_WALL + 1) * TILE
	_build_hud()

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

	spellbook = Spellbook.new()
	add_child(spellbook)
	debug_panel = DebugPanel.new()
	debug_panel.arena = self
	add_child(debug_panel)
	debug_panel.visible = true  # open for testing; F1 hides it

	# The player starts on open ground. The waves come from the director, one level at a time.
	var open := _clear_columns()
	player.position = Vector2(open[_rng.randi() % open.size()] * TILE + 8.0, 150.0)
	var director := WaveDirector.new()
	director.arena = self
	add_child(director)
	director.wave_cleared.connect(_on_wave_cleared)
	director.start(Levels.all_waves()[Levels.wave_index])


## Adds one enemy of a kind on open ground, away from the player and from the other enemies.
## Returns false if no spot was found.
func spawn_mob(kind: String) -> bool:
	var open := _clear_columns()
	var player_col := roundi((player.position.x - 8.0) / TILE)
	var taken: Array[int] = []
	for mob in get_tree().get_nodes_in_group("mobs"):
		taken.append(roundi((mob.position.x - 8.0) / TILE))
	for attempt in 40:
		var c: int = open[_rng.randi() % open.size()]
		if absi(c - player_col) >= 6 and not _too_close(c, taken):
			var mob := MOB_SCENE.instantiate()
			mob.kind = kind
			mob.position = Vector2(c * TILE + 8.0, 150.0)
			mob.player = player
			add_child(mob)
			Fx.burst(self, mob.position + Vector2(0, 20), Color(0.8, 0.75, 0.6), 10, 90.0, 0.4)
			return true
	return false


## Once a wave is cleared, a portal opens at the far end of the map. Walking through it brings the next wave, in a new map.
func _on_wave_cleared() -> void:
	var portal := Portal.new()
	portal.position = Vector2((ArenaGen.RIGHT_WALL - 2) * TILE + 8.0, FLOOR_Y - 26.0)
	portal.body_entered.connect(_on_portal_entered)
	add_child(portal)


var _leaving := false


func _on_portal_entered(body: Node2D) -> void:
	if body != player or _leaving:
		return
	_leaving = true
	# The map ends with the last wave; going through the portal after it starts the run again from the first.
	Levels.wave_index = (Levels.wave_index + 1) % Levels.all_waves().size()
	get_tree().reload_current_scene()


func _input(event: InputEvent) -> void:
	var toggle := event as InputEventKey
	if toggle and toggle.pressed and not toggle.echo and toggle.keycode == KEY_F1:
		debug_panel.visible = not debug_panel.visible
		return
	var key := event as InputEventKey
	if ritual.visible or key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_start_ritual()
		KEY_E:
			_try_pickup()


func _process(_delta: float) -> void:
	spellbook.lift_for_typing(ritual.visible)
	# Casting and movement pause while the ritual box is open, so typing doesn't move or cast.
	# The spellbook doesn't pause anything, so it can stay open while you play.
	var busy := ritual.visible
	caster.set_casting_enabled(not busy)
	player.movement_enabled = not busy
	caster.anchor = player.global_position
	caster.blocked_rects = _visible_hud_rects()
	caster.hide_trail = player.is_blind()
	player.casting = caster._active_mask != 0  # the wizard holds the staff up while a stroke is drawn
	player.cast_color = caster._school_color(caster._active_mask)  # and the crystal shows the school being drawn
	caster.tolerance = FocusItem.FOCI[player.focus]["tolerance"]

	_hp_bar.visible = true
	_hp_bar.value = player.hp
	_hp_bar.get_node("Caption").text = "Health  %d / %d" % [player.hp, player.MAX_HP]
	_stamina_bar.visible = true
	_stamina_bar.value = player.stamina
	_stamina_bar.get_node("Caption").text = "Stamina  %d / %d" % [player.stamina, player.MAX_STAMINA]
	_minimap.visible = _revealed["minimap"]
	_update_insight()

	# Only active debuffs appear here. The held focus is visible in the world.
	_status_label.text = player.status_text()


func _build_ground() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_physics_layer()

	var source := TileSetAtlasSource.new()
	source.texture = load("res://art/tiles.png")
	source.texture_region_size = Vector2i(TILE, TILE)
	var source_id := tile_set.add_source(source)
	for i in 4:
		source.create_tile(Vector2i(i, 0))
		var tile_data := source.get_tile_data(Vector2i(i, 0), 0)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
		]))

	var ground := TileMapLayer.new()
	ground.tile_set = tile_set
	add_child(ground)
	var cells := _terrain()
	for cell in cells:
		ground.set_cell(cell, source_id, Vector2i(cells[cell], 0))


## The map as tile blocks. Cell (0, 0) is the top-left corner of the arena, and y grows downward.
## Ground surface is row 12 (y = 192 px); everything above it is air.
func _terrain() -> Dictionary:
	return _cells


func _fill(cells: Dictionary, c0: int, r0: int, c1: int, r1: int, tile: int) -> void:
	for c in range(c0, c1 + 1):
		for r in range(r0, r1 + 1):
			cells[Vector2i(c, r)] = tile


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var view := get_viewport().get_visible_rect().size

	_status_label = Label.new()
	_status_label.position = Vector2(16, 14)
	hud.add_child(_status_label)

	_hp_bar = _make_bar(Vector2(16, 40), "Health")
	hud.add_child(_hp_bar)
	_stamina_bar = _make_bar(Vector2(16, 68), "Stamina")
	hud.add_child(_stamina_bar)

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

	_feedback_label = Label.new()
	_feedback_label.position = Vector2(16, view.y - 36.0)
	_feedback_label.text = ""
	hud.add_child(_feedback_label)


## Floor columns with nothing above them, so the player, enemies and staff never start inside a platform.
func _clear_columns() -> Array[int]:
	var cols: Array[int] = []
	for c in ArenaGen.open_columns(_cells):
		var clear := true
		for r in ArenaGen.GROUND_ROW:
			# A character is two tiles wide, so the columns on either side must be clear too.
			for dc in [-1, 0, 1]:
				if _cells.has(Vector2i(c + dc, r)):
					clear = false
		if clear:
			cols.append(c)
	if cols.is_empty():
		return ArenaGen.open_columns(_cells)
	return cols


## Clicking a HUD module hides it again.
func _on_hud_clicked(event: InputEvent, module: String) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	_revealed[module] = false
	var label := "Minimap"
	_on_feedback("%s hidden. Say its chant again to bring it back." % label, Color.WHITE)


## The visible HUD modules on screen. The caster ignores presses that start over them.
func _visible_hud_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for control in [_hp_bar, _stamina_bar, _minimap]:
		if control.visible:
			rects.append(control.get_global_rect())
	if debug_panel.visible:
		rects.append(debug_panel.panel.get_global_rect())
	return rects


## A bar with its name and value written inside it, so you can tell what it shows.
func _make_bar(pos: Vector2, title: String) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.position = pos
	bar.custom_minimum_size = Vector2(230, 22)
	bar.size = Vector2(230, 22)
	bar.max_value = 100
	bar.show_percentage = false
	bar.visible = false
	var label := Label.new()
	label.name = "Caption"
	label.text = title
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(8, 2)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color.WHITE)
	bar.add_child(label)
	return bar


func _on_cast_resolved(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary) -> void:
	player.play_cast_release()
	var cost := SpellData.cost_for(spell, info)
	if not player.spend(cost):
		_on_feedback("Not enough stamina for %s (needs %d)" % [spell, cost], Color.ORANGE)
		return

	spawn_spell(spell, targeting, origin, aim, info, player.global_position)


## Makes a spell take effect in the world. The player's spells and the dark wizard's both come through here.
## from is where the caster stands.
func spawn_spell(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary, from: Vector2) -> void:
	# Barrier wraps the caster rather than appearing somewhere in the world.
	if spell == "Barrier":
		player.raise_shield(BARRIER_SECONDS)
		return
	# Blink zips the player along the stroke, so it starts from the caster, not the stroke.
	if spell == "Blink":
		_blink(aim, info.get("length", 0.0))
		return
	# Icicles, snowfall, tornados and volcanoes are placed where they were drawn, not at one point.
	if targeting == "shape":
		_place_shapes(spell, info)
		return
	# Stone Wall rises from where the stroke began, on the ground. Angled spells keep their origin and aim.
	if targeting == "directional" and spell != "Stone Wall":
		# Other directional spells leave the caster along the stroke; positional ones appear where drawn.
		origin = from + Vector2.from_angle(aim) * MUZZLE_OFFSET
	var effect := SpellEffect.new()
	add_child(effect)
	effect.zone_radius = info.get("radius", 0.0)
	effect.setup(spell, origin, aim)
	effect.broke.connect(func() -> void: _on_feedback("%s broke" % spell, Color.ORANGE))


## Picks the dark wizard's next spell from the situation and draws it at the player. Returns false if it is not
## casting this moment: nothing is worth casting, or it cannot afford what is.
func wizard_cast(wizard: Node2D) -> bool:
	var choice := _choose_wizard_spell(wizard)
	if choice == "":
		return false
	var data: Dictionary = SpellData.SPELLS[choice]
	var template := GestureTemplates.preview_points(data["gesture"])
	if template.size() < 2:
		return false
	wizard.stamina -= SpellData.cost(choice)
	wizard.last_spell = choice
	var target: Vector2 = player.global_position
	var points := PackedVector2Array()
	if data["targeting"] == "positional" or data["targeting"] == "shape":
		var centre := Vector2.ZERO
		for p in template:
			centre += p / template.size()
		for p in template:
			points.append(target + p - centre)
	else:
		var start: Vector2 = wizard.global_position + Vector2(0, -20)
		var angle := (target - start).angle() - (template[template.size() - 1] - template[0]).angle()
		for p in template:
			points.append(start + (p - template[0]).rotated(angle))
	wizard.start_drawing(_densify(points), SpellData.SCHOOL_COLORS[data["school"]], Callable(self, "_finish_wizard_cast").bind(wizard, data["buttons"]))
	return true


## Weighs each spell the dark wizard can cast against the fight, then picks one at random by weight.
func _choose_wizard_spell(wizard: Node2D) -> String:
	var names := ["Ignite", "Frostbolt", "Spark", "Stonefall", "Icicles", "Volcano", "Tornado"]
	var total := 0.0
	var scores := []
	for spell_name in names:
		var score := _wizard_score(spell_name, wizard)
		scores.append(score)
		total += score
	if total <= 0.0:
		return ""
	var pick := randf() * total
	for i in names.size():
		pick -= scores[i]
		if pick <= 0.0 and scores[i] > 0.0:
			return names[i]
	return ""


## How much a spell is worth right now: close or far, whether the player is moving or slowed, and whether the
## wizard just cast it. A spell it cannot afford is worth nothing.
func _wizard_score(spell_name: String, wizard: Node2D) -> float:
	if wizard.stamina < SpellData.cost(spell_name):
		return 0.0
	var gap: float = player.global_position.distance_to(wizard.global_position)
	var still: bool = player.velocity.length() < 25.0
	var score := 1.0
	match spell_name:
		"Ignite":
			score = 2.0 if gap > 120.0 else 0.8
		"Frostbolt":
			score = 0.3 if player.slow_time > 0.0 else 1.8
		"Spark":
			score = 2.0 if gap < 260.0 else 0.6
		"Stonefall":
			score = 2.5 if still else 0.5
		"Icicles":
			score = 1.4 if player.is_on_floor() else 0.4
		"Volcano":
			score = 1.6 if gap > 140.0 else 0.3
		"Tornado":
			score = 1.2 if gap < 180.0 else 0.2
	if spell_name == wizard.last_spell:
		score *= 0.25  # it does not keep repeating the same spell
	return score


## The stroke with points in between, so it is as dense as one drawn with the mouse.
func _densify(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size() - 1:
		var steps := maxi(1, int(points[i].distance_to(points[i + 1]) / 2.0))
		for k in steps:
			out.append(points[i].lerp(points[i + 1], float(k) / steps))
	out.append(points[points.size() - 1])
	return out


## A dark wizard's spell resolves here, placed from the wizard rather than the player.
func _on_wizard_cast(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary, wizard: Node2D) -> void:
	spawn_spell(spell, targeting, origin, aim, info, wizard.global_position)


const BLINK_DAMAGE := 8
const INSIGHT_REACH := 40.0  # how close the pointer must be to an enemy for Insight to show it


## Blink: the caster zips along the stroke, stopping short of walls. Foes in the way take damage.
func _blink(aim: float, length: float) -> void:
	var dir := Vector2.from_angle(aim)
	var start := player.global_position
	var end := start + dir * minf(length, SpellData.BLINK_MAX)
	var query := PhysicsRayQueryParameters2D.create(start, end)
	query.collision_mask = 1
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit["position"] - dir * 14.0
	for mob in get_tree().get_nodes_in_group("mobs"):
		var closest := Geometry2D.get_closest_point_to_segment(mob.global_position, start, end)
		if closest.distance_to(mob.global_position) <= 24.0:
			mob.take_damage(BLINK_DAMAGE, "Storm")
	player.global_position = end
	Fx.burst(self, start, SpellData.SCHOOL_COLORS["Storm"], 12, 120.0, 0.25)
	Fx.burst(self, end, SpellData.SCHOOL_COLORS["Storm"], 12, 120.0, 0.25)



func _on_misfire() -> void:
	player.drain(MISFIRE_COST)


func _start_ritual() -> void:
	if player.is_muted():
		_on_feedback("Muted: no rituals for %.0f more seconds" % player.mute_time, Color.ORANGE)
		return
	ritual.open()
	# Stop this key press from also reaching the text box it just opened.
	get_viewport().set_input_as_handled()


func _on_ritual_finished(id: String, acc: float) -> void:
	var data: Dictionary = RitualInput.RITUALS[id]
	if data["kind"] == "toggle":
		_on_toggle_chant(data, acc)
		return

	var power := RitualInput.power_for(acc)
	var acc_text := "accuracy %d%%" % roundi(acc * 100.0)
	if power <= 0.0:
		player.take_damage(15)
		_on_feedback("RITUAL BACKFIRED (%s)" % acc_text, Color.RED)
		return

	var ritual_name: String = RitualInput.RITUALS[id]["name"]
	var power_text := "%s, power %d%%" % [acc_text, roundi(power * 100.0)]
	match id:
		"second_wind":
			player.heal(roundi(30.0 * power))
		"boundless":
			player.grant_unlimited(15.0)
		"bonfire":
			var fire := Bonfire.new()
			add_child(fire)
			fire.power = power
			fire.global_position = _ground_below(player.global_position)
	_on_feedback("RITUAL %s (%s)" % [ritual_name, power_text], Color.GREEN)


## A toggle chant shows or hides a HUD module. Incantations cost no stamina.
func _on_toggle_chant(data: Dictionary, acc: float) -> void:
	if acc < RitualInput.BACKFIRE_BELOW:
		_on_feedback("The words don't take hold.", Color.GRAY)
		return
	var module: String = data["module"]
	_revealed[module] = not _revealed[module]
	var label: String = {"minimap": "Minimap", "insight": "Insight"}[module]
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
	nearest.queue_free()
	_spawn_focus(held, Vector2(player.global_position.x, FLOOR_Y))
	_on_feedback("Picked up the %s. Dropped the %s." % [
		FocusItem.FOCI[player.focus]["name"], FocusItem.FOCI[held]["name"]], Color.WHITE)


func _spawn_focus(id: String, pos: Vector2) -> void:
	var item := FocusItem.new()
	add_child(item)
	item.setup(id, pos)


func _on_feedback(text: String, color: Color) -> void:
	_feedback_label.text = text
	_feedback_label.modulate = color


## True when a point is on or just above solid ground, within one tile.
func _is_ground_at(point: Vector2) -> bool:
	var col := floori(point.x / TILE)
	var row := floori(point.y / TILE)
	return _cells.has(Vector2i(col, row)) or _cells.has(Vector2i(col, row + 1))


## True when a column is within two columns of one already taken.
func _too_close(col: int, taken: Array[int]) -> bool:
	for other in taken:
		if absi(col - other) < 3:
			return true
	return false


## Icicles stand as the triangles they were drawn as. Snowfall is a band along the drawn line.


func _place_shapes(spell: String, info: Dictionary) -> void:
	if spell == "Icicles":
		for tri in info["shapes"]:
			var centre: Vector2 = (tri[0] + tri[1] + tri[2]) / 3.0
			var local := PackedVector2Array()
			for p in tri:
				local.append(p - centre)
			var effect := SpellEffect.new()
			add_child(effect)
			effect.polygon = local
			effect.setup(spell, centre, 0.0)
	elif spell == "Tornado" or spell == "Volcano":
		var centre := Vector2.ZERO
		for p in info["line"]:
			centre += p / info["line"].size()
		if spell == "Volcano":
			centre = _ground_below(centre)
		var node: Node2D = Tornado.new() if spell == "Tornado" else Volcano.new()
		node.position = centre
		add_child(node)
	elif spell == "Snowfall":
		var line: PackedVector2Array = info["line"]
		var left := line[0].x
		var right := line[0].x
		var mid_y := 0.0
		for p in line:
			left = minf(left, p.x)
			right = maxf(right, p.x)
			mid_y += p.y / line.size()
		var effect := SpellEffect.new()
		add_child(effect)
		effect.polygon = PackedVector2Array([Vector2(0, -60), Vector2(right - left, -60), Vector2(right - left, 60), Vector2(0, 60)])
		effect.setup(spell, Vector2(left, mid_y), 0.0)


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
		data["name"], mob.hp, Mob.MAX_HP,
		weak, resist, data["desc"],
	]
	_insight_tip.position = get_viewport().get_mouse_position() + Vector2(18, 18)


## The enemy closest to the pointer, if it is within reach.
func _mob_under_pointer() -> Node2D:
	var pointer := get_global_mouse_position()
	var best: Node2D = null
	var best_distance := INSIGHT_REACH
	for mob in get_tree().get_nodes_in_group("mobs"):
		var distance: float = (mob.global_position + Vector2(0, -15)).distance_to(pointer)
		if distance < best_distance:
			best_distance = distance
			best = mob
	return best


func _school_bb(school: String) -> String:
	return "[color=#%s]%s[/color]" % [SpellData.SCHOOL_COLORS[school].to_html(false), school]


## The surface directly below a point (the floor or a platform), so things placed there sit on the ground.
func _ground_below(point: Vector2) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(point, point + Vector2(0, 400))
	query.collision_mask = 1  # terrain only
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else point + Vector2(0, 25)


## Debug: summons one enemy of a kind on the far side of the screen, ahead of where the wizard is facing.
func summon_far_side(kind: String) -> void:
	var zoom: float = player.get_node("Camera2D").zoom.x
	var half_view := get_viewport().get_visible_rect().size.x * 0.5 / zoom
	var x := clampf(player.global_position.x + player._facing * half_view * 0.8, ArenaGen.LEFT_WALL * TILE + 16.0, ArenaGen.RIGHT_WALL * TILE - 16.0)
	var mob := MOB_SCENE.instantiate()
	mob.kind = kind
	mob.player = player
	mob.position = Vector2(x, player.global_position.y - 40.0)
	add_child(mob)


## A dark wizard has finished drawing its stroke: the spell is cast from the stroke it drew.
func _finish_wizard_cast(points: PackedVector2Array, wizard: Node2D, mask: int) -> void:
	if is_instance_valid(wizard):
		wizard.caster.cast_stroke(mask, points)

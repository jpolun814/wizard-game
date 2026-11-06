class_name Tutorial
extends Lab

## The tutorial room: a level stretch of ground with something in the way at each place, and the pages that answer it lying at the foot of it. The book
## starts empty, as in a match; reading a page (Tab) puts its spell in the book. Nothing is explained on screen but the keys to walk and jump at the very
## start. What shuts the way: a dummy and a skeleton that strike down whoever walks past them standing, a pond and a pit too wide to cross, turrets that
## hit whoever has no cover, thorns too long to walk through and a cliff too high to jump. It is the waiting room's own ground, but stamina runs out here as
## it does in a match, and the portal at the far end leads back to the first screen.

const POND_SPAN := Vector2i(24, 44)   # water too wide to jump, and too deep to wade
const POND_ROWS := 4.0
const CHUNKS := 52  # the room is wide, so that the places are far apart
const PANEL := Color("#1f1528")
const WORDS := Color("#efe3cf")
const MENU := "res://scenes/menu.tscn"

## The pages that lie in the room: the column each lies at and its pages. Pages that go together lie fanned out like cards, as a wizard's first pages do in a
## match, and one read takes them all; any of them does the work at its place.
const PAGE_SPOTS := [
	[-16, ["Ignite", "Frostbolt", "Stonefall"]],
	[3, ["Faint"]],
	[17, ["Frost Bridge", "Lily Pads"]],
	[59, ["Barrier", "Stone Wall"]],
	[108, ["Ignite", "Fire Breath"]],
	[156, ["chant:double_jump"]],
	[192, ["Rocket Jump", "Featherfall", "Push"]],
]
const STARTS := [-31, -22, 0, 12, 54, 104, 154, 186]   # where whoever falls is on their feet again: the start of the place they were working on
const HINT_UNTIL := -21.0   # the keys to walk and jump show until the wizard has gone this far
const CLIFF_COL := 170       # from here on the ground is this many rows higher than before: too high to jump, near enough for a second jump
const CLIFF_ROWS := 7.0
const GAP_SPAN := Vector2i(204, 229)   # a pit far too wide to jump, on the high ground: the spells listed carry a jump across it
const GAP_ROWS_DOWN := 4.0
const THICKET_SPAN := Vector2i(118, 150)   # thorns across the way, far too long to walk through
const THICKET_LAYERS := 10
const TURRETS := [70, 82, 94]
const TURRET_ZONE := Vector2i(62, 106)   # a hit from a turret here is a death
const TURRET_PATIENCE := 0.8   # seconds in the sight of a turret, with nothing in the way, before its shot finds the wizard
const DUMMY_COL := -6       # in the way at the first place: whoever walks past it while it stands is struck down
const SKELETON_COL := 11    # in the way at the second: whoever walks past it while it is awake is struck down
const DUMMY_HP := 36  # three fireballs: the tutorial's dummy falls quickly, so each try is seen through

var _guide: CanvasLayer
var _hint: PanelContainer   # the keys to walk and jump, at the start
var _thickets: Array[Bramble] = []
var _dummy: Mob
var _skeleton: Mob
var _exposed := 0.0   # how long the wizard has been in the sight of a turret


func _init() -> void:
	ArenaGen.chunk_count = CHUNKS
	ArenaGen.right_wall = ArenaGen.FIRST_COL + ArenaGen.CHUNK_WIDTH * CHUNKS


func _exit_tree() -> void:
	ArenaGen.chunk_count = ArenaGen.CHUNK_COUNT  # the other rooms are their usual width
	ArenaGen.right_wall = ArenaGen.FIRST_COL + ArenaGen.CHUNK_WIDTH * ArenaGen.CHUNK_COUNT


func _build_map() -> Variant:
	var heights := PackedFloat32Array()
	heights.resize(ArenaGen.right_wall - ArenaGen.FIRST_COL)
	for col in range(ArenaGen.FIRST_COL, CLIFF_COL):
		heights[col - ArenaGen.FIRST_COL] = CLIFF_ROWS  # the low ground, which the high ground at the end of the room stands over
	_dig_into(heights, POND_SPAN, CLIFF_ROWS, POND_ROWS)
	_dig_into(heights, GAP_SPAN, 0.0, GAP_ROWS_DOWN)
	return ArenaGen.build(_rng, heights)


func _begin_encounter(camera: Camera2D) -> void:
	super(camera)
	player.infinite_time = 0.0  # the waiting room never lets stamina run out, but here it does, as it does in a match: this is where it is learned
	player.ledger = Ledger.of([])  # and the book is empty, as it is at the start of a match
	spellbook.refresh()
	player.damaged.connect(_on_player_hurt)
	_guide = CanvasLayer.new()
	_guide.layer = 4
	add_child(_guide)
	_show_keys()
	for spot: Array in PAGE_SPOTS:
		var page := PagePickup.new()
		var names: Array = spot[1]
		page.page = names[0]
		if names.size() > 1:
			page.spoils.assign(names)
			page.fan = true
		page.position = Vector2(ArenaGen.column_x(spot[0]), ArenaGen.surface_y(_cells, spot[0]))
		add_child(page)


## A pit of the same shape as the others, dug down from the ground at `base` rows.
func _dig_into(heights: PackedFloat32Array, span: Vector2i, base: float, rows: float) -> void:
	for col in range(span.x, span.y + 1):
		var edge := mini(col - span.x, span.y - col)
		var t := clampf((edge + 0.5) / 3.0, 0.0, 1.0)
		heights[col - ArenaGen.FIRST_COL] = base + rows * t * t * (3.0 - 2.0 * t)


func _add_ponds() -> void:
	var pond := Pond.new()
	pond.width = (POND_SPAN.y - POND_SPAN.x + 1) * float(ArenaGen.TILE)
	pond.depth = POND_ROWS * ArenaGen.TILE + 16.0
	pond.position = Vector2(POND_SPAN.x * float(ArenaGen.TILE), ArenaGen.GROUND_Y + CLIFF_ROWS * ArenaGen.TILE)
	pond.ground = _ground
	add_child(pond)


func _add_targets() -> void:
	_dummy = _add_mob("dummy", Vector2(ArenaGen.column_x(DUMMY_COL), ArenaGen.surface_y(_cells, DUMMY_COL))) as Mob
	_dummy.max_hp = DUMMY_HP
	_dummy.hp = DUMMY_HP
	_dummy.facing = -1.0
	_dummy.felled_stays = true
	_skeleton = _add_mob("basic", Vector2(ArenaGen.column_x(SKELETON_COL), ArenaGen.surface_y(_cells, SKELETON_COL))) as Mob
	_skeleton.facing = -1.0
	_skeleton.faint_stays = true
	_plant_thicket()
	for col: int in TURRETS:
		var turret := _add_mob("turret", Vector2(ArenaGen.column_x(col), ArenaGen.surface_y(_cells, col)))
		turret.facing = -1.0


## The thorns across the way at the Plants place: planted like the world's own, so fire burns them away.
func _plant_thicket() -> void:
	var points := PackedVector2Array()
	for col in range(THICKET_SPAN.x, THICKET_SPAN.y + 1):
		for half in 2:
			var x := (col + half * 0.5) * float(ArenaGen.TILE)
			points.append(Vector2(x, ArenaGen.surface_y(_cells, col)))
	for layer in THICKET_LAYERS:  # each layer pricks on its own, so that walking all the way through is more than a wizard can take
		var thorns := Bramble.new()
		thorns.planted_ground = points
		add_child(thorns)
		_thickets.append(thorns)


func _title() -> String:
	return "Tutorial"


func _scene_name() -> String:
	return "tutorial"


## The book on its stand here does not start a match: touching it leads back to the first screen too.
func _on_book_touched(body: Node2D) -> void:
	_on_portal_entered(body)


## The portal leads back to the first screen.
func _on_portal_entered(body: Node2D) -> void:
	if body != player or _leaving:
		return
	_leaving = true
	Sfx.play("portal_enter")
	var fade := create_tween()
	fade.tween_property(player, "modulate:a", 0.0, 0.25)
	fade.tween_callback(get_tree().change_scene_to_file.bind(MENU))


## Whoever falls is on their feet again at the start of the place they were working on, with the pages they had read, and has to get past what shut them off.
func _on_player_died() -> void:
	var column := player.global_position.x / float(ArenaGen.TILE)
	var back: int = STARTS[0]
	for start: int in STARTS:
		if start <= column:
			back = start
	super()
	_return_to.call_deferred(back)


func _return_to(column: int) -> void:
	player.global_position = Vector2(ArenaGen.column_x(column), ArenaGen.surface_y(_cells, column) - 20.0)
	player.velocity = Vector2.ZERO


## How many layers of thorns still stand at the Plants place.
func thorns_left() -> int:
	var left := 0
	for thorns in _thickets:
		if is_instance_valid(thorns) and not thorns.is_queued_for_deletion():
			left += 1
	return left


func _process(delta: float) -> void:
	super(delta)
	var column := player.global_position.x / float(ArenaGen.TILE)
	_rescue_from_pits(column)
	_guard_the_way(column)
	_watch_the_turrets(delta, column)
	_clear_spare_pages()
	if _hint != null and column > HINT_UNTIL:
		_hint.queue_free()
		_hint = null


## A page the book already holds is nothing to read, so it is taken away (the Burn Plants place lays Ignite again, for whoever skipped it).
func _clear_spare_pages() -> void:
	for pickup: PagePickup in get_tree().get_nodes_in_group("pages"):
		if not pickup.is_queued_for_deletion() and not pickup.gives(player.ledger):
			pickup.queue_free()


## Whoever has fallen into the pond or the pit is put back on its near edge, where they came from.
func _rescue_from_pits(column: float) -> void:
	for pit: Array in [[POND_SPAN, POND_ROWS], [GAP_SPAN, GAP_ROWS_DOWN]]:
		var span: Vector2i = pit[0]
		var edge := span.x - 3
		if column >= span.x and column <= span.y and player.global_position.y > ArenaGen.surface_y(_cells, edge) + (float(pit[1]) - 1.0) * ArenaGen.TILE:
			player.global_position = Vector2(ArenaGen.column_x(edge), ArenaGen.surface_y(_cells, edge) - 20.0)
			player.velocity = Vector2.ZERO


## The dummy and the skeleton strike down whoever walks past them while the dummy stands and the skeleton is awake. The skeleton does not leave its place.
func _guard_the_way(column: float) -> void:
	if player.dead:
		return
	if _dummy != null and is_instance_valid(_dummy) and not _dummy.is_dead() and column > DUMMY_COL + 1.5:
		player.take_damage(1000, false)
	if _skeleton != null and is_instance_valid(_skeleton) and not _skeleton.is_dead():
		if not _skeleton.is_fainted():
			_skeleton.apply_root(0.5)
			if column > SKELETON_COL + 1.5:
				player.take_damage(1000, false)


## Whoever stays in sight of a turret, with no Barrier round them and no stone between, is shot, for the turrets fire slowly and a runner could slip every
## one of them. A hit in this stretch is a death (see _strike_down).
func _watch_the_turrets(delta: float, column: float) -> void:
	if player.dead or player.has_shield() or column < TURRET_ZONE.x or column > TURRET_ZONE.y:
		_exposed = 0.0
		return
	var watcher: Mob
	for mob: Node in get_tree().get_nodes_in_group("mobs"):
		if mob is Mob and mob.kind == "turret" and not mob.is_dead() and mob.center().distance_to(player.center()) < 480.0:
			var query := PhysicsRayQueryParameters2D.create(mob.center(), player.center())
			query.collision_mask = 1
			if get_world_2d().direct_space_state.intersect_ray(query).is_empty() and not SpellTargets.sight_blocked(get_tree(), mob.center(), player.center()):
				watcher = mob
				break
	if watcher == null:
		_exposed = maxf(_exposed - delta, 0.0)
		return
	_exposed += delta
	if _exposed >= TURRET_PATIENCE:
		_exposed = 0.0
		Sfx.play("mob_shoot", watcher.center())
		Fx.burst(self, player.center(), Color("#7fd8ff"), 8, 120.0, 0.3, true)
		player.take_damage(6, true, true)


## A hit from a turret kills, in the stretch the turrets guard (the Barrier and the Stone Wall are what turn the shots away).
func _on_player_hurt(_amount: int) -> void:
	_strike_down.call_deferred()


func _strike_down() -> void:
	var column := player.global_position.x / float(ArenaGen.TILE)
	if not player.dead and column >= TURRET_ZONE.x and column <= TURRET_ZONE.y:
		player.take_damage(1000, false)


## The keys to walk and jump, on screen at the start: the one thing the room does not leave to be found out.
func _show_keys() -> void:
	_hint = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = Color("#8a6ac8").lightened(0.3)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14.0)
	_hint.add_theme_stylebox_override("panel", style)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 8)
	_hint.add_child(lines)
	for key: Array in [["A D", "Move."], ["W Space", "Jump."]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		for cap: String in String(key[0]).split(" ", false):
			line.add_child(Spellbook.KeyCap.new(cap))
		var words := Label.new()
		words.text = key[1]
		words.add_theme_font_size_override("font_size", 20)
		words.add_theme_color_override("font_color", WORDS)
		line.add_child(words)
		lines.add_child(line)
	_guide.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 84)

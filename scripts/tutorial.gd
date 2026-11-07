class_name Tutorial
extends Lab

## The tutorial room: a level stretch of ground with something in the way at each place, and the pages that answer it lying at the foot of it. The book
## starts empty, as in a match; reading a page (Tab) puts its spell in the book. Nothing is explained on screen but the keys to walk and jump at the very
## start. What shuts the way: a dummy and a giant that strike down whoever walks past them standing, a pond and a pit too wide to cross, turrets that
## hit whoever has no cover, thorns too long to walk through, a cliff too high to jump, a gap too wide for one jump and a dark stretch of hidden spikes. The
## last gates ask for two things together (light and fire, a leap and fire). It is the waiting room's own ground, but stamina runs out here as it does in a
## match, and the portal at the far end leads back to the first screen.

const POND_SPAN := Vector2i(24, 44)   # water too wide to jump, shallow enough to wade, and full of piranhas
const POND_ROWS := 2.0
const CHUNKS := 195  # the room is wide, so that the places are far apart
const PANEL := Color("#1f1528")
const WORDS := Color("#efe3cf")
const MENU := "res://scenes/menu.tscn"

## The pages that lie in the room: the column each lies at and its pages. Pages that go together lie fanned out like cards, as a wizard's first pages do in a
## match, and one read takes them all; any of them does the work at its place.
const PAGE_SPOTS := [
	[-16, ["Ignite", "Frostbolt", "Stonefall"]],
	[-2, ["Faint"]],
	[17, ["Frost Bridge", "Lily Pads", "Spark"]],
	[52, ["Barrier", "Stone Wall", "Smoke Screen"]],
	[108, ["Ignite", "Fire Breath"]],
	[158, ["Liana"]],
	[176, ["chant:double_jump"]],
	[206, ["Flare", "Glowcap"]],
	[281, ["Rocket Jump", "Featherfall", "Push"]],
	[318, ["Earthquake", "Stonefall"]],
	[350, ["Eclipse", "Decoy"]],
	[421, ["Gust", "Tornado"]],
]
const STARTS := [-31, -22, 0, 12, 47, 104, 154, 172, 204, 278, 316, 348, 382, 419, 456, 488, 542, 570, 588, 626, 666, 684, 770, 830, 912, 998, 1060]   # where whoever falls is on their feet again: the start of the place they were working on
const HINT_UNTIL := -21.0   # the keys to walk and jump show until the wizard has gone this far
const CLIFF_COL := 165       # from here on the ground is this many rows higher than before: too high to jump, a vine climbs it
const CLIFF_ROWS := 7.0
const CHANT_GAP := Vector2i(186, 199)   # a gap too wide for one jump and not for two (the chant of the double jump)
const CHANT_GAP_ROWS := 4.0
const GAP_SPAN := Vector2i(288, 313)   # a pit far too wide to jump, on the high ground: the spells listed carry a jump across it
const GAP_ROWS_DOWN := 4.0
const THICKET_SPAN := Vector2i(118, 150)   # thorns across the way, far too long to walk through
const THICKET_DARK := Vector2i(258, 270)   # thorns at the end of the dark stretch
const WALL_COL := 324        # a wall of brick three columns thick and ten rows high: no jump clears it, and an earthquake or a boulder brings it down
const WALL_ROWS := 26   # (a rocket jump lifts a wizard about fifteen rows, so a wall that can be rocket-jumped is not tall enough)
const SENTINEL_COL := 402     # an eye that shoots whoever it sees, over a stretch with thorns at the far end of it
const SENTINEL_REACH := 480.0
const SENTINEL_ZONE := Vector2i(388, 414)
const THICKET_SENTINEL := Vector2i(366, 376)
const GAS_SPAN := Vector2i(428, 451)    # three banks of poison gas
const GAS_HEIGHT := 7
const PIT_TWO := Vector2i(458, 483)     # a second pit, for the same leap
const POND_TWO := Vector2i(506, 524)    # a pond of piranhas in the dark, for the light and the Spark together
const DARK_POND := Vector2i(488, 534)
const THICKETS := [THICKET_SPAN, THICKET_DARK, THICKET_SENTINEL]
## The last place is a run over everything the room has taught, with no page to read: a gap that takes two jumps, a cliff that takes a vine, a pit that takes a leap
## (all the same size as the ones met before), and a long thicket on the high ground that takes fire. The ground is never raised above its line, only dug down from it,
## so the way in is a drop of the first cliff's height and the cliff is climbed back to the usual level, which runs level to the portal.
const FINALE_LOW := 536        # from here to the cliff the ground is as low as the room's first stretch
const FINALE_GAP := Vector2i(548, 561)
const FINALE_CLIFF := 576      # from here the ground is level again, as high as the first cliff
const FINALE_LEAP := Vector2i(592, 617)
const FINALE_THORNS := Vector2i(630, 662)
const FINALE_PITS := [[FINALE_GAP, CLIFF_ROWS], [FINALE_LEAP, 0.0]]  # each pit and the level of the ground it is dug from
## The gauntlet at the end: every kind of gate the room has taught, one after another with hardly a pause, and some of them together (a pit under the
## fire of turrets, a pond with thorns just past it, a dark stretch with spikes, a pond and thorns all in it, a tall wall and then gas, an eye over thorns,
## a gap, a pit and a long thicket to finish). There are no pages here: what is needed has been read, and it is for the wizard to know which to use and when.
const GIANT_TWO_COL := 690
const TURRETS_TWO := [710, 722, 738]
const TURRET_ZONE_TWO := Vector2i(702, 756)
const PIT_THREE := Vector2i(726, 751)            # a leap, under the turrets' fire
const POND_THREE := Vector2i(776, 799)
const THICKET_FOUR := Vector2i(807, 821)         # thorns just past the water
const DARK_THREE := Vector2i(834, 906)
const SPIKE_STRIPS_TWO := [842, 852, 862]
const POND_FOUR := Vector2i(871, 889)            # a pond of piranhas in the dark
const THICKET_FIVE := Vector2i(897, 905)         # and thorns at the end of the dark
const WALL_TWO_COL := 920
const GAS_TWO := Vector2i(932, 955)
const SENTINEL_TWO_COL := 972
const SENTINEL_ZONE_TWO := Vector2i(960, 996)
const THICKET_SIX := Vector2i(984, 995)          # thorns inside the eye's sight
const CHANT_GAP_TWO := Vector2i(1004, 1017)
const PIT_FOUR := Vector2i(1034, 1059)
const THICKET_SEVEN := Vector2i(1068, 1096)
const GAUNTLET_FROM := 684
const GAUNTLET_PITS := [[PIT_THREE, GAP_ROWS_DOWN], [CHANT_GAP_TWO, CHANT_GAP_ROWS], [PIT_FOUR, GAP_ROWS_DOWN]]
const GAUNTLET_THICKETS := [THICKET_FOUR, THICKET_FIVE, THICKET_SIX, THICKET_SEVEN]
const GAUNTLET_ZONES := [TURRET_ZONE_TWO, POND_THREE, THICKET_FOUR, DARK_THREE, SENTINEL_ZONE_TWO, GAS_TWO, POND_FOUR, THICKET_FIVE, THICKET_SIX, THICKET_SEVEN]
const DARK_COLOR := Color(0.03, 0.03, 0.05)   # as dark as it is far under the ground in a match
const THICKET_LAYERS := 10
const DARK_SPAN := Vector2i(210, 272)   # where it is dark: the spikes in it are seen only by a light
const SPIKE_STRIPS := [216, 228, 240]   # the first column of each strip of spikes, each three columns wide
const TURRETS := [70, 80, 90]   # (they see 15 columns, so no page lies within sight of them)
const TURRET_ZONE := Vector2i(60, 106)   # a hit from a turret here is a death
const TURRET_PATIENCE := 0.8   # seconds in the sight of a turret, with nothing in the way, before its shot finds the wizard
const DUMMY_COL := -6       # in the way at the first place: whoever walks past it while it stands is struck down
const GIANT_COL := 6        # in the way at the second: whoever walks past it while it is awake is struck down (it has too much strength to be killed: a Faint is the way)
const GIANT_HP := 10000   # so much that it is not worth a single blow: a Faint is the way past
const DUMMY_HP := 36  # three fireballs: the tutorial's dummy falls quickly, so each try is seen through

var _guide: CanvasLayer
var _hint: PanelContainer   # the keys to walk and jump, at the start
var _thickets: Array[Bramble] = []
var _finale_thorns: Array[Bramble] = []   # the long thicket of the last place (kept apart from the first three, which the Plants place counts)
var _dummy: Mob
var _giant: Mob
var _exposed := 0.0   # how long the wizard has been in the sight of a turret
var _shoal: Piranhas
var _backdrop: Backdrop   # the sky and the hills behind, put out under the rock
var _darkness := 0.0   # how dark it is round the wizard, 0 to 1
var _shoal_two: Piranhas
var _wall: RockWall
var _gas: Array[GasBank] = []
var _gas_two: Array[GasBank] = []
var _spikes: SpikeBed
var _camera: GameCamera
var _camera_rest := 0.0    # how far the view sits below the wizard, away from the pits
var _camera_depth := 0.0   # how far it has dropped to show the bottom of a pit that is near
const PIT_VIEW := 110.0   # how far the view drops by a pit: enough to see the spikes at the bottom from its edge
var _pit_spikes: SpikeBed   # at the bottom of every pit, in plain sight: the pits are death
var _giant_two: Mob
var _gauntlet_thorns: Array[Bramble] = []
var _gauntlet_walls: Array[RockWall] = []


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
	_dig_into(heights, CHANT_GAP, 0.0, CHANT_GAP_ROWS)
	_dig_into(heights, GAP_SPAN, 0.0, GAP_ROWS_DOWN)
	_dig_into(heights, PIT_TWO, 0.0, GAP_ROWS_DOWN)
	_dig_into(heights, POND_TWO, 0.0, POND_ROWS)
	for col in range(FINALE_LOW, FINALE_CLIFF):
		heights[col - ArenaGen.FIRST_COL] = CLIFF_ROWS  # the low ground the last place begins on
	for pit: Array in FINALE_PITS:
		_dig_into(heights, pit[0], pit[1], GAP_ROWS_DOWN)
	for pit: Array in GAUNTLET_PITS:
		_dig_into(heights, pit[0], 0.0, pit[1])
	_dig_into(heights, POND_THREE, 0.0, POND_ROWS)
	_dig_into(heights, POND_FOUR, 0.0, POND_ROWS)
	var cells: Dictionary = ArenaGen.build(_rng, heights)
	for span: Vector2i in [DARK_SPAN, DARK_POND, DARK_THREE]:  # the dark stretches are under a roof of rock, as underground
		for col in range(span.x, span.y + 1):
			for row in range(ArenaGen.WALL_TOP, -1):
				cells[Vector2i(col, row)] = ArenaGen.STONE
	return cells


func _begin_encounter(camera: Camera2D) -> void:
	super(camera)
	camera.limit_bottom += int(CLIFF_ROWS * ArenaGen.TILE)  # the low ground is seen as high on the screen as the waiting room's, not at its foot
	_camera = camera as GameCamera
	_camera_rest = _camera.rest_offset().y
	_camera_depth = 0.0
	player.infinite_time = 0.0  # the waiting room never lets stamina run out, but here it does, as it does in a match: this is where it is learned
	player.ledger = Ledger.of([])  # and the book is empty, as it is at the start of a match
	spellbook.refresh()
	player.damaged.connect(_on_player_hurt)
	for child in get_children():
		if child is Backdrop:
			_backdrop = child
	_guide = CanvasLayer.new()
	_guide.layer = 4
	add_child(_guide)
	_show_keys()
	for spot: Array in PAGE_SPOTS:
		_lay_pages(Vector2(ArenaGen.column_x(spot[0]), ArenaGen.surface_y(_cells, spot[0])), spot[1])


## Lays pages on the ground at a point: one page, or several fanned out like cards.
func _lay_pages(at: Vector2, names: Array) -> void:
	var page := PagePickup.new()
	page.page = names[0]
	if names.size() > 1:
		page.spoils.assign(names)
		page.fan = true
	page.position = at
	add_child(page)


## A fan with a page in it that the book already has is laid out again with only what is new.
func _trim_fans() -> void:
	for pickup: PagePickup in get_tree().get_nodes_in_group("pages"):
		if pickup.is_queued_for_deletion() or pickup.spoils.is_empty():
			continue
		var fresh := pickup.new_pages(player.ledger)
		if not fresh.is_empty() and fresh.size() < pickup.spoils.size():
			var at := pickup.position
			pickup.queue_free()
			_lay_pages(at, fresh)


## A pit of the same shape as the others, dug down from the ground at `base` rows.
func _dig_into(heights: PackedFloat32Array, span: Vector2i, base: float, rows: float) -> void:
	for col in range(span.x, span.y + 1):
		var edge := mini(col - span.x, span.y - col)
		var t := clampf((edge + 0.5) / 3.0, 0.0, 1.0)
		heights[col - ArenaGen.FIRST_COL] = base + rows * t * t * (3.0 - 2.0 * t)


func _add_ponds() -> void:
	_shoal = _add_pond(POND_SPAN, CLIFF_ROWS)
	_shoal_two = _add_pond(POND_TWO, 0.0)
	_add_pond(POND_THREE, 0.0)
	_add_pond(POND_FOUR, 0.0)


## A pond dug into ground `level` rows down, with a shoal of piranhas in it.
func _add_pond(span: Vector2i, level: float) -> Piranhas:
	var pond := Pond.new()
	pond.width = (span.y - span.x + 1) * float(ArenaGen.TILE)
	pond.depth = POND_ROWS * ArenaGen.TILE + 16.0
	pond.position = Vector2(span.x * float(ArenaGen.TILE), ArenaGen.GROUND_Y + level * ArenaGen.TILE)
	pond.ground = _ground
	add_child(pond)
	var shoal := Piranhas.new()
	shoal.water = Rect2(pond.position, Vector2(pond.width, pond.depth))
	shoal.pond = pond
	shoal.count = 6
	for col in range(span.x, span.y + 1):
		shoal.bed.append(roundi(ArenaGen.surface_y(_cells, col) / float(ArenaGen.TILE)))
	shoal.bed_x = span.x * float(ArenaGen.TILE)
	add_child(shoal)
	return shoal


func _add_targets() -> void:
	_dummy = _add_mob("dummy", Vector2(ArenaGen.column_x(DUMMY_COL), ArenaGen.surface_y(_cells, DUMMY_COL))) as Mob
	_dummy.max_hp = DUMMY_HP
	_dummy.hp = DUMMY_HP
	_dummy.facing = -1.0
	_dummy.felled_stays = true
	_giant = _add_mob("giant", Vector2(ArenaGen.column_x(GIANT_COL), ArenaGen.surface_y(_cells, GIANT_COL))) as Mob
	_giant.facing = -1.0
	_giant.faint_stays = true
	_giant.max_hp = GIANT_HP
	_giant.hp = GIANT_HP
	_giant_two = _add_mob("giant", Vector2(ArenaGen.column_x(GIANT_TWO_COL), ArenaGen.surface_y(_cells, GIANT_TWO_COL))) as Mob
	_giant_two.facing = -1.0
	_giant_two.faint_stays = true
	_giant_two.max_hp = GIANT_HP
	_giant_two.hp = GIANT_HP
	for span: Vector2i in THICKETS:
		_plant_thicket(span, _thickets)
	_plant_thicket(FINALE_THORNS, _finale_thorns)
	for span: Vector2i in GAUNTLET_THICKETS:
		_plant_thicket(span, _gauntlet_thorns)
	_lay_spikes()
	_lay_pit_spikes()
	_wall = _raise_wall(WALL_COL)
	_gauntlet_walls.append(_raise_wall(WALL_TWO_COL))
	for col: int in [SENTINEL_COL, SENTINEL_TWO_COL]:
		var watcher := Sentinel.new()
		watcher.position = Vector2(ArenaGen.column_x(col), ArenaGen.surface_y(_cells, col))
		watcher.reach = SENTINEL_REACH
		watcher.first_shot = 1.2   # it takes a moment to take aim, and then shoots slowly
		watcher.interval = 1.6
		add_child(watcher)
	_spread_gas(GAS_SPAN, _gas)
	_spread_gas(GAS_TWO, _gas_two)
	for col: int in TURRETS + TURRETS_TWO:
		var turret := _add_mob("turret", Vector2(ArenaGen.column_x(col), ArenaGen.surface_y(_cells, col)))
		turret.facing = -1.0


## A wall of brick across the way, brought down by a quake or a boulder.
func _raise_wall(at: int) -> RockWall:
	var columns := []
	for k in 3:
		var floor_row := roundi(ArenaGen.surface_y(_cells, at + k) / float(ArenaGen.TILE))
		columns.append({"x": at + k, "top": floor_row - WALL_ROWS, "bottom": floor_row})
	var wall := RockWall.new()
	wall.columns = columns
	add_child(wall)
	return wall


## Three banks of poison gas lying over the ground, from the floor to a height of its own, as the world's gas lies in a passage.
func _spread_gas(span: Vector2i, into: Array[GasBank]) -> void:
	for k in range(0, span.y - span.x + 1, 8):
		var floors := PackedInt32Array()
		var tops := PackedInt32Array()
		for j in 8:
			var row := roundi(ArenaGen.surface_y(_cells, span.x + k + j) / float(ArenaGen.TILE))
			floors.append(row)
			tops.append(row - GAS_HEIGHT)
		var bank := GasBank.new()
		bank.column = span.x + k
		bank.floors = floors
		bank.tops = tops
		add_child(bank)
		into.append(bank)


## Strips of spikes along the dark stretch, seen only when a light falls on them.
func _lay_spikes() -> void:
	var strips := []
	for col: int in SPIKE_STRIPS + SPIKE_STRIPS_TWO:
		var floors := PackedInt32Array()
		for k in 3:
			floors.append(roundi(ArenaGen.surface_y(_cells, col + k) / float(ArenaGen.TILE)))
		strips.append({"x": col, "width": 3, "floors": floors})
	_spikes = SpikeBed.new()
	_spikes.strips = strips
	add_child(_spikes)


## Spikes at the bottom of every pit, in plain sight (a pit is a drop onto them): whoever lands in one is cut, and in the room that is the end.
func _lay_pit_spikes() -> void:
	var strips := []
	for pit: Array in all_pits():
		var span: Vector2i = pit[0]
		var col := span.x + 3
		while col + 3 <= span.y - 2:
			var floors := PackedInt32Array()
			for k in 3:
				floors.append(roundi(ArenaGen.surface_y(_cells, col + k) / float(ArenaGen.TILE)))
			strips.append({"x": col, "width": 3, "floors": floors})
			col += 3
	_pit_spikes = SpikeBed.new()
	_pit_spikes.always_seen = true
	_pit_spikes.strips = strips
	add_child(_pit_spikes)


## Every pit of the room, with the level of the ground it is dug from.
static func all_pits() -> Array:
	return [[CHANT_GAP, 0.0], [GAP_SPAN, 0.0], [PIT_TWO, 0.0]] + FINALE_PITS + GAUNTLET_PITS.map(func(pit: Array) -> Array: return [pit[0], 0.0])


## Thorns across the way: planted like the world's own, so fire burns them away.
func _plant_thicket(span: Vector2i, into: Array[Bramble]) -> void:
	var points := PackedVector2Array()
	for col in range(span.x, span.y + 1):
		for half in 2:
			var x := (col + half * 0.5) * float(ArenaGen.TILE)
			points.append(Vector2(x, ArenaGen.surface_y(_cells, col)))
	for layer in THICKET_LAYERS:  # each layer pricks on its own, so that walking all the way through is more than a wizard can take
		var thorns := Bramble.new()
		thorns.planted_ground = points
		add_child(thorns)
		into.append(thorns)


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


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("night_toggle"):
		return  # the dark is the room's own here
	super(event)


func _process(delta: float) -> void:
	super(delta)
	var column := player.global_position.x / float(ArenaGen.TILE)
	_rescue_from_pits(column)
	_show_the_pit_floor(delta, column)
	_guard_the_way(column)
	_watch_the_turrets(delta, column)
	_clear_spare_pages()
	_trim_fans()
	var under := [DARK_SPAN, DARK_POND, DARK_THREE].any(func(span: Vector2i) -> bool: return column >= span.x and column <= span.y)  # dark only under the rock, and no light of the wizard's own
	_darkness = move_toward(_darkness, 1.0 if under else 0.0, delta * 4.0)
	_night.visible = _darkness > 0.0
	_night.color = Color.WHITE.lerp(DARK_COLOR, _darkness)
	if _backdrop != null:
		_backdrop.set_opacity(1.0 - _darkness)
	_player_light.enabled = false
	if _hint != null and column > HINT_UNTIL:
		_hint.queue_free()
		_hint = null


## A page the book already holds is nothing to read, so it is taken away (the Burn Plants place lays Ignite again, for whoever skipped it).
func _clear_spare_pages() -> void:
	for pickup: PagePickup in get_tree().get_nodes_in_group("pages"):
		if not pickup.is_queued_for_deletion() and not pickup.gives(player.ledger):
			pickup.queue_free()


## The view drops to show the bottom of a pit as a wizard comes up to it, so the spikes at the bottom are seen before the jump, not after it.
func _show_the_pit_floor(delta: float, column: float) -> void:
	if _camera == null:
		return
	var near := all_pits().any(func(pit: Array) -> bool: return column >= pit[0].x - 14 and column <= pit[0].y + 6)
	_camera_depth = move_toward(_camera_depth, PIT_VIEW if near else 0.0, delta * 260.0)
	_camera.set_rest_offset(Vector2(_camera.rest_offset().x, _camera_rest + _camera_depth))


## Whoever has fallen into the pond or the pit is put back on its near edge, where they came from.
func _rescue_from_pits(column: float) -> void:
	for pit: Array in [[CHANT_GAP, CHANT_GAP_ROWS], [GAP_SPAN, GAP_ROWS_DOWN], [PIT_TWO, GAP_ROWS_DOWN], [FINALE_GAP, GAP_ROWS_DOWN], [FINALE_LEAP, GAP_ROWS_DOWN]] + GAUNTLET_PITS:
		var span: Vector2i = pit[0]
		var edge := span.x - 3
		if column >= span.x and column <= span.y and player.global_position.y > ArenaGen.surface_y(_cells, edge) + (float(pit[1]) - 1.0) * ArenaGen.TILE:
			player.global_position = Vector2(ArenaGen.column_x(edge), ArenaGen.surface_y(_cells, edge) - 20.0)
			player.velocity = Vector2.ZERO


## The dummy and the giant strike down whoever walks past them while the dummy stands and the giant is awake. The giant does not leave its place.
func _guard_the_way(column: float) -> void:
	if player.dead:
		return
	if _dummy != null and is_instance_valid(_dummy) and not _dummy.is_dead() and column > DUMMY_COL + 1.5:
		player.take_damage(1000, false)
	for pair: Array in [[_giant, GIANT_COL], [_giant_two, GIANT_TWO_COL]]:
		var giant: Mob = pair[0]
		if giant != null and is_instance_valid(giant) and not giant.is_dead() and not giant.is_fainted():
			giant.apply_root(0.5)
			if column > float(pair[1]) + 1.5:
				player.take_damage(1000, false)


## Whoever stays in sight of a turret, with no Barrier round them and no stone between, is shot, for the turrets fire slowly and a runner could slip every
## one of them. A hit in this stretch is a death (see _strike_down).
func _watch_the_turrets(delta: float, column: float) -> void:
	if player.dead or player.has_shield() or not [TURRET_ZONE, TURRET_ZONE_TWO].any(func(zone: Vector2i) -> bool: return column >= zone.x and column <= zone.y):
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


## A hit is a death in the stretches that are guarded: by the turrets (the Barrier and the Stone Wall turn their shots away), the piranhas, the thorns,
## the spikes in the dark, the eye and the gas.
func _on_player_hurt(_amount: int) -> void:
	_strike_down.call_deferred()


func _strike_down() -> void:
	var column := player.global_position.x / float(ArenaGen.TILE)
	if player.dead:
		return
	var pits := all_pits().map(func(pit: Array) -> Vector2i: return pit[0])
	for zone: Vector2i in [TURRET_ZONE, POND_SPAN, DARK_SPAN, SENTINEL_ZONE, GAS_SPAN, POND_TWO, FINALE_THORNS] + THICKETS + GAUNTLET_ZONES + pits:
		if column >= zone.x and column <= zone.y:
			player.take_damage(1000, false)
			return


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

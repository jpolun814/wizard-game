class_name Senses
extends RefCounted

## What a wizard can take in, as a list of numbers for a trained network: the second layout, which replaces Sensing for new training (Sensing stays,
## unchanged, for the networks already trained on it: ai/footwork.json). See training/senses_audit.md for what a person's screen shows and why each part is here.
##
## The rule is a person's: what is on the wizard's screen (Eyes) or shown on its own wizard, what the chants it has said put on its screen (the minimap,
## Insight, the Scrying Eye's window), what is in its book, and what it remembers of what it saw, and nothing else. A network has no memory of its own
## (it sees one moment at a time), so the memory a person has is given to it here: the ground it has seen, the pages it saw and has not seen taken, and
## where it last saw each rival.
##
## Things are described by what they do (solid, a liquid, no air to breathe, it hurts, it slows, it is slippery, it can be climbed, it lifts, it pulls,
## it can be stood on), not by what they are, so that a new kind of world fits this same layout and a network has something to carry over to it. A world
## thing of a new kind can say what it does itself, with `sense_traits() -> int` returning the bits below, and where it is, with `sense_point()` (the
## point whose motion is watched); anything in the "danger" group counts as hurting.
##
## Layout (all about -1..1), in this order:
##   the wizard itself     SELF (its motion, stamina, breath, the liquid it is in, the conditions and spells on it)
##   ground near the feet  FINE_W x FINE_H tiles, CHANNELS each
##   the whole screen      BLOCKS_W x BLOCKS_H blocks of BLOCK x BLOCK tiles, CHANNELS each (how much of the block has each trait)
##   remembered ground     MEM_W x MEM_H blocks of MEM_BLOCK x MEM_BLOCK tiles about the feet, MEM_CHANNELS each (seen before, and what was there)
##   things                THINGS nearest things in sight (shots, creatures, spells, fires, smoke, walls, moving footing), THING each: with which
##                         spell it is and which creature (a person sees both), and the damage number shown over a creature
##   rivals                RIVALS nearest wizards in sight, RIVAL each, with the stroke they are drawing (and their stamina, under Insight), which
##                         wizard it is (figure and colours), the words shown over them (damage, Negated, Interrupted, Dazed), the chant they type
##   remembered rivals     RIVALS wizards seen before and not now: where they were last seen, and how long ago
##   pages                 PAGES nearest pages in sight, then REMEMBERED_PAGES pages seen before and not seen taken, PAGE_SLOT each (where, and
##                         the school whose colour it glows in)
##   portal                the nearest portal in sight, 3
##   book                  BOOK_SPELLS spells (SPELL_ORDER), PAGE each: 1 in the book, and what its page says (the least and the most it costs, whether it
##                         is paid in maximum stamina, its damage and whether that is a rate); then BOOK_CHANTS chants (CHANT_ORDER): a chant 1 said and holding
##   minimap               MAP_W x MAP_H (the whole world's ground, once the Rite of the Land is said) and the wizard's place on it, 3
##   scrying eye           SCRY: the wizard the Scrying Eye's window shows, and the ground about them (not where they are)
##   words                 WORDS: the words the screen shows its player about the wizard (Wizard.WORDS: Misfire, Too tired, the spell
##                         that went off, a damage number...), each fading from 1 as the word does
##   spare                 SPARE zeros, kept for senses a later world needs, so that adding one does not change the layout
## Change the layout and every network trained on it stops fitting: use the spare numbers and the spare book places instead, and change LAYOUT when you must.

const LAYOUT := 3  # (3, 2026-11-11: what each page of the book says, the words on screen, which spell, creature and wizard a thing is, page schools)

# What a tile, or a thing, does (bits).
const SOLID := 1        # ground or a wall
const PLATFORM := 2     # a wooden platform, a stair, a pad: stood on, passed up through
const LIQUID := 4       # water, lava: swum or waded in
const NO_AIR := 8       # the breath is held in it (water)
const HURTS := 16
const SLOWS := 32
const SLICK := 64       # ice underfoot
const CLIMB := 128      # a vine or a ladder
const LIFTS := 256      # rising air, a geyser
const SEEN := 512       # on the screen and made out (not in the dark, not behind smoke)
const CHANNEL_BITS := [SOLID, PLATFORM, LIQUID, NO_AIR, HURTS, SLOWS, SLICK, CLIMB, LIFTS, SEEN]
const CHANNELS := 10
# Bits only things carry.
const PULLS := 1024     # draws bodies toward it (a black hole, a dying star, a whirlwind)
const BLOCKS := 2048    # stops shots and bodies (a stone wall, ice)
const HIDES := 4096     # nothing is seen through it (smoke)
const SHOT := 8192      # a shot in flight
const CREATURE := 16384
const FLYER := 32768
const NO_MAGIC := 65536 # nothing can be cast inside it (Silence)

## Every spell, in a fixed order: the book's places. New spells go in the spare places at the end (BOOK_SPELLS in all), never between.
const SPELL_ORDER := ["Adrenaline", "Barbs", "Barrier", "Black Hole", "Blizzard", "Bramble", "Crimson Veil", "Decoy", "Earthquake", "Eclipse",
	"Eldritch Blast", "Faint", "Featherfall", "Fight or Flight", "Fire Breath", "Firewall", "Flaming Sphere", "Flare", "Flytrap", "Frost Bridge",
	"Frostbolt", "Geyser", "Glowcap", "Great Oak", "Gust", "Hailstorm", "Hemorrhage", "Hex", "Hunter's Mark", "Ice Prison", "Icicles", "Ignite",
	"Insect Plague", "Leech", "Liana", "Lily Pads", "Mirage", "Moonbeam", "Mudslide", "Obsidian Armor", "Pebble", "Push", "Raise Dead", "Rocket Jump",
	"Scythe", "Shadow Step", "Silence", "Sinkhole", "Smoke Screen", "Sneak", "Spark", "Spore Puff", "Stalagmite", "Stone Wall", "Stonefall", "Supernova",
	"Thorn Whip", "Thunderclap", "Tide Surf", "Tornado", "Updraft", "Vacuum", "Wild Shape"]
const CHANT_ORDER := ["minimap", "insight", "bonfire", "boundless", "double_jump", "rift", "haste", "deep_breath", "dowsing", "scrying_eye"]
const BOOK_SPELLS := 96
const BOOK_CHANTS := 16
const PAGE := 6  # numbers for each spell of the book: in it, least cost, most cost, paid in maximum stamina, damage, damage a rate

const TILE := 32.0
const COLS := 13          # tiles either side of the feet that the screen grid looks at (the screen is about 27 tiles across)
const UP := 12            # tiles above the feet (the view rests above the wizard: about 12 tiles show above, 3 below)
const DOWN := 3
const FINE_HALF := 7
const FINE_UP := 7
const FINE_DOWN := 3
const FINE_W := FINE_HALF * 2 + 1
const FINE_H := FINE_UP + FINE_DOWN + 1
const BLOCK := 3
const BLOCKS_W := 9       # (COLS * 2 + 1) / BLOCK
const BLOCKS_H := 5       # rows -UP .. 2 in blocks of BLOCK
const MEM_BLOCK := 6
const MEM_W := 16         # remembered ground: 96 tiles across (about three and a half screens), 48 down, about the feet, in blocks of 6 x 6 tiles
const MEM_H := 8
const MEM_CHANNELS := 4   # seen before, solid, liquid, hurts
const SELF := 40
const THINGS := 24
const THING := 23
const RIVALS := 7
const STROKE_POINTS := 8
const RIVAL := 17 + STROKE_POINTS * 2 + RIVAL_MORE
const RIVAL_MORE := 6 + 10  # which wizard (figure, colours), words over them (damage, Negated, Interrupted, Dazed), the chant they type (CHANT_ORDER)
const PAGES := 3
const REMEMBERED_PAGES := 5
const SCHOOLS := ["Fire", "Water", "Air", "Earth", "Flora", "Shadow", "Blood"]  # a page glows in its school's colour; a chant's page in its own
const PAGE_SLOT := 3 + 8
const WORD_LIFE := 0.8  # seconds a floating word is seen (FloatText.LIFE)
const WORD_COUNT := 11  # Wizard.WORDS.size() (a constant must be written out; tests/senses_check.gd checks they agree)
const MAP_W := 32
const MAP_H := 8
const SCRY_HALF := 3      # the ground about the watched wizard: 7 x 5 tiles
const SCRY_UP := 3
const SCRY_DOWN := 1
const SCRY := 1 + 11 + (SCRY_HALF * 2 + 1) * (SCRY_UP + SCRY_DOWN + 1) * 3
const SPARE := 24
const SIZE := SELF + FINE_W * FINE_H * CHANNELS + BLOCKS_W * BLOCKS_H * CHANNELS + MEM_W * MEM_H * MEM_CHANNELS + THINGS * THING + RIVALS * RIVAL \
	+ RIVALS * 3 + (PAGES + REMEMBERED_PAGES) * PAGE_SLOT + 3 + BOOK_SPELLS * PAGE + BOOK_CHANTS + MAP_W * MAP_H + 3 + SCRY + WORD_COUNT + SPARE

const SEE := 900.0
const REMEMBER_RIVAL := 30.0  # seconds a rival out of sight is remembered
const REMEMBER_PAGE := 300.0
const MAP_EVERY := 15.0       # seconds between new looks at the whole world's ground, for the minimap
const THING_GROUPS := ["mobs", "danger", "shots", "projectiles", "clouds", "sight_blockers", "walls", "silences", "swing_stairs", "lily_pads"]

var wizard: Wizard
var codes := PackedInt32Array()  # the tiles of the screen grid, a bit set each, rows from -UP to DOWN, columns from -COLS to COLS (kept for the recorder)
var _last_at := {}               # instance id -> [position, time]: where each thing was last looked at, for its motion
var _sizes := {}                 # instance id -> how big a thing is, worked out once
var _world_id := 0               # the world the memory below is of: a new world forgets it
var _memory := PackedByteArray() # the ground seen, a byte to a tile (1 seen, 2 solid, 4 liquid, 8 hurts), over _mem_rect
var _mem_rect := Rect2i()
var _mem_blocks := PackedInt32Array()  # the same, summed over blocks of MEM_BLOCK x MEM_BLOCK tiles: seen, solid, liquid, hurts (four to a block)
var _mem_blocks_w := 0
var _rivals_seen := {}           # instance id -> [where last seen, when]
var _pages_seen := {}            # instance id -> [where, when last seen]
var _map := PackedFloat32Array() # the minimap's ground, how solid each cell is
var _map_rect := Rect2()
var _map_at := -1.0e9
var _watched: Wizard             # who this wizard's Scrying Eye shows, when it is not a person's own window
var _rng := RandomNumberGenerator.new()


func _init(owner: Wizard) -> void:
	wizard = owner
	_rng.seed = owner.get_instance_id()


## The numbers, in the layout above.
func observe() -> PackedFloat32Array:
	var obs := PackedFloat32Array()
	if wizard == null or not is_instance_valid(wizard) or not wizard.is_inside_tree():
		obs.resize(SIZE)
		return obs
	_new_world_forgets()
	_self(obs)
	_read_tiles()
	_fine(obs)
	_blocks(obs)
	_remember_ground()
	_remembered_ground(obs)
	_things(obs)
	_rivals(obs)
	_pages(obs)
	_portal(obs)
	_book(obs)
	_minimap(obs)
	_scrying(obs)
	_words(obs)
	obs.resize(SIZE)  # (the spare numbers, zero)
	return obs


## Where the parts of the layout made from the tiles begin and end: the screen's ground, and the remembered ground after it. The recorder writes the
## tiles, not these numbers (the memory is made again from the tiles of the looks before).
static func ground_span() -> Vector2i:
	return Vector2i(SELF, SELF + FINE_W * FINE_H * CHANNELS + BLOCKS_W * BLOCKS_H * CHANNELS + MEM_W * MEM_H * MEM_CHANNELS)


## Where the lists of like things lie, each as (first number, slots, numbers a slot, the place in a slot that is 1 when it holds something): a network
## that reads them with encoders of their own (PolicyNet kind "entity", training/entity_net.py) must have been trained on these same places.
static func list_spans() -> Dictionary:
	var things := ground_span().y
	return {"things": Vector4i(things, THINGS, THING, 19), "rivals": Vector4i(things + THINGS * THING, RIVALS, RIVAL, 16)}


## Where the minimap's numbers begin and end (the recorder leaves them out: it is the world's ground, which does not change from look to look).
static func map_span() -> Vector2i:
	var from := SIZE - SPARE - WORD_COUNT - SCRY - 3 - MAP_W * MAP_H  # (counted back from the end: the words, the Scrying Eye, the place on the map)
	return Vector2i(from, from + MAP_W * MAP_H)


func _self(obs: PackedFloat32Array) -> void:
	var w := wizard
	var from := obs.size()
	obs.append_array([
		w.velocity.x / 300.0, clampf(w.velocity.y / 600.0, -2.0, 2.0), _flag(w.is_on_floor()), w.facing,
		w.stamina / 200.0, w.max_stamina / 200.0, _flag(w.infinite_time > 0.0),
		w.breath / Wizard.BREATH, _flag(w.holding_breath()), w.deep_breath_time / Wizard.DEEP_BREATH, _flag(w.underwater()),
		_flag(w.in_liquid()), _flag(w.in_lava()), clampf(w.wind / 300.0, -2.0, 2.0),
		_flag(w.air_jump_ready), _flag(w.air_jump_time > 0.0),
		_flag(w.is_slowed()), _flag(w.is_rooted()), _flag(w.is_frozen()), _flag(w.fainted), _flag(w.daze_time > 0.0), _flag(w.is_muted()), _flag(w.silenced()),
		_flag(w.has_shield()), _flag(w.veil > 0), _flag(w.obsidian_time > 0.0), _flag(w.fade_time > 0.0), _flag(w.haste_time > 0.0 or w.adrenaline_time > 0.0),
		_flag(w.feather_time > 0.0), _flag(w.rocket_time > 0.0), _flag(w.surf_time > 0.0), _flag(Hex.multiplier(w.get_tree(), w) > 1.0),
		_flag(w.rage_time > 0.0), _flag(w.fear_time > 0.0), _flag(w.on_vine()), _flag(w.wild), _flag(w.drawn), _flag(w.is_drawing()),
		_flag(w.brain != null and w.brain.is_typing()),
	])
	while obs.size() < from + SELF:
		obs.append(0.0)


## What it takes to read tiles about a place: the things there that a tile can be in, found once.
func _looker(area: Rect2) -> Dictionary:
	var tree := wizard.get_tree()
	var bodies := PhysicsPointQueryParameters2D.new()
	bodies.collision_mask = 1 | 16
	var areas := PhysicsPointQueryParameters2D.new()
	areas.collide_with_areas = true
	areas.collide_with_bodies = false
	areas.collision_mask = 0xFFFFFFFF
	return {
		"space": wizard.get_world_2d().direct_space_state, "bodies": bodies, "areas": areas, "area_boxes": _area_boxes(area),
		"ponds": _near(tree, "ponds", area, 2000.0),
		"dangers": _near(tree, "danger", area, 900.0).filter(func(n: Node) -> bool: return not n is Pond),
		"slick": _near(tree, "slick", area, 900.0), "climbs": _near(tree, "climbables", area, 900.0), "lifts": _near(tree, "updrafts", area, 900.0),
	}


## Where the areas a tile can be in (thorns, spikes, gas, fire...) lie about a place: a box for each, so that only the tiles inside one are asked
## what areas they are in (most tiles are in none, and asking costs).
func _area_boxes(area: Rect2) -> Array[Rect2]:
	var query := PhysicsShapeQueryParameters2D.new()
	var box := RectangleShape2D.new()
	box.size = area.size
	query.shape = box
	query.transform = Transform2D(0.0, area.get_center())
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 0xFFFFFFFF
	var out: Array[Rect2] = []
	for hit in wizard.get_world_2d().direct_space_state.intersect_shape(query, 64):
		var found: Object = hit["collider"]
		if found is Pond or not found is CollisionObject2D or _traits(found) & (HURTS | SLOWS | LIFTS | CLIMB | SLICK) == 0:
			continue
		var body := found as CollisionObject2D
		for owner_id in body.get_shape_owners():
			var at := body.global_transform * body.shape_owner_get_transform(owner_id)
			for k in body.shape_owner_get_shape_count(owner_id):
				var shape: Shape2D = body.shape_owner_get_shape(owner_id, k)
				if shape != null:
					out.append((at * shape.get_rect()).grow(2.0))
	return out


## What is at one point, as tile bits (not SEEN: that is the caller's to say).
func _code_at(point: Vector2, look: Dictionary) -> int:
	var code := 0
	var bodies: PhysicsPointQueryParameters2D = look["bodies"]
	var space: PhysicsDirectSpaceState2D = look["space"]
	bodies.position = point
	for hit in space.intersect_point(bodies, 4):
		var layer: int = hit["collider"].collision_layer if hit["collider"] is CollisionObject2D else 1
		code |= PLATFORM if (layer & 16 != 0 and layer & 1 == 0) else SOLID
	for box: Rect2 in look["area_boxes"]:
		if box.has_point(point):
			var areas: PhysicsPointQueryParameters2D = look["areas"]
			areas.position = point
			for hit in space.intersect_point(areas, 8):
				var area: Object = hit["collider"]
				if area is Pond or not area is Node2D:
					continue
				code |= _traits(area) & (HURTS | SLOWS | LIFTS | CLIMB | SLICK)
			break
	for pond: Pond in look["ponds"]:
		if pond.wet_at(point):
			code |= LIQUID | (HURTS if pond.cools and pond.molten() else NO_AIR)
	for node: Node2D in look["dangers"]:
		if node.danger_at(point):
			code |= _traits(node) & (HURTS | SLOWS | LIFTS)
	for node in look["slick"]:
		if node.covers(point) or node.covers(point + Vector2(0.0, -TILE)):
			code |= SLICK
	for node in look["climbs"]:
		if node.can_grab(point):
			code |= CLIMB
	for node: Node2D in look["lifts"]:
		var at := point - node.global_position
		if absf(at.x) <= Updraft.WIDTH * 0.5 and at.y <= 30.0 and at.y >= -Updraft.HEIGHT:
			code |= LIFTS
	return code


## Every tile of the screen grid: what is there, and whether it can be made out.
func _read_tiles() -> void:
	var tree := wizard.get_tree()
	var feet := _feet_tile()
	var view := wizard.eyes.rect()
	var reach := Rect2((feet.x - COLS) * TILE, (feet.y - UP) * TILE, (COLS * 2 + 1) * TILE, (UP + DOWN + 1) * TILE).grow(TILE)
	var bright := wizard.eyes.light_level() >= Eyes.SEEN_UNLIT
	var eye := wizard.center()
	var look := _looker(reach)
	# What can hide a tile, found once for the look: smoke and the dark of an eclipse (sight_blocked asks the tree for both at every call), and the
	# lights that reach the screen when it is dark.
	var hiders := not tree.get_nodes_in_group("sight_blockers").is_empty() or not tree.get_nodes_in_group("eclipses").is_empty()
	var lights: Array = [] if bright else wizard.eyes.lights_near(view)
	codes.resize((UP + DOWN + 1) * (COLS * 2 + 1))
	var i := 0
	for dy in range(-UP, DOWN + 1):
		for dx in range(-COLS, COLS + 1):
			var point := Vector2((feet.x + dx + 0.5) * TILE, (feet.y + dy + 0.5) * TILE)
			var code := 0
			if view.has_point(point) and not (hiders and SpellTargets.sight_blocked(tree, eye, point)) and (bright or Eyes.lit_by(lights, point)):
				code = SEEN | _code_at(point, look)
			codes[i] = code
			i += 1


func _fine(obs: PackedFloat32Array) -> void:
	for dy in range(-FINE_UP, FINE_DOWN + 1):
		for dx in range(-FINE_HALF, FINE_HALF + 1):
			var code := _code(dx, dy)
			for bit: int in CHANNEL_BITS:
				obs.append(1.0 if code & bit != 0 else 0.0)


## The screen in blocks: for each trait, how much of the block has it.
func _blocks(obs: PackedFloat32Array) -> void:
	for by in BLOCKS_H:
		for bx in BLOCKS_W:
			var counts := PackedFloat32Array()
			counts.resize(CHANNELS)
			for y in BLOCK:
				for x in BLOCK:
					var code := _code(-COLS + bx * BLOCK + x, -UP + by * BLOCK + y)
					for c in CHANNELS:
						if code & CHANNEL_BITS[c] != 0:
							counts[c] += 1.0
			for c in CHANNELS:
				obs.append(counts[c] / float(BLOCK * BLOCK))


func _code(dx: int, dy: int) -> int:
	if dx < -COLS or dx > COLS or dy < -UP or dy > DOWN:
		return 0
	return codes[(dy + UP) * (COLS * 2 + 1) + dx + COLS]


## A new world (or the first look) starts the memory afresh: its ground, its pages and its rivals are not the last world's.
func _new_world_forgets() -> void:
	var world: Node = wizard.get_tree().get_first_node_in_group(&"world")
	var id := world.get_instance_id() if world != null else wizard.get_parent().get_instance_id()
	if id == _world_id and not _memory.is_empty():
		return
	_world_id = id
	_rivals_seen.clear()
	_pages_seen.clear()
	_last_at.clear()
	_map = PackedFloat32Array()
	_map_at = -1.0e9
	_watched = null
	var bounds := _world_bounds()
	_mem_rect = Rect2i(floori(bounds.position.x / TILE), floori(bounds.position.y / TILE), ceili(bounds.size.x / TILE) + 1, ceili(bounds.size.y / TILE) + 1)
	_mem_rect.position = Vector2i(floori(_mem_rect.position.x / float(MEM_BLOCK)) * MEM_BLOCK, floori(_mem_rect.position.y / float(MEM_BLOCK)) * MEM_BLOCK)  # blocks lie on the world's own grid
	_memory = PackedByteArray()
	_memory.resize(_mem_rect.size.x * _mem_rect.size.y)
	_mem_blocks_w = ceili(_mem_rect.size.x / float(MEM_BLOCK)) + 1
	_mem_blocks = PackedInt32Array()
	_mem_blocks.resize(_mem_blocks_w * (ceili(_mem_rect.size.y / float(MEM_BLOCK)) + 1) * MEM_CHANNELS)


## The tiles seen this look are remembered as they are now (a pit dug since is remembered once it is seen again).
func _remember_ground() -> void:
	var feet := _feet_tile()
	var i := 0
	for dy in range(-UP, DOWN + 1):
		for dx in range(-COLS, COLS + 1):
			var code := codes[i]
			i += 1
			if code & SEEN == 0:
				continue
			var x := feet.x + dx
			var y := feet.y + dy
			var at := _mem_index(x, y)
			if at < 0:
				continue
			var now := 1 | (2 if code & (SOLID | PLATFORM) != 0 else 0) | (4 if code & LIQUID != 0 else 0) | (8 if code & HURTS != 0 else 0)
			var was := _memory[at]
			if now == was:
				continue
			_memory[at] = now
			var block := _block_index(x, y)
			for c in MEM_CHANNELS:
				_mem_blocks[block + c] += ((now >> c) & 1) - ((was >> c) & 1)


func _remembered_ground(obs: PackedFloat32Array) -> void:
	var feet := _feet_tile()
	var left := floori(feet.x / float(MEM_BLOCK)) - MEM_W / 2
	var top := floori(feet.y / float(MEM_BLOCK)) - MEM_H * 3 / 5  # more above the feet than below, as the screen is
	var all := float(MEM_BLOCK * MEM_BLOCK)
	for by in MEM_H:
		for bx in MEM_W:
			var block := _block_index((left + bx) * MEM_BLOCK, (top + by) * MEM_BLOCK)
			if block < 0:
				obs.append_array([0.0, 0.0, 0.0, 0.0])
			else:
				obs.append_array([_mem_blocks[block] / all, _mem_blocks[block + 1] / all, _mem_blocks[block + 2] / all, _mem_blocks[block + 3] / all])


## Where a tile's block begins among the remembered blocks, or -1 off the world.
func _block_index(x: int, y: int) -> int:
	if not _mem_rect.has_point(Vector2i(x, y)):
		return -1
	return (((y - _mem_rect.position.y) / MEM_BLOCK) * _mem_blocks_w + (x - _mem_rect.position.x) / MEM_BLOCK) * MEM_CHANNELS


func _mem_index(x: int, y: int) -> int:
	if not _mem_rect.has_point(Vector2i(x, y)):
		return -1
	return (y - _mem_rect.position.y) * _mem_rect.size.x + (x - _mem_rect.position.x)


## What acts nearby and can be seen: shots, creatures, spells, fires, smoke, walls, moving footing. Each with where it is, which way it moves, how big
## it is and what it does.
func _things(obs: PackedFloat32Array) -> void:
	var tree := wizard.get_tree()
	var found: Array = []
	var seen_ids := {}
	var insight := wizard.ledger.is_settled("insight")
	for group in THING_GROUPS:
		for node in tree.get_nodes_in_group(group):
			if not node is Node2D or node == wizard or node is Pond or node is Wizard or not is_instance_valid(node):
				continue
			var id: int = node.get_instance_id()
			if seen_ids.has(id):
				continue
			seen_ids[id] = true
			var at := _place_of(node)
			var off := at - wizard.center()
			if off.length() > SEE or not wizard.eyes.sees_point(at):
				continue
			var traits := _traits(node)
			if traits == 0:
				continue
			found.append([off, node, traits, at])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0].length() < b[0].length())
	for i in THINGS:
		if i >= found.size():
			for k in THING:
				obs.append(0.0)
			continue
		var off: Vector2 = found[i][0]
		var node: Node2D = found[i][1]
		var traits: int = found[i][2]
		var motion := _motion(node, found[i][3])
		var melee := 0.0
		var ranged := 0.0
		var strength := 0.0
		var creature := 0.0
		var hurt := 0.0
		if node is Mob:
			creature = float(Mob.KINDS.keys().find(node.kind) + 1) / float(Mob.KINDS.size())  # which creature (a person sees a skeleton, a knight...)
			hurt = _fading(node.shown_hurt_at) * node.shown_hurt / 50.0
			var kind: MobKind = node.KINDS[node.kind]
			melee = _flag(kind.role == "melee")
			ranged = _flag(kind.role == "ranged" or not kind.shot.is_empty())
			strength = clampf((float(node.hp) if insight else float(kind.hp)) / 200.0, 0.0, 2.0)  # (how strong a kind is shows in it; Insight shows what is left)
		obs.append_array([off.x / SEE, off.y / SEE, clampf(motion.x / 600.0, -2.0, 2.0), clampf(motion.y / 600.0, -2.0, 2.0),
			clampf(_size_of(node) / 400.0, 0.0, 2.0), _bit(traits, HURTS), _bit(traits, SLOWS), _bit(traits, PULLS), _bit(traits, LIFTS),
			_bit(traits, BLOCKS), _bit(traits, HIDES), _bit(traits, SHOT), _bit(traits, CREATURE), _bit(traits, FLYER), _bit(traits, PLATFORM),
			melee, ranged, strength, _bit(traits, NO_MAGIC), 1.0, _spell_of(node), creature, hurt])
	for id in _last_at.keys():
		if not seen_ids.has(id):
			_last_at.erase(id)


func _rivals(obs: PackedFloat32Array) -> void:
	var now := _now()
	var insight := wizard.ledger.is_settled("insight")
	var found: Array = []
	var in_sight := {}
	for other: Wizard in SpellTargets.wizards(wizard.get_tree()):
		if other == wizard or other.dead:
			continue
		var id := other.get_instance_id()
		if wizard.eyes.sees_wizard(other):
			var off := other.center() - wizard.center()
			found.append([off, other])
			in_sight[id] = true
			_rivals_seen[id] = [other.global_position, now]
		elif _rivals_seen.has(id):
			var where: Vector2 = _rivals_seen[id][0]
			if now - float(_rivals_seen[id][1]) > REMEMBER_RIVAL or wizard.eyes.sees_point(where + Vector2(0.0, -40.0)):
				_rivals_seen.erase(id)  # long ago, or the place is in sight and they are not there
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0].length() < b[0].length())
	for i in RIVALS:
		if i >= found.size():
			for k in RIVAL:
				obs.append(0.0)
			continue
		var off: Vector2 = found[i][0]
		var other: Wizard = found[i][1]
		var typing := other.shown_words != "" or (other.brain != null and other.brain.is_typing())
		obs.append_array([clampf(off.x / SEE, -2.0, 2.0), clampf(off.y / SEE, -2.0, 2.0), clampf(other.velocity.x / 300.0, -2.0, 2.0),
			clampf(other.velocity.y / 600.0, -2.0, 2.0), other.facing, _flag(other.is_drawing() or other.casting), _flag(typing), _flag(other.wild),
			_flag(other.has_shield()), _flag(other.is_frozen() or other.is_rooted()), _flag(other.is_slowed()), _flag(Hex.multiplier(other.get_tree(), other) > 1.0),
			_flag(other.fade_time > 0.0), _flag(other.fainted), (other.stamina / 200.0) if insight else 0.0, (other.max_stamina / 200.0) if insight else 0.0, 1.0])
		_stroke(obs, other)
		_about(obs, other)
	# The ones out of sight it remembers: where they were last seen, and how long ago.
	var remembered: Array = []
	for id in _rivals_seen:
		if not in_sight.has(id):
			remembered.append([(_rivals_seen[id][0] as Vector2) - wizard.global_position, now - float(_rivals_seen[id][1])])
	remembered.sort_custom(func(a: Array, b: Array) -> bool: return a[0].length() < b[0].length())
	for i in RIVALS:
		if i < remembered.size():
			obs.append_array([clampf(remembered[i][0].x / 3000.0, -2.0, 2.0), clampf(remembered[i][0].y / 1500.0, -2.0, 2.0), remembered[i][1] / REMEMBER_RIVAL])
		else:
			obs.append_array([0.0, 0.0, 0.0])


## The stroke a wizard is drawing, as far as it is drawn, as a person watching would see it: STROKE_POINTS points spread along it, from their middle.
func _stroke(obs: PackedFloat32Array, other: Wizard) -> void:
	var stroke := other.drawn_so_far() if other.brain != null else other.shown_stroke
	for k in STROKE_POINTS:
		if stroke.size() < 2:
			obs.append_array([0.0, 0.0])
		else:
			var p: Vector2 = stroke[int(float(k) / float(STROKE_POINTS - 1) * float(stroke.size() - 1))] - other.center()
			obs.append_array([clampf(p.x / 300.0, -2.0, 2.0), clampf(p.y / 300.0, -2.0, 2.0)])


func _pages(obs: PackedFloat32Array) -> void:
	var now := _now()
	var found: Array = []
	var in_sight := {}
	var view := wizard.eyes.rect().grow(WizardBrain.PAGE_GLOW)
	for pickup: Node2D in wizard.get_tree().get_nodes_in_group("pages"):
		if not is_instance_valid(pickup):
			continue
		var off := pickup.global_position - wizard.center()
		if off.length() < SEE and view.has_point(pickup.global_position) and not SpellTargets.sight_blocked(wizard.get_tree(), wizard.center(), pickup.global_position):
			var school := _school_of(pickup)
			found.append([off, school])
			in_sight[pickup.get_instance_id()] = true
			_pages_seen[pickup.get_instance_id()] = [pickup.global_position, now, school]
	found.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).length() < (b[0] as Vector2).length())
	for i in PAGES:
		if i < found.size():
			obs.append_array([found[i][0].x / SEE, found[i][0].y / SEE, 1.0])
			_school(obs, found[i][1])
		else:
			for k in PAGE_SLOT:
				obs.append(0.0)
	# The pages it saw and has not seen taken: a page that went while it was looking elsewhere is still remembered, until its place is in sight again.
	var remembered: Array = []
	for id in _pages_seen.keys():
		if in_sight.has(id):
			continue
		var where: Vector2 = _pages_seen[id][0]
		if now - float(_pages_seen[id][1]) > REMEMBER_PAGE or wizard.eyes.sees_point(where):
			_pages_seen.erase(id)
			continue
		remembered.append([where - wizard.center(), int(_pages_seen[id][2])])
	remembered.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).length() < (b[0] as Vector2).length())
	for i in REMEMBERED_PAGES:
		if i < remembered.size():
			obs.append_array([clampf(remembered[i][0].x / 3000.0, -2.0, 2.0), clampf(remembered[i][0].y / 1500.0, -2.0, 2.0), 1.0])
			_school(obs, remembered[i][1])
		else:
			for k in PAGE_SLOT:
				obs.append(0.0)


## Which school a page glows in: SCHOOLS, then a chant (its own glow). A Mirage glows as the page it pretends to be.
func _school_of(pickup: Node) -> int:
	var page: String = pickup.get("page") if pickup.get("page") != null else ""
	var spell: Spell = SpellData.SPELLS.get(page)
	return SCHOOLS.find(spell.school) if spell != null else SCHOOLS.size()


func _school(obs: PackedFloat32Array, school: int) -> void:
	for k in SCHOOLS.size() + 1:
		obs.append(_flag(k == school))


## Which spell a thing is, as a person sees it (a fireball, a thicket): its place in the book's order, from the mark the arena puts on what a cast
## makes (Arena._spawn_marked), on the thing or what holds it; 0 for what no spell made.
func _spell_of(node: Node) -> float:
	var at := node
	for k in 3:
		if at == null:
			break
		if at.has_meta(&"spell"):
			return float(SPELL_ORDER.find(String(at.get_meta(&"spell"))) + 1) / float(BOOK_SPELLS)
		at = at.get_parent()
	return 0.0


## What a person sees of another wizard besides where they are and what they do: which wizard it is (its figure and colours, the same from one look
## to the next), the words over it (a damage number, Negated, Interrupted, Dazed) and, once their words say which, the chant they are typing.
func _about(obs: PackedFloat32Array, other: Wizard) -> void:
	obs.append(float(absi(hash(other.look)) % 1000) / 1000.0)
	obs.append(float(other.palette) / 16.0)
	obs.append(_fading(float(other.told.get("hurt", -100.0))) * other.shown_hurt / 50.0)
	for word in ["negated", "interrupted", "dazed"]:
		obs.append(_fading(float(other.told.get(word, -100.0))))
	var words := other.shown_words.strip_edges().to_lower()
	var which := -1
	if words.length() >= 3:
		for k in CHANT_ORDER.size():
			var text: String = RitualInput.RITUALS.get(CHANT_ORDER[k], {}).get("text", "")
			if text.begins_with(words):
				which = k if which == -1 else -2  # (words that begin two chants do not yet say which)
	for k in 10:
		obs.append(_flag(k == which))


## The words the screen shows its player about the wizard (Wizard.WORDS), each fading as it does.
func _words(obs: PackedFloat32Array) -> void:
	for word: String in Wizard.WORDS:
		obs.append(_fading(float(wizard.told.get(word, -100.0))))


## 1 for a word shown just now, falling to 0 as it fades from the screen.
static func _fading(at: float) -> float:
	return clampf(1.0 - (_now() - at) / WORD_LIFE, 0.0, 1.0)


## The game clock the senses keep time by (public: the wizard notes when its words were shown by it).
static func now() -> float:
	return _now()


func _portal(obs: PackedFloat32Array) -> void:
	var best := Vector2.ZERO
	var have := false
	for group in [&"portals", &"field_portals"]:
		for node in wizard.get_tree().get_nodes_in_group(group):
			if node is Node2D and is_instance_valid(node) and node.is_visible_in_tree() and wizard.eyes.sees_point(node.global_position):
				var off: Vector2 = node.global_position - wizard.center()
				if off.length() < SEE and (not have or off.length() < best.length()):
					best = off
					have = true
	obs.append_array([best.x / SEE, best.y / SEE, _flag(have)])


## What is in the wizard's book, as a person knows their own book: each page held, with its cost and damage lines (a person reads both on the page).
func _book(obs: PackedFloat32Array) -> void:
	var ledger := wizard.ledger
	for i in BOOK_SPELLS:
		var spell: Spell = SpellData.SPELLS.get(SPELL_ORDER[i]) if i < SPELL_ORDER.size() else null
		if spell == null or not ledger.knows_spell(SPELL_ORDER[i]):
			for k in PAGE:
				obs.append(0.0)
			continue
		var span := spell.cost_span()
		obs.append_array([1.0, span.x / 200.0, span.y / 200.0, _flag(spell.pays_max()), spell.damage_figure() / 50.0, _flag(spell.damage_is_rate())])
	for i in BOOK_CHANTS:
		if i >= CHANT_ORDER.size():
			obs.append(0.0)
		elif ledger.is_settled(CHANT_ORDER[i]):
			obs.append(1.0)
		else:
			obs.append(0.5 if ledger.knows_chant(CHANT_ORDER[i]) else 0.0)


## The minimap, once the Rite of the Land is said: the whole world's ground, and where the wizard is on it (the only mark it shows).
func _minimap(obs: PackedFloat32Array) -> void:
	if not wizard.ledger.is_settled("minimap"):
		for k in MAP_W * MAP_H + 3:
			obs.append(0.0)
		return
	if _map.is_empty() or _now() - _map_at > MAP_EVERY:
		_map_at = _now()
		_map_rect = _world_bounds()
		_map.resize(MAP_W * MAP_H)
		var query := PhysicsPointQueryParameters2D.new()
		query.collision_mask = 1 | 16
		var space := wizard.get_world_2d().direct_space_state
		var cell := _map_rect.size / Vector2(MAP_W, MAP_H)
		for y in MAP_H:
			for x in MAP_W:
				var solid := 0
				for sy in 2:
					for sx in 2:
						query.position = _map_rect.position + Vector2((x + 0.25 + sx * 0.5) * cell.x, (y + 0.25 + sy * 0.5) * cell.y)
						solid += 1 if not space.intersect_point(query, 1).is_empty() else 0
				_map[y * MAP_W + x] = solid / 4.0
	obs.append_array(_map)
	var at := (wizard.global_position - _map_rect.position) / _map_rect.size
	obs.append_array([clampf(at.x, 0.0, 1.0), clampf(at.y, 0.0, 1.0), 1.0])


## The Scrying Eye's window: someone else, live, and the ground about them, but not where they are.
func _scrying(obs: PackedFloat32Array) -> void:
	var from := obs.size()
	var shown := _scried()
	if shown == null:
		obs.resize(from + SCRY)
		return
	obs.append(1.0)
	obs.append_array([clampf(shown.velocity.x / 300.0, -2.0, 2.0), clampf(shown.velocity.y / 600.0, -2.0, 2.0), _flag(shown.is_drawing() or shown.casting),
		_flag(shown.shown_words != "" or (shown.brain != null and shown.brain.is_typing())), _flag(shown.has_shield()), _flag(shown.is_frozen() or shown.is_rooted()),
		_flag(shown.is_slowed()), _flag(shown.wild), _flag(shown.fainted), _flag(shown.in_liquid()), _flag(shown.holding_breath())])
	var feet := Vector2i(floori(shown.global_position.x / TILE), floori((shown.global_position.y - 1.0) / TILE))
	var look := _looker(Rect2(shown.global_position - Vector2(300.0, 300.0), Vector2(600.0, 400.0)))
	for dy in range(-SCRY_UP, SCRY_DOWN + 1):
		for dx in range(-SCRY_HALF, SCRY_HALF + 1):
			var code := _code_at(Vector2((feet.x + dx + 0.5) * TILE, (feet.y + dy + 0.5) * TILE), look)
			obs.append_array([_bit(code, SOLID | PLATFORM), _bit(code, LIQUID), _bit(code, HURTS)])
	obs.resize(from + SCRY)


## Who the wizard's Scrying Eye shows: the person's own window shows whom it shows; for anyone else one standing wizard is picked, and kept until they fall.
func _scried() -> Wizard:
	if not wizard.ledger.is_settled("scrying_eye"):
		return null
	var world: Node = wizard.get_tree().get_first_node_in_group(&"world")
	if world != null and world.has_method("scrying_watched") and "player" in world and world.player == wizard:
		return world.scrying_watched()
	if _watched == null or not is_instance_valid(_watched) or _watched.dead:
		var others: Array = SpellTargets.wizards(wizard.get_tree()).filter(func(w: Wizard) -> bool: return w != wizard and not w.dead)
		_watched = others[_rng.randi() % others.size()] if not others.is_empty() else null
	return _watched


## What a thing does, as bits. A thing of a new kind may say so itself (sense_traits); the rest is read from what it is.
func _traits(node: Object) -> int:
	if node.has_method("sense_traits"):
		return int(node.sense_traits())
	if node is Mob:
		return CREATURE | HURTS | (FLYER if node.KINDS[node.kind].role == "flyer" else 0)
	if node is Projectile or node is EnemyBolt or node is FallingShot or node is HailStone or node is LavaBall:
		return SHOT | HURTS
	if node is BlackHole or node is Tornado or node is Vacuum:
		return PULLS
	if node is Supernova:
		return PULLS | HURTS
	if node is Updraft:
		return LIFTS
	if node is Geyser:
		return LIFTS | HURTS
	if node is Mudslide or node is Blizzard:
		return SLOWS
	if node is Bramble:
		return HURTS | SLOWS  # (thorns hurt whatever is in the wizard's book)
	if node is StoneWall or node is IcePrison:
		return BLOCKS
	if node is Silence:
		return NO_MAGIC
	if node is SmokeScreen or (node is Node and node.is_in_group("sight_blockers")):
		return HIDES
	if node is SpikeBed:
		return HURTS if node.shown() else 0
	if node is GasBank or node is SporePuff or node is InsectPlague:
		return HURTS
	if node is Node and (node.is_in_group("danger") or node.is_in_group("fires")):
		return HURTS
	return 0


## Where a thing is: the point it says to watch, the middle of its body, or its place.
func _place_of(node: Node2D) -> Vector2:
	if node.has_method("sense_point"):
		return node.sense_point()
	if node is CollisionObject2D:
		return SpellTargets.center_of(node)
	return node.global_position


## Which way a thing is moving: its own speed when it has one, or how far it went since it was last looked at.
func _motion(node: Node2D, at: Vector2) -> Vector2:
	if node is CharacterBody2D:
		return (node as CharacterBody2D).velocity
	if node is Projectile:
		return node.velocity()
	var id := node.get_instance_id()
	var now := _now()
	var motion := Vector2.ZERO
	if _last_at.has(id):
		var then: Array = _last_at[id]
		var gap := now - float(then[1])
		if gap > 0.0 and gap < 2.0:
			motion = (at - (then[0] as Vector2)) / gap
		elif gap <= 0.0:
			return Vector2.ZERO
	_last_at[id] = [at, now]
	return motion


## How big a thing is across, in pixels: worked out once, unless it says how wide it is now.
func _size_of(node: Node2D) -> float:
	var id := node.get_instance_id()
	if _sizes.has(id) and not node.has_method("span"):
		return _sizes[id]
	var size := TILE
	if node.has_method("span"):
		var span: Vector2 = node.span()
		size = absf(span.y - span.x)
	elif node.has_method("footprint"):
		var box: Rect2 = node.footprint()
		size = maxf(box.size.x, box.size.y)
	elif node is CollisionObject2D:
		var body := node as CollisionObject2D
		for owner_id in body.get_shape_owners():
			for k in body.shape_owner_get_shape_count(owner_id):
				var shape: Shape2D = body.shape_owner_get_shape(owner_id, k)
				if shape != null:
					var rect := shape.get_rect()
					size = maxf(size, maxf(rect.size.x, rect.size.y))
	_sizes[id] = size
	return size


func _feet_tile() -> Vector2i:
	return Vector2i(floori(wizard.global_position.x / TILE), floori((wizard.global_position.y - 1.0) / TILE))


## The world's edges: the person's camera's limits, or a wide box about the wizard where there is no such camera.
func _world_bounds() -> Rect2:
	var camera := wizard.get_tree().get_first_node_in_group("game_camera") as GameCamera
	if camera != null and camera.limit_right - camera.limit_left < 1000000 and camera.limit_bottom - camera.limit_top < 1000000:
		return Rect2(camera.limit_left, camera.limit_top, camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top)
	return Rect2(wizard.global_position - Vector2(16000.0, 6000.0), Vector2(32000.0, 12000.0))


## Seconds of the world's time: the same at any speed the game is run at.
static func _now() -> float:
	return float(Engine.get_physics_frames()) * Engine.time_scale / float(Engine.physics_ticks_per_second)


## The members of a group that could reach into an area: their place within `margin` of it (a pond's own region, for a pond).
static func _near(tree: SceneTree, group: String, area: Rect2, margin: float) -> Array:
	var out: Array = []
	for node in tree.get_nodes_in_group(group):
		if not node is Node2D or not is_instance_valid(node):
			continue
		if node is Pond:
			if (node as Pond).region().intersects(area):
				out.append(node)
		elif area.grow(margin).has_point((node as Node2D).global_position):
			out.append(node)
	return out


static func _flag(on: bool) -> float:
	return 1.0 if on else 0.0


static func _bit(traits: int, bit: int) -> float:
	return 1.0 if traits & bit != 0 else 0.0

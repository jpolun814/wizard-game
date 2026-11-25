extends GdUnitTestSuite
## The movement planning on paper (docs/handoff/23_movement_planning.md, stage 2): the drills of movement_drills, whose ways were proved with real bodies and real spells, put to the planner.
## It must find a way in each that has one and none in the others; it must use a spell nobody has told it of; and the rooms here are no more than tiles.

const BASE := 20  # the row of the flat ground
const DRILLS := preload("res://tests/checks/movement_drills.gd")


func _map(plan: PackedFloat32Array, slabs: Array) -> MoveMap:
	var cells := TileGrid.new(Vector2i(plan.size(), BASE + 14))
	for c in plan.size():
		for r in range(BASE + int(plan[c]), BASE + 14):
			cells.put(Vector2i(c, r), ArenaGen.STONE)
	for slab: Rect2i in slabs:
		for c in range(slab.position.x, slab.end.x):
			for r in range(slab.position.y, slab.end.y):
				cells.put(Vector2i(c - ArenaGen.FIRST_COL, r - ArenaGen.GROUND_ROW + BASE), ArenaGen.STONE)
	return MoveMap.new(cells, BASE + 14)


func _top(map: MoveMap, c: int) -> Vector2i:
	for r in BASE + 14:
		if map.can_stand(Vector2i(c, r)):
			return Vector2i(c, r)
	return Vector2i(c, 0)


func _floor(map: MoveMap, c: int) -> Vector2i:
	for r in range(BASE + 13, -1, -1):
		if map.can_stand(Vector2i(c, r)):
			return Vector2i(c, r)
	return Vector2i(c, 0)


func _say(plan: MovePlan) -> String:
	var out := PackedStringArray()
	for leg in plan.legs():
		for cast in leg.casts:
			out.append("%s%s" % [cast["spell"].spell_name, "" if cast["way"] == Vector2.ZERO else " %d" % roundi(rad_to_deg((cast["way"] as Vector2).angle()))])
	return ", ".join(out)


func test_every_drill_with_a_way_is_found_and_the_others_refused() -> void:
	var list: Node = DRILLS.new()
	list._list()
	var wrong := PackedStringArray()
	var slowest := 0
	for drill: Dictionary in list.drills:
		if (drill.has("thorns") or drill.has("shoal")) and drill.get("refuse", false):
			continue  # (there are no thorns or fish in these rooms, which are no more than tiles)
		var map := _map(drill["plan"], drill["slabs"])
		var spells: Array[Spell] = []
		for spell_name: String in drill["spells"]:
			spells.append(SpellData.SPELLS[spell_name])
		var plan := MovePlan.new(map, _floor(map, drill["start"]), _top(map, drill["page"]), {"spells": spells, "most": drill.get("max", Wizard.MAX_STAMINA)})
		var began := Time.get_ticks_usec()
		plan.work()
		var took := Time.get_ticks_usec() - began
		slowest = maxi(slowest, took)
		print("PLAN  %-55s %-5s %6.1f ms %5d places %5d flights  %4.1f s  %s" % [drill["name"], "found" if plan.found else "none", took / 1000.0, plan.places, plan.flights, plan.cost() if plan.found else 0.0, _say(plan)])
		if plan.found == bool(drill.get("refuse", false)):
			wrong.append(drill["name"])
	list.free()
	assert_array(wrong).override_failure_message("wrong about: " + ", ".join(wrong)).is_empty()


func _made_up(does: Dictionary, lasts := 1.0) -> Spell:
	var spell := Spell.new()
	spell.spell_name = "A Spell Nobody Knows"
	spell.school = "Earth"
	spell.gesture = "circle"
	spell.targeting = "positional"
	spell.cost = 20.0
	spell.parts = [{"where": "self", "for": lasts, "does": [does]}] as Array[Dictionary]
	return spell


func test_a_spell_it_has_never_met_is_used() -> void:
	var plan := PackedFloat32Array()
	plan.resize(48)
	for c in range(26, 48):
		plan[c] = -6.0
	var map := _map(plan, [])
	var none := MovePlan.new(map, _floor(map, 8), _top(map, 40), {"spells": []})
	none.work()
	assert_bool(none.found).is_false()
	for does: Dictionary in [{"do": "drive", "way": "up", "speed": 400.0}, {"do": "drive", "way": "up", "speed": 900.0, "grows": 1.0}]:
		var way := MovePlan.new(map, _floor(map, 8), _top(map, 40), {"spells": [_made_up(does)]})
		way.work()
		assert_bool(way.found).override_failure_message("it did not see what to do with %s" % does).is_true()
		assert_str(_say(way)).contains("A Spell Nobody Knows")
	var weak := MovePlan.new(map, _floor(map, 8), _top(map, 40), {"spells": [_made_up({"do": "drive", "way": "up", "speed": 60.0})]})
	weak.work()
	assert_bool(weak.found).override_failure_message("it thought a spell that lifts it 60 px would get it up 192").is_false()


func test_it_goes_only_over_ground_it_has_seen() -> void:
	var plan := PackedFloat32Array()
	plan.resize(48)
	var map := _map(plan, [])
	var blind := MovePlan.new(map, _floor(map, 6), _floor(map, 40), {"spells": [], "knows": func(tile: Vector2i) -> bool: return tile.x < 30})
	blind.work()
	assert_bool(blind.found).is_false()


func test_a_price_on_the_ground_is_paid_or_gone_round() -> void:
	var plan := PackedFloat32Array()
	plan.resize(48)
	var map := _map(plan, [])
	var thorns := func(tile: Vector2i) -> float: return 0.5 if tile.x >= 18 and tile.x < 26 else 0.0
	var way := MovePlan.new(map, _floor(map, 6), _floor(map, 40), {"spells": [], "price": thorns})
	way.work()
	assert_bool(way.found).is_true()
	var step := MovePlan.new(map, _floor(map, 6), _floor(map, 40), {"spells": [SpellData.SPELLS["Shadow Step"]], "price": func(tile: Vector2i) -> float: return 30.0 if tile.x >= 22 and tile.x < 26 else 0.0})
	step.work()
	assert_bool(step.found).is_true()


## Something in the way that harms whoever walks through it, in a stretch of columns.
class Peril extends Node:
	var box := Rect2()
	var harm := 25.0
	var slow := 0.5
	var ends: Array = []
	var jump := false

	func peril_at(point: Vector2) -> Dictionary:
		return {"harm": harm, "pace": slow, "jump": jump} if box.has_point(point) else {}

	func peril_box() -> Rect2:
		return box

	func undone_by() -> Array:
		return ends


## What it does about a stretch of harm this wide, holding these: "walks", or the spells it casts, or "no way".
func _about(width: int, ends: Array, held: Array, most := 200.0) -> String:
	var level := PackedFloat32Array()
	level.resize(60)
	var map := _map(level, [])
	var peril := Peril.new()
	peril.ends = ends
	peril.box = Rect2(20 * 32.0, BASE * 32.0 - 34.0, width * 32.0, 40.0)
	var spells: Array[Spell] = []
	for spell_name: String in held:
		spells.append(SpellData.SPELLS[spell_name])
	var plan := MovePlan.new(map, _floor(map, 14), _floor(map, 20 + width + 4), {"spells": spells, "most": most, "stamina": most, "perils": [peril]})
	plan.work()
	var out := _say(plan) if plan.found else "no way"
	peril.free()
	return "walks" if out == "" else out


func test_what_harms_is_jumped_waded_gone_over_or_put_an_end_to() -> void:
	print("PERIL narrow, nothing held: ", _about(4, [], []))
	for width: int in [12, 16]:
		for held: Array in [[], ["Rocket Jump"], ["Push"], ["Geyser"], ["Shadow Step"], ["Updraft"], ["Tornado"], ["Ignite"], ["Fire Breath"], ["Firewall"], ["Spark"], ["Jolt"], ["Flaming Sphere"], ["Frostbolt"]]:
			print("PERIL %2d wide, plants, %-18s whole: %-28s worn: %s" % [width, held, _about(width, Perils.PLANT, held), _about(width, Perils.PLANT, held, 45.0)])
	assert_str(_about(4, [], [])).is_equal("walks")   # (a jump is a move on foot)
	assert_str(_about(16, Perils.PLANT, ["Ignite"])).contains("Ignite")
	assert_str(_about(16, Perils.LIVES_IN_WATER, ["Ignite"])).not_contains("Ignite")   # fire does nothing to fish
	assert_str(_about(16, Perils.LIVES_IN_WATER, ["Spark"])).contains("Spark")
	assert_str(_about(16, Perils.LIVES_IN_WATER, ["Jolt"])).contains("Jolt")
	for held: String in ["Rocket Jump", "Push", "Tornado", "Updraft", "Shadow Step"]:  # (a Geyser throws straight up, and a thrown body steers too weakly to clear so much)
		assert_str(_about(16, [], [held])).override_failure_message("%s would carry it over, and it did not think of that: %s" % [held, _about(16, [], [held])]).contains(held)
	assert_str(_about(16, [], [], 45.0)).override_failure_message("worn to 45, it would wade through what would kill it").is_equal("no way")


extends Node

## A wizard that holds a spell that gets past a gate (a chasm, a flood, a piranha pit, a sentinel) goes across it to a page lying beyond, alive; and one that
## holds none does not get there, for the way is shut to it. Pages are taken off the map so that nothing else draws it away.
##
##     godot --headless --path . --fixed-fps 60 tests/cross_check.tscn -- seed=8 kind=flood spells=Frost%Bridge
## The wizard is set down beside the first gate of that kind. Spells are separated by commas, and a space in a name is written as %. It prints PASS or
## FAIL and exits with code 1 if any failed.

const SECONDS := 120.0

var seed_value := 8
var kind := "flood"
var spells := ["Frost Bridge"]
var _failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):
			seed_value = int(arg.substr(5))
		elif arg.begins_with("kind="):
			kind = arg.substr(5)
		elif arg.begins_with("spells="):
			spells = Array(arg.substr(7).replace("%", " ").split(",")).filter(func(name_: String) -> bool: return name_ != "")
	MatchState.hurry = 100.0
	World.random_start = false
	World.next_seed = seed_value
	var tree := get_tree()
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await tree.process_frame
	await tree.process_frame
	world.player.take_damage(100000)
	var page_name := ""
	for candidate in ["Volcano", "Tornado", "Eclipse"]:  # a page it does not hold
		if not spells.has(candidate):
			page_name = candidate
			break
	for page in tree.get_nodes_in_group("pages"):
		page.queue_free()
	var wizard: Mob = null
	var rival: Mob = null
	for mob in tree.get_nodes_in_group("mobs"):
		if mob.kind == "dark_wizard":
			wizard = mob
		elif rival == null and Mob.KINDS[mob.kind].role == "wizard":
			rival = mob  # it stands far off, so that the wizard has someone to be the last of
	for mob in tree.get_nodes_in_group("mobs"):
		if mob != wizard and mob != rival:
			mob.set_physics_process(false)
			mob.global_position = Vector2(-9000.0, -9000.0)
	var crossing := {}
	var entry := {}
	for found in world.crossings():
		if found["kind"] == kind:
			crossing = found
			break
	if crossing.is_empty():
		print("NOTE  seed %d has no %s gate" % [seed_value, kind])
		tree.quit(0)
		return
	for gate in world._gates:
		if WorldBuilder.toll_key(gate) == crossing["key"]:
			entry = gate
	var outside: Vector2i = entry["outside"]
	var here: Vector2i = world.nav.nearest(outside + Vector2i(0, -1))
	var middle: float = crossing["post"].global_position.x if kind == "sentinel" else (crossing["span"] as Rect2).get_center().x
	var side := 1 if middle / 32.0 > outside.x else -1
	var far_tile := Vector2i(-1, -1)  # a place well beyond the gate, to which the only way is over it
	for dx in range(3, 90):
		for dy in range(-40, 41):
			var tile := Vector2i(floori(middle / 32.0) + side * dx, outside.y - 1 + dy)
			if far_tile.x >= 0 or not world.nav.can_stand(tile) or world.nav.toll_at(tile) != "":
				continue
			var way: Array[Vector2i] = world.nav.path(here, tile)
			var last := -1.0e9  # how far along the way the crossing goes
			for step in way:
				if world.nav.toll_at(step) == crossing["key"]:
					last = maxf(last, step.x * side)
			if last > -1.0e9 and tile.x * side > last + 4 and world.nav.path(here, tile, [crossing["key"]]).is_empty():
				far_tile = tile
	if far_tile.x < 0:
		print("NOTE  no place beyond the %s gate at %s to go to (it lies behind a gate that has to be cleared)" % [kind, str(outside)])
		tree.quit(0)
		return
	var start := outside
	if kind == "sentinel":  # a sentinel's gate begins well short of the statue: the wizard comes at it from out of its sight
		for dx in range(26, 70):
			for dy in range(-40, 41):
				var tile := Vector2i(floori(middle / 32.0) - side * dx, outside.y - 1 + dy)
				if start != outside or not world.nav.can_stand(tile) or world.nav.toll_at(tile) != "":
					continue
				var way: Array[Vector2i] = world.nav.path(tile, far_tile)
				if way.any(func(t: Vector2i) -> bool: return world.nav.toll_at(t) == crossing["key"]):
					start = tile + Vector2i(0, 1)
	wizard.global_position = Vector2((start.x + 0.5) * 32.0, start.y * 32.0 - 2.0)
	rival.global_position = Vector2(-9000.0, -9000.0)
	rival.set_physics_process(false)
	var page := PagePickup.new()
	page.page = page_name
	page.position = Vector2((far_tile.x + 0.5) * 32.0, (far_tile.y + 1) * 32.0 - 20.0)
	world.add_child(page)
	print("seed %d, %s gate at %s: the wizard at x %.0f, the page at x %.0f, holding %s" % [seed_value, kind, str(outside), wizard.global_position.x, page.position.x, str(spells)])
	var before := wizard.hp
	wizard.ledger = Ledger.of(spells)
	var passed := false
	var time := 0.0
	while time < SECONDS and not passed and not wizard.is_dead():
		await tree.physics_frame
		time += 1.0 / 60.0
		wizard.stamina = maxf(wizard.stamina, 100.0)
		passed = wizard.ledger.knows(page_name)
	if not spells.is_empty():
		_verdict(passed and not wizard.is_dead(), "the wizard has the page beyond by %.0f s, alive (x %.0f; hp %d of %d; %s)" % [time, wizard.global_position.x, wizard.hp, before, (wizard.brain as WizardBrain).status()])
	else:
		_verdict(not passed, "a wizard with no spell does not get the page beyond (x %.0f)" % wizard.global_position.x)
	print("done" if _failures == 0 else "%d FAILED" % _failures)
	tree.quit(1 if _failures > 0 else 0)


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

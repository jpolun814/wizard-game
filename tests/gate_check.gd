extends Node

## A wizard that holds the right spell goes to each gate that spells can clear (thorns, ice, gas, a wall), clears it, and the ways about the
## world are built again with the gate gone. Pages are taken off the map so that nothing else draws the wizard away.
##
##     godot --headless --path . --fixed-fps 60 tests/gate_check.tscn -- seed=8 spells=Ignite,Stonefall only=ice
## The wizard walks to the gates itself, so it can take minutes of play; only=KIND sets it down beside the first gate of that kind instead.
## A gate behind another kind (a chasm, say) is noted, not failed. It prints PASS or FAIL for each gate and exits with code 1 if any failed.

const SECONDS := 420.0

var seed_value := 8
var spells := ["Ignite", "Fire Breath", "Stonefall"]
var only := ""  # only=KIND: tries just the gates of one kind, from the wizard standing beside the first
var _failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):
			seed_value = int(arg.substr(5))
		elif arg.begins_with("only="):
			only = arg.substr(5)
		elif arg.begins_with("spells="):
			spells = Array(arg.substr(7).replace("%", " ").split(","))
	MatchState.hurry = 100.0  # the portal does not give way during the test
	World.random_start = false
	World.next_seed = seed_value
	var tree := get_tree()
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await tree.process_frame
	await tree.process_frame
	world.player.take_damage(100000)  # the player stands down
	for page in tree.get_nodes_in_group("pages"):
		page.queue_free()
	var wizard: Mob = null
	for mob in tree.get_nodes_in_group("mobs"):
		if mob.kind == "dark_wizard":
			wizard = mob
	wizard.ledger = Ledger.of(spells)
	for mob in tree.get_nodes_in_group("mobs"):
		if mob != wizard:
			mob.set_physics_process(false)  # the others stand still, far off (the wizard does nothing with no one else in play)
			mob.global_position = Vector2(-9000.0, -9000.0)
	var gates := world.closed_gates()
	print("seed %d has %d gates that spells can clear: %s" % [seed_value, gates.size(), gates.map(func(g: Dictionary) -> String: return g["kind"])])
	var wanted: Array[Dictionary] = []
	for gate in gates:
		if (only == "" or gate["kind"] == only) and WizardBrain.CLEARS.get(gate["kind"], []).any(func(spell: String) -> bool: return spells.has(spell)):
			wanted.append(gate)
	if only != "" and not wanted.is_empty():
		var at: Vector2i = wanted[0]["outside"]
		wizard.global_position = Vector2((at.x + 0.5) * 32.0, at.y * 32.0 - 2.0)
	var version := world.nav.version
	var time := 0.0
	var done := {}
	while time < SECONDS and done.size() < wanted.size() and not wizard.is_dead():
		await tree.physics_frame
		time += 1.0 / 60.0
		wizard.stamina = maxf(wizard.stamina, 100.0)  # the cost of a spell is not what is tried here
		for gate in wanted:
			if gate["entry"].get("open", false) and not done.has(gate["outside"]):
				done[gate["outside"]] = true
				print("PASS  the %s gate at %s is cleared after %.0f s" % [gate["kind"], str(gate["outside"]), time])
	for gate in wanted:
		if done.has(gate["outside"]):
			continue
		var floor_tile: Vector2i = gate["outside"] + Vector2i(0, -1)
		var here: Vector2i = world.nav.nearest(_tile_of(wizard))
		var stand: Vector2i = world.nav.nearest(floor_tile)
		if absi(stand.x - floor_tile.x) + absi(stand.y - floor_tile.y) > 3 or world.nav.path(here, stand).is_empty():
			print("NOTE  the %s gate at %s cannot be got to on foot (it lies behind another gate)" % [gate["kind"], str(gate["outside"])])
			continue
		_verdict(false, "the %s gate at %s is not cleared in %.0f s" % [gate["kind"], str(gate["outside"]), SECONDS])
		print("   the wizard: %s, at tile %s, stamina %.0f, dead %s" % [(wizard.brain as WizardBrain).status(), str(_tile_of(wizard)), wizard.stamina, wizard.is_dead()])
	_verdict(wanted.is_empty() or world.nav.version > version, "the ways are built again after a gate goes")
	_verdict(not wizard.is_dead(), "the wizard lived")
	print("gates are cleared" if _failures == 0 else "%d FAILED" % _failures)
	tree.quit(1 if _failures > 0 else 0)


func _tile_of(wizard: Mob) -> Vector2i:
	return Vector2i(floori(wizard.global_position.x / 32.0), floori((wizard.global_position.y - 1.0) / 32.0))


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

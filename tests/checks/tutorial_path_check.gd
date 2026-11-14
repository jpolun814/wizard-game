extends Node

## The tutorial room is shut off place from place: the cliff cannot be climbed without the chant of the double jump (and can with it), the thorns
## kill whoever walks into them until they are burnt, the pit cannot be jumped, and a wizard in the pond or the pit is put back on its edge.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/tutorial_path_check.tscn

var _failures := 0
var room: Tutorial
var player: Wizard
var _deaths := 0
var _falls := 0   # deaths alone


func _ready() -> void:
	room = load("res://scenes/tutorial.tscn").instantiate()
	add_child(room)
	for k in 20:
		await get_tree().process_frame
	player = room.player
	player.ledger = Ledger.complete()  # (what is in the book is tried in tutorial_check: here it is the ground)
	player.died.connect(func() -> void:
		_deaths += 1
		_falls += 1)
	player.damaged.connect(func(_amount: int) -> void: _deaths += 1)  # (a blow counts as much as a death here: nothing in the room kills for no reason, so it is the blow that is looked for)
	for f in 90:
		await get_tree().physics_frame  # (the mobs fade in first)
	for node: Node in get_tree().get_nodes_in_group("mobs"):
		node.set_physics_process(false)  # the dummy and the turrets stand quiet: only the ground is tried here
	await _dummy()
	await _giant_gate()
	await _pond()
	await _turrets()
	await _thorns()
	await _cliff()
	await _chant_gap()
	await _dark()
	await _pit()
	await _wall()
	await _sentinel()
	await _gas()
	await _second_pit()
	await _dark_pond()
	await _slowing()
	print("the tutorial room is shut off place from place" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _put(column: int) -> void:
	player.global_position = Vector2(ArenaGen.column_x(column), ArenaGen.surface_y(room._cells, column) - 20.0)
	player.velocity = Vector2.ZERO
	player.grant_unlimited(1.0e7)


func _column() -> float:
	return player.global_position.x / float(ArenaGen.TILE)


## Runs right and jumps whenever on the ground (and once more at the top of the jump, when it can), for a number of seconds.
func _run_and_jump(seconds: float, second_jump: bool, until_column: float) -> void:
	Input.action_press("move_right")
	var frames := int(seconds * 60.0)
	for f in frames:
		await get_tree().physics_frame
		if player.is_on_floor():
			player.request_jump()
		elif second_jump and player.velocity.y > -40.0 and player.velocity.y < 60.0:
			player.request_jump()
		if _column() >= until_column and player.is_on_floor():
			break
	Input.action_release("move_right")


## Runs right (jumping, with a second jump if it has one) until it has got to a column, died, or the time is out.
func _run_until(column: float, seconds: float) -> void:
	var deaths := _falls
	Input.action_press("move_right")
	for f in int(seconds * 60.0):
		await get_tree().physics_frame
		if player.is_on_floor():
			player.request_jump()
		elif player.air_jump_time > 0.0 and player.velocity.y > -40.0 and player.velocity.y < 60.0:
			player.request_jump()
		if _column() >= column or _falls > deaths:
			break
	Input.action_release("move_right")


func _dummy() -> void:
	var at := room._dummy.global_position.x / float(ArenaGen.TILE)
	var deaths := _deaths
	_put(-12)
	for f in 20:
		await get_tree().physics_frame
	await _run_until(at + 6.0, 6.0)
	_verdict(_deaths == deaths and _column() >= at + 6.0, "the dummy can be walked past, and hurts no one (column %.1f)" % _column())
	for f in 10:
		await get_tree().physics_frame
	room._dummy.take_damage(1000)
	for f in 30:
		await get_tree().physics_frame
	_verdict(room._dummy.is_dead(), "the dummy can be killed")
	deaths = _deaths
	_put(-12)
	for f in 20:
		await get_tree().physics_frame
	await _run_until(at + 6.0, 6.0)
	_verdict(_deaths == deaths and _column() >= at + 6.0, "and then it can be walked past (column %.1f)" % _column())


func _giant_gate() -> void:
	var at: int = Tutorial.GIANT_COL
	var deaths := _deaths
	_put(at - 7)
	for f in 20:
		await get_tree().physics_frame
	await _run_until(at + 6.0, 6.0)
	_verdict(not player.dead, "the giant does not kill for walking past (it fights, and nothing more)")
	room.spawn_spell("Faint", "positional", room._giant.center(), 0.0, {}, player)
	for f in 10:
		await get_tree().physics_frame
	_verdict(room._giant.is_fainted(), "a Faint puts it down")
	deaths = _deaths
	_put(at - 7)
	for f in 20:
		await get_tree().physics_frame
	await _run_until(at + 6.0, 6.0)
	_verdict(_deaths == deaths and _column() >= at + 6.0, "and then it can be walked past (column %.1f)" % _column())


func _turrets() -> void:
	for node: Node in get_tree().get_nodes_in_group("mobs"):
		if node is Mob and node.kind == "turret":
			node.set_physics_process(true)
	var goal: int = 106
	var deaths := _deaths
	_put(Tutorial.TURRET_ZONE.x - 2)
	for f in 20:
		await get_tree().physics_frame
	await _run_until(goal, 12.0)

	deaths = _deaths
	for f in 30:
		await get_tree().physics_frame
	_put(Tutorial.TURRET_ZONE.x - 4)
	for f in 20:
		await get_tree().physics_frame
	room.spawn_spell("Barrier", "positional", player.center(), 0.0, {}, player)
	await _run_until(goal, 12.0)
	_verdict(_deaths == deaths and _column() >= goal, "and with a Barrier it is got through alive (column %.1f)" % _column())
	for node: Node in get_tree().get_nodes_in_group("mobs"):
		if node is Mob and node.kind == "turret":
			node.set_physics_process(false)


func _pond() -> void:
	var span := Tutorial.POND_SPAN
	var deaths := _deaths
	_put(span.x - 4)
	for f in 20:
		await get_tree().physics_frame
	await _run_until(span.y + 3.0, 12.0)
	_verdict(_deaths > deaths, "wading through the pond among the piranhas kills (deaths %d)" % (_deaths - deaths))
	var water_top: float = room._shoal.water.position.y
	for k in 6:  # a Spark lands on the water, six times along it, and the fish are dead
		var strike := SparkStrike.new()
		room.add_child(strike)
		strike.setup("Spark", Vector2(ArenaGen.column_x(span.x + 4 + 3 * k), water_top - 150.0), 0.0)
	for f in 30:
		await get_tree().physics_frame
	_verdict(not is_instance_valid(room._shoal) or not room._shoal.alive(), "and Spark kills the piranhas")
	deaths = _deaths
	_put(span.x - 4)
	for f in 20:
		await get_tree().physics_frame
	await _run_until(span.y + 3.0, 12.0)
	_verdict(_deaths == deaths and _column() >= span.y + 3.0, "and then the pond can be waded across (column %.1f)" % _column())


func _cliff() -> void:
	_put(Tutorial.CLIFF_COL - 6)
	for f in 20:
		await get_tree().physics_frame
	await _run_and_jump(6.0, false, Tutorial.CLIFF_COL + 2.0)
	_verdict(_column() < Tutorial.CLIFF_COL, "the cliff cannot be climbed with a single jump (column %.1f)" % _column())
	var foot := Vector2(ArenaGen.column_x(Tutorial.CLIFF_COL - 3), ArenaGen.surface_y(room._cells, Tutorial.CLIFF_COL - 3))
	var vine := Liana.new()
	vine.line = PackedVector2Array([foot, foot + Vector2(0.0, -380.0)])
	room.add_child(vine)
	_put(Tutorial.CLIFF_COL - 3)
	for f in 20:
		await get_tree().physics_frame
	Input.action_press("move_up")
	for f in 60 * 4:
		await get_tree().physics_frame
		if player.global_position.y < foot.y - 340.0:
			break
	Input.action_release("move_up")
	Input.action_press("move_right")
	for f in 60 * 3:
		await get_tree().physics_frame
		if _column() > Tutorial.CLIFF_COL + 2.0 and player.is_on_floor():
			break
	Input.action_release("move_right")
	_verdict(_column() > Tutorial.CLIFF_COL + 2.0, "and a vine climbs it (column %.1f)" % _column())
	vine.queue_free()


func _chant_gap() -> void:
	var span := Tutorial.CHANT_GAP
	_put(span.x - 5)
	for f in 20:
		await get_tree().physics_frame
	await _run_and_jump(6.0, false, span.y + 3.0)
	_verdict(_column() < span.y, "the first gap cannot be jumped (column %.1f)" % _column())
	player.air_jump_time = 30.0
	player.air_jump_ready = true
	_put(span.x - 5)
	for f in 20:
		await get_tree().physics_frame
	await _run_and_jump(8.0, true, span.y + 3.0)
	_verdict(_column() >= span.y + 3.0, "and can with the double jump (column %.1f)" % _column())
	player.air_jump_time = 0.0


## Runs right, jumping at the foot of each strip of spikes (when it is seen), from the gap before it.
func _run_hopping(until: float, seconds: float) -> void:
	var deaths := _deaths
	Input.action_press("move_right")
	for f in int(seconds * 60.0):
		await get_tree().physics_frame
		for strip: int in Tutorial.SPIKE_STRIPS:
			if player.is_on_floor() and strip - _column() > 0.2 and strip - _column() < 1.2:
				player.request_jump()
		if _column() >= until or _deaths > deaths:
			break
	Input.action_release("move_right")


func _dark() -> void:
	var first: int = Tutorial.SPIKE_STRIPS[0]
	var deaths := _deaths
	_put(first - 4)
	for f in 30:
		await get_tree().physics_frame
	_verdict(room._night.visible, "it is dark along the dark stretch")
	_verdict(not room._spikes.shown(), "and the spikes are not seen without a light")
	await _run_until(first + 8.0, 6.0)
	_verdict(_deaths > deaths, "walking into the spikes unseen kills (deaths %d)" % (_deaths - deaths))
	room.spawn_spell("Flare", "positional", Vector2(ArenaGen.column_x(first - 3), ArenaGen.surface_y(room._cells, first) - 60.0), 0.0, {}, player)
	_put(first - 3)
	for f in 40:
		await get_tree().physics_frame
	_verdict(room._spikes.shown(), "a Flare shows them")
	deaths = _deaths
	await _run_hopping(Tutorial.THICKET_DARK.x - 2.0, 14.0)
	_verdict(_deaths == deaths and _column() >= Tutorial.THICKET_DARK.x - 2.0, "and with them seen they are jumped (column %.1f)" % _column())


func _thorns() -> void:
	var span := Tutorial.THICKET_SPAN
	_put(span.x - 3)
	for f in 20:
		await get_tree().physics_frame
	Input.action_press("move_right")
	var died := false
	for f in 60 * 40:
		await get_tree().physics_frame
		if _column() < span.x - 5.0:  # put back at the place, where they had been working
			died = true
			break
		if _column() > span.y + 1:
			break
	Input.action_release("move_right")
	_verdict(died, "the thorns kill whoever walks into them, who is put back at the place (column %.1f)" % _column())
	_put(span.x - 6)
	for f in 20:
		await get_tree().physics_frame
	room.spawn_spell("Ignite", "directional", player.center() + Vector2(10.0, 0.0), 0.0, {}, player)
	for f in 60 * 12:
		await get_tree().physics_frame
		if room.thorns_left() <= (Tutorial.THICKETS.size() - 1) * Tutorial.THICKET_LAYERS:
			break
	_verdict(room.thorns_left() == (Tutorial.THICKETS.size() - 1) * Tutorial.THICKET_LAYERS, "a fireball burns all of the first thicket's thorns away (%d layers left in the others)" % room.thorns_left())


func _pit() -> void:
	_put(Tutorial.GAP_SPAN.x - 3)
	for f in 20:
		await get_tree().physics_frame
	await _run_and_jump(6.0, true, Tutorial.GAP_SPAN.y + 2.0)
	_verdict(_column() < Tutorial.GAP_SPAN.y, "the pit cannot be jumped (column %.1f)" % _column())
	_verdict(player.global_position.y < ArenaGen.surface_y(room._cells, Tutorial.GAP_SPAN.x - 3) + 40.0, "and whoever fell in is back on the edge")


func _wall() -> void:
	var col := Tutorial.WALL_COL
	player.air_jump_time = 30.0
	player.air_jump_ready = true
	_put(col - 6)
	for f in 20:
		await get_tree().physics_frame
	await _run_and_jump(6.0, true, col + 5.0)
	_verdict(_column() < col, "the wall of brick cannot be jumped, even twice (column %.1f)" % _column())
	room._wall.take_blow_near(Vector2(ArenaGen.column_x(col + 1), ArenaGen.surface_y(room._cells, col) - 60.0), 1000.0)
	for f in 60:
		await get_tree().physics_frame
	_put(col - 6)
	for f in 20:
		await get_tree().physics_frame
	await _run_until(col + 5.0, 6.0)
	_verdict(_column() >= col + 5.0, "and once it is brought down it can be walked through (column %.1f)" % _column())
	player.air_jump_time = 0.0


func _sentinel() -> void:
	var zone := Tutorial.SENTINEL_ZONE
	for f in 5:
		await get_tree().physics_frame
	var deaths := _deaths
	_put(zone.x - 2)
	for f in 20:
		await get_tree().physics_frame
	await _run_until(zone.y + 3.0, 12.0)
	_verdict(_deaths > deaths, "crossing the eye's stretch in its sight kills (deaths %d)" % (_deaths - deaths))
	deaths = _deaths
	for f in 30:
		await get_tree().physics_frame
	_put(zone.x - 4)
	for f in 20:
		await get_tree().physics_frame
	room.spawn_spell("Barrier", "positional", player.center(), 0.0, {}, player)
	await _run_until(zone.y + 3.0, 12.0)
	_verdict(_deaths == deaths and _column() >= zone.y + 3.0, "and with a Barrier it is crossed alive (column %.1f)" % _column())


func _gas() -> void:
	var span := Tutorial.GAS_SPAN
	var deaths := _deaths
	_put(span.x - 4)
	for f in 20:
		await get_tree().physics_frame
	await _run_until(span.y + 3.0, 10.0)
	_verdict(_deaths > deaths, "walking through the poison gas kills (deaths %d)" % (_deaths - deaths))
	for bank: GasBank in room._gas:
		if is_instance_valid(bank):
			bank.dissipate()  # the wind takes it
	for f in 90:
		await get_tree().physics_frame
	deaths = _deaths
	_put(span.x - 4)
	for f in 20:
		await get_tree().physics_frame
	await _run_until(span.y + 3.0, 10.0)
	_verdict(_deaths == deaths and _column() >= span.y + 3.0, "and with the gas blown away it is crossed (column %.1f)" % _column())


func _second_pit() -> void:
	_put(Tutorial.PIT_TWO.x - 3)
	for f in 20:
		await get_tree().physics_frame
	await _run_and_jump(6.0, true, Tutorial.PIT_TWO.y + 2.0)
	_verdict(_column() < Tutorial.PIT_TWO.y, "the second pit cannot be jumped (column %.1f)" % _column())


func _dark_pond() -> void:
	var span := Tutorial.POND_TWO
	var deaths := _deaths
	var deaths_before_wade := _falls
	_put(span.x - 4)
	for f in 30:
		await get_tree().physics_frame
	_verdict(room._night.visible, "it is dark at the second pond")
	Input.action_press("move_right")  # (waded on foot: a runner that hops the whole way may clear the water before a fish is on it)
	for f in 60 * 12:
		await get_tree().physics_frame
		if _column() >= span.y + 3.0 or _falls > deaths_before_wade:
			break
	Input.action_release("move_right")
	_verdict(_deaths > deaths, "wading it among the piranhas kills (deaths %d)" % (_deaths - deaths))
	var water_top: float = room._shoal_two.water.position.y
	for k in 6:
		var strike := SparkStrike.new()
		room.add_child(strike)
		strike.setup("Spark", Vector2(ArenaGen.column_x(span.x + 4 + 3 * k), water_top - 150.0), 0.0)
	for f in 30:
		await get_tree().physics_frame
	deaths = _deaths
	_put(span.x - 4)
	for f in 20:
		await get_tree().physics_frame
	await _run_until(span.y + 3.0, 12.0)
	_verdict(_deaths == deaths and _column() >= span.y + 3.0, "and after a Spark it is waded across (column %.1f)" % _column())


## The slowing place: one fast skeleton stands guard, and a Mudslide or a Blizzard laid under it slows it.
func _slowing() -> void:
	var runners := []
	for node: Node in get_tree().get_nodes_in_group("mobs"):
		if node is Mob and node.kind == "runner":
			runners.append(node)
	_verdict(runners.size() == 1, "one fast skeleton stands at its post (%d)" % runners.size())
	_verdict(Mob.KINDS["runner"].speed > 2.0, "it runs faster than a wizard walks")
	var foe: Mob = runners[0]
	var mud := Mudslide.new()
	mud.width = 200.0
	room.add_child(mud)
	mud.global_position = foe.global_position - Vector2(100.0, 0.0)
	for f in 40:
		await get_tree().physics_frame
	_verdict(foe.is_slowed(), "a Mudslide under one slows it")
	_put(Tutorial.SLOW_ZONE.x + 10)
	player.take_damage(8, false)  # one blow from it is a death: the wizard is on their feet again at the start of the place
	for f in 30:
		await get_tree().physics_frame
	_verdict(_column() < Tutorial.SLOW_ZONE.x, "a blow in the slowing place is a death (column %.1f)" % _column())


## The gauntlet: a tall wall, a pit at the foot of every pit, and each gate kills whoever is caught in it.
func _gauntlet() -> void:
	_verdict(Tutorial.WALL_ROWS >= 22, "the tall wall is taller than a rocket jump reaches (%d rows)" % Tutorial.WALL_ROWS)
	_verdict(room._giant.max_hp >= 10000, "the giant has so much strength that no one would trade blows with it")
	_verdict(room._pit_spikes != null and room._pit_spikes.always_seen, "there are spikes in plain sight at the bottom of the pits")
	_verdict(Tutorial.THICKET_DARK.x - (Tutorial.SPIKE_STRIPS.back() + 3) >= 8, "the last spikes of the dark are well clear of the thorns")
	for zone: Vector2i in Tutorial.GAUNTLET_ZONES:
		_verdict(zone.x > Tutorial.GAUNTLET_FROM and zone.y < ArenaGen.right_wall - 6, "the gate at columns %d to %d lies inside the room, past the thorns" % [zone.x, zone.y])


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

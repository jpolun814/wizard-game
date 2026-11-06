extends Node

## The tutorial room is shut off place from place: the cliff cannot be climbed without the chant of the double jump (and can with it), the thorns
## kill whoever walks into them until they are burnt, the pit cannot be jumped, and a wizard in the pond or the pit is put back on its edge.
##
##     godot --headless --fixed-fps 60 --path . tests/tutorial_path_check.tscn

var _failures := 0
var room: Tutorial
var player: Wizard


func _ready() -> void:
	room = load("res://scenes/tutorial.tscn").instantiate()
	add_child(room)
	for k in 20:
		await get_tree().process_frame
	player = room.player
	for node: Node in get_tree().get_nodes_in_group("mobs"):
		node.set_physics_process(false)  # the dummy and the turrets stand quiet: only the ground is tried here
	await _cliff()
	await _thorns()
	await _pit()
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


func _cliff() -> void:
	_put(Tutorial.CLIFF_COL - 6)
	for f in 20:
		await get_tree().physics_frame
	await _run_and_jump(6.0, false, Tutorial.CLIFF_COL + 2.0)
	_verdict(_column() < Tutorial.CLIFF_COL, "the cliff cannot be climbed with a single jump (column %.1f)" % _column())
	player.air_jump_time = 30.0
	player.air_jump_ready = true
	_put(Tutorial.CLIFF_COL - 6)
	for f in 20:
		await get_tree().physics_frame
	await _run_and_jump(8.0, true, Tutorial.CLIFF_COL + 2.0)
	_verdict(_column() >= Tutorial.CLIFF_COL + 2.0, "and can with the double jump (column %.1f)" % _column())
	player.air_jump_time = 0.0


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
		if room.thorns_left() == 0:
			break
	_verdict(room.thorns_left() == 0, "a fireball burns all of the thorns away")


func _pit() -> void:
	_put(Tutorial.GAP_SPAN.x - 3)
	for f in 20:
		await get_tree().physics_frame
	await _run_and_jump(6.0, true, Tutorial.GAP_SPAN.y + 2.0)
	_verdict(_column() < Tutorial.GAP_SPAN.y, "the pit cannot be jumped (column %.1f)" % _column())
	_verdict(player.global_position.y < ArenaGen.surface_y(room._cells, Tutorial.GAP_SPAN.x - 3) + 40.0, "and whoever fell in is back on the edge")


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

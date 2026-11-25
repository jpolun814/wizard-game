extends Node
## An AI wizard that knows Rocket Jump and Featherfall stands at the lower landing of a swinging stair that goes up, and is made to want the landing above.
## Prints whether it gets there, and how long it takes: with the switch `stairs` off (AI_OFF=stairs) it can only wait for the stair.
func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 9
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var wizard: Wizard = null
	for each: Wizard in get_tree().get_nodes_in_group("wizards"):
		if each.brain != null:
			wizard = each
			break
	for other: Wizard in get_tree().get_nodes_in_group("wizards"):
		if other != wizard:
			other.global_position = Vector2(20000.0, 100.0) if false else other.global_position
	wizard.ledger.learn("Rocket Jump")
	wizard.ledger.learn("Featherfall")
	var from := Vector2i(80, 98)
	var to := Vector2i(92, 87)
	wizard.global_position = Vector2((from.x + 0.5) * 32.0, (from.y + 1) * 32.0 - 1.0)
	wizard.velocity = Vector2.ZERO
	var t := 0.0
	var arrived := false
	var hopped := false
	var frame := 0
	var lit := false
	var hop_at := 0.0
	var path: Array[Vector2i] = [from, to]
	while t < 40.0:
		wizard.stamina = maxf(wizard.stamina, 150.0)
		if wizard.brain.route.done():
			wizard.brain.route.set_path(path)
		await get_tree().physics_frame
		t += 1.0 / 60.0
		frame += 1
		var leap: Dictionary = wizard.brain.moves.leap
		if wizard.rocket_time > 0.0 and not lit:
			lit = true
			print("  rocket lit at %.2f s, y %.0f" % [t, wizard.global_position.y])
		if hopped and not leap.is_empty() and int(t * 60.0) % 6 == 0 and t < hop_at + 1.2:
			print("    leap: air %.2f helpers %s vy %.0f pen %s stamina %.0f" % [leap["air"], leap.get("helpers"), wizard.velocity.y, wizard.pen.active(), wizard.stamina])
		if not leap.is_empty() and not hopped:
			hopped = true
			hop_at = t
			print("  the hop began at %.1f s from %s (key %s)" % [t, wizard.global_position, leap["key"]])
		if (hopped and (frame % 15) == 0 and t < hop_at + 6.0) or (not hopped and int(t * 60.0) % 300 == 0):
			print("  t=%.0f at %s, waiting for stair: %s, idle %.1f, route %s" % [t, wizard.global_position, wizard.brain.route.waiting_for_stair, wizard.brain.travel.stair_idle, wizard.brain.route.status()])
		if wizard.global_position.y < float(to.y + 1) * 32.0 + 8.0 and wizard.global_position.x > float(to.x) * 32.0 - 40.0 and wizard.is_on_floor():
			arrived = true
			break
	print("RESULT: %s after %.1f s (at %s)" % ["REACHED THE UPPER LANDING" if arrived else "did not get up", t, wizard.global_position])
	get_tree().quit()

extends Node
## Measures the open air above a swinging stair's shaft: from the stair's middle, how far up a wizard can go before rock, and where the upper landing lies.
func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 9
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Wizard = world.player
	player.movement_enabled = true
	var goal := Vector2(2960.0, 2816.0)  # the upper landing, on the hinge side, 352 px up and about 384 px across
	for feather in [false, true]:
		for delay in [0.0, 0.2, 0.4]:  # how long after stepping off the landing it fires
			player.global_position = Vector2(2570.0, 3167.0)
			player.velocity = Vector2.ZERO
			player.feather_time = 30.0 if feather else 0.0
			await _frames(20)
			var start := player.global_position
			Input.action_press("move_right")
			var fired := false
			var airborne := 0.0
			var t := 0.0
			var peak := 0.0
			var landed := false
			var end := player.global_position
			while t < 7.0:
				await get_tree().physics_frame
				t += 1.0 / 60.0
				if not player.is_on_floor():
					airborne += 1.0 / 60.0
				if not fired and airborne > delay and not player.is_on_floor():
					fired = true
					RocketJump.cast(player)
				peak = maxf(peak, start.y - player.global_position.y)
				end = player.global_position
				if fired and airborne > 0.5 and player.is_on_floor():
					landed = true
					break
			Input.action_release("move_right")
			var on_upper := landed and absf(end.y - goal.y) < 40.0 and absf(end.x - goal.x) < 200.0
			print("feather %s, fires %.1f s after stepping off: peak %.0f up, landed at (%.0f, %.0f) %s" % [feather, delay, peak, end.x, end.y, "ON THE UPPER LANDING" if on_upper else ("(somewhere else)" if landed else "(still in the air)")])
	get_tree().quit()


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame

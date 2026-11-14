extends Node

## A Flaming Sphere cast in the waiting room appears, rolls along the ground and stays lit for a while.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/lab_sphere_check.tscn
## It prints PASS or FAIL and exits with code 1 if the ball did not appear and roll.


func _ready() -> void:
	var lab: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Wizard = lab.player
	lab.spawn_spell("Flaming Sphere", "directional", player.center(), 0.0, {"length": 90.0}, player)
	await get_tree().physics_frame
	var balls := get_tree().get_nodes_in_group("fires").filter(func(n) -> bool: return n is FlamingSphere)
	var seen: bool = balls.size() == 1
	var start := Vector2.ZERO
	if seen:
		start = balls[0].global_position
	for k in 120:
		await get_tree().physics_frame
	var alive: bool = seen and is_instance_valid(balls[0]) and not balls[0]._out
	var moved: float = balls[0].global_position.x - start.x if alive else 0.0
	print("%s  the sphere appears in the waiting room (%d)" % ["PASS" if seen else "FAIL", balls.size()])
	print("%s  and is still lit and rolling after two seconds (%.0f px)" % ["PASS" if alive and moved > 100.0 else "FAIL", moved])
	get_tree().quit(0 if alive and moved > 100.0 else 1)

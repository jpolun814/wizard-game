extends Node

## Fire melts a Blizzard's snowbank: a fireball that strikes the bank takes a bite out of it at the spot, deepest where it struck.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/blizzard_melt_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 3
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var feet: Vector2 = world.player.global_position
	for rival in world.rivals:
		rival.set_physics_process(false)
		rival.global_position += Vector2(0.0, -4000.0)
	var snow := Blizzard.new()
	snow.polygon = PackedVector2Array([Vector2(0, -60), Vector2(320, -60), Vector2(320, 60), Vector2(0, 60)])
	world.add_child(snow)
	snow.setup("Blizzard", Vector2(feet.x - 160.0, feet.y - 20.0), 0.0)
	await get_tree().physics_frame
	snow._pile.fill(30.0)
	var middle := snow._pile.size() / 2
	var edge := 4
	var spot: Vector2 = snow.global_position + Vector2(middle * Blizzard.STEP, snow._floors[middle] - 15.0)
	Blizzard.melt_at(get_tree(), spot)
	_verdict(snow._pile[middle] < 25.0, "a fireball striking the bank melts the snow where it struck (%.0f of 30 left)" % snow._pile[middle])
	_verdict(snow._pile[edge] == 30.0, "and not the snow far from it (%.0f)" % snow._pile[edge])
	print("blizzard melts" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _wait(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await get_tree().physics_frame


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

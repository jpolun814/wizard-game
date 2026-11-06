extends Node

## What falls from the sky goes through the leaves of a jungle's great trees: a Spark's bolt lands on the ground under a tree's ledges, not on them, and a
## boulder dropped over them falls to the ground. The ledges still hold a wizard (they are platforms): only the sky spells pass.
##
##     godot --headless --fixed-fps 60 --path . tests/canopy_check.tscn
## It prints PASS or FAIL and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 0  # a jungle first
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var leaves := get_tree().get_nodes_in_group("canopy")
	_check(not leaves.is_empty(), "the jungle has great trees with ledges (%d)" % leaves.size())
	if leaves.is_empty():
		get_tree().quit(1)
		return
	var tree: StaticBody2D = leaves[0]
	var plank: CollisionShape2D = tree.get_child(0)
	var over: Vector2 = plank.global_position
	var high := over + Vector2(0.0, -300.0)
	var ledge := SpellTargets.ground_below(world.get_world_2d(), high, 4000.0)
	var through := SpellTargets.ground_below(world.get_world_2d(), high, 4000.0, true)
	_check(ledge.y < through.y - 20.0, "a plain look down meets the ledge (y %.0f), a bolt's passes it (y %.0f)" % [ledge.y, through.y])
	var boulder := Boulder.new()
	world.add_child(boulder)
	boulder.global_position = high
	for k in 240:
		await get_tree().physics_frame
	_check(boulder.global_position.y > over.y + 20.0, "a boulder dropped over the ledge falls past it (rests at y %.0f, ledge at y %.0f)" % [boulder.global_position.y, over.y])
	print("the sky goes through the leaves" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

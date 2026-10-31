extends Node

## A Sinkhole opens in the waiting room too, where the ground is one line of heights rather than tiles of rock.
##
##     godot --headless --fixed-fps 60 --path . tests/lab_sinkhole_check.tscn
## It prints PASS or FAIL and exits with code 1 if the ground did not sink.


func _ready() -> void:
	var lab: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame
	var space: World2D = lab.get_world_2d()
	var player: Wizard = lab.player
	var spot := SpellTargets.solid_below(space, player.global_position + Vector2(260.0, -200.0))
	var before := SpellTargets.solid_below(space, spot + Vector2(0.0, -100.0)).y
	lab.spawn_spell("Sinkhole", "positional", spot + Vector2(0.0, -20.0), 0.0, {}, player)
	for k in int(Sinkhole.WARNING * 60.0) + 20:
		await get_tree().physics_frame
	var after := SpellTargets.solid_below(space, spot + Vector2(0.0, -100.0)).y
	var ok := after > before + 60.0
	print("%s  the waiting room's ground sinks under a Sinkhole (%.0f px)" % ["PASS" if ok else "FAIL", after - before])
	get_tree().quit(0 if ok else 1)

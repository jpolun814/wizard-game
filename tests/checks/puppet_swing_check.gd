extends Node

## A skeleton that is a puppet (on a machine that is not the host's) draws its sword when the host's does.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/puppet_swing_check.tscn

func _ready() -> void:
	var mob: Mob = load("res://scenes/mob.tscn").instantiate()
	mob.kind = "basic"
	mob.puppet = true
	mob.roams = true
	add_child(mob)
	mob.set_physics_process(true)
	await get_tree().process_frame
	mob.net_position = mob.global_position
	mob.net_swing = true
	var drew := false
	for k in 20:
		await get_tree().physics_frame
		await get_tree().process_frame
		drew = drew or mob._visual.animation == "attack"
	print("%s  a puppet draws its sword when the host's does" % ("PASS" if drew else "FAIL"))
	get_tree().quit(0 if drew else 1)

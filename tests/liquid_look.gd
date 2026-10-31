extends Node

## Pictures of the waiting room's pond as a pit is dug beside it and the water flows in, and a check that it does.
##
##     godot --fixed-fps 60 --path . tests/liquid_look.tscn -- out=DIR     (needs a window, for the pictures)

var _failures := 0


func _ready() -> void:
	var out := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			out = argument.trim_prefix("out=")
	var lab: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame
	var pond: Pond = null
	for each: Pond in get_tree().get_nodes_in_group("ponds"):
		if not each.lava:
			pond = each
	var player: Wizard = lab.player
	player.global_position = pond.global_position + Vector2(pond.width + 260.0, -40.0)
	player.velocity = Vector2.ZERO
	for k in 40:
		await get_tree().physics_frame
	pond.ensure_grid()
	var level_before := pond.surface_at(pond.global_position.x + pond.width - 60.0)
	await _picture(out, "0_before")
	lab._ground.dig(Vector2(pond.global_position.x + pond.width + 40.0, pond.global_position.y + 2.0), 80.0, 96.0)
	for k in 45:
		await get_tree().physics_frame
	await _picture(out, "1_pouring")
	for k in 240:
		await get_tree().physics_frame
	await _picture(out, "2_settling")
	for k in 600:
		await get_tree().physics_frame
	await _picture(out, "3_settled")
	var level_after := pond.surface_at(pond.global_position.x + pond.width - 60.0)
	_verdict(pond.grid.wet_at(Vector2(pond.global_position.x + pond.width + 40.0, pond.global_position.y + 80.0)), "the water has flowed into the pit")
	_verdict(level_after > level_before + 6.0, "and the pond's surface has dropped (%.0f to %.0f)" % [level_before, level_after])
	get_tree().quit(1 if _failures > 0 else 0)


func _picture(out: String, name: String) -> void:
	if out == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/liquid_%s.png" % [out, name])


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

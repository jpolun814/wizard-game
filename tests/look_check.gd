extends Node

## Pictures of a few spells in the waiting room, at the moments that matter, for looking at (needs a window):
##
##     godot --fixed-fps 60 --path . tests/look_check.tscn -- out=DIR
## It saves smoke.png (a Smoke Screen once it has thickened, with a rival behind it), ice.png (an Ice Prison round a skeleton and one round
## the wizard), sinkhole.png (a pit drawn as a deep, narrow U), stalagmite.png, wall.png and eclipse.png.

var _out := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.substr(4)
	var lab: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 20:
		await get_tree().process_frame
	var player: Wizard = get_tree().get_first_node_in_group("player")
	player.max_stamina = 9999.0
	player.stamina = 9999.0
	var pond: Pond = get_tree().get_nodes_in_group("ponds")[0]
	var ground := SpellTargets.solid_below(lab.get_world_2d(), Vector2(pond.global_position.x + pond.width + 230.0, 100.0))
	player.global_position = ground + Vector2(-200.0, -40.0)
	for k in 30:
		await get_tree().physics_frame
	var feet := player.global_position

	var smoke := SmokeScreen.new()  # a Smoke Screen a little way ahead, thick
	smoke.line = PackedVector2Array([feet + Vector2(120.0, 20.0), feet + Vector2(110.0, -50.0), feet + Vector2(124.0, -120.0), feet + Vector2(112.0, -190.0)])
	lab.add_child(smoke)
	for k in 360:
		await get_tree().physics_frame
	await _snap("smoke")

	var prison := IcePrison.new()  # an Ice Prison drawn round the wizard
	prison.rect = Rect2(feet + Vector2(-60.0, -100.0), Vector2(120.0, 130.0))
	lab.add_child(prison)
	for k in 30:
		await get_tree().physics_frame
	for k in 40:
		await get_tree().physics_frame
	await _snap("ice")
	for k in 400:
		await get_tree().physics_frame

	var hole := PackedVector2Array()  # a deep, narrow U, then a wide shallow one
	for k in 17:
		var a := PI * k / 16.0
		hole.append(Vector2(ground.x + cos(a) * 45.0, ground.y - 85.0 + sin(a) * 80.0))
	var pit := Sinkhole.new()
	pit.ground = lab._ground
	pit.half_width = 60.0
	pit.depth = 110.0
	pit.profile = Sinkhole.profile_of(hole, 17)
	pit.global_position = ground
	lab.add_child(pit)
	for k in 150:
		await get_tree().physics_frame
	await _snap("sinkhole")

	var peak := PackedVector2Array([Vector2(ground.x - 30.0, ground.y), Vector2(ground.x, ground.y - 90.0), Vector2(ground.x + 30.0, ground.y)])
	lab.spawner.shapes.place("Stalagmite", {"shapes": [peak], "line": peak})
	await get_tree().create_timer(0.8).timeout
	await _snap("stalagmite")
	Flames.lay(lab, Rect2(ground.x - 70.0, ground.y - 110.0, 60.0, 110.0), 5, 55.0)  # a burning plant
	Flames.lay(lab, Rect2(ground.x + 20.0, ground.y - 6.0, 120.0, 12.0), 9, 18.0, 1.3)  # burning ground
	var drift := SnowDrift.new()
	drift.position = Vector2(ground.x + 190.0, ground.y)
	lab.add_child(drift)
	for k in 300:
		await get_tree().physics_frame
	await _snap("fire")
	get_tree().quit()


func _snap(name: String) -> void:
	await get_tree().process_frame
	if _out != "" and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(_out)
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])

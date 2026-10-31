extends Node

## Pictures of the Hex, the Fight or Flight mark and the Moonbeam, cast in the waiting room, to judge how they look.
##
##     godot --path . tests/marks_look.tscn -- out=DIR     (needs a window)

var out_dir := "user://marks_look"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out_dir = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var lab: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 30:
		await get_tree().process_frame
	var player: Wizard = get_tree().get_first_node_in_group("player")
	var feet := player.global_position
	var beam := Moonbeam.new()
	beam.position = SpellTargets.solid_below(lab.get_world_2d(), feet + Vector2(140.0, -60.0)) + Vector2(0.0, -4.0)
	lab.add_child(beam)
	var hex := Hex.new()
	hex.target = player
	lab.add_child(hex)
	await get_tree().create_timer(1.5).timeout
	_shot("hex_moonbeam")
	hex.queue_free()
	for fights in [true, false]:
		var spell := FightOrFlight.new()
		spell.target = player
		lab.add_child(spell)
		spell.fights = fights
		spell._mark.modulate = FightOrFlight.FIGHT if fights else FightOrFlight.FLIGHT
		await get_tree().create_timer(0.4).timeout
		_shot("fight" if fights else "flight")
		spell.queue_free()
		await get_tree().create_timer(0.2).timeout
	get_tree().quit()


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])

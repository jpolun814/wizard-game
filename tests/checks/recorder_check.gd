extends Node

## The match recorder writes a world: every wizard, the person's keys and hands, a cast, a blow and the things in the world, and closes the file at the end.

func _ready() -> void:
	var dir := "user://recorder_check_logs"
	MatchRecorder.force = true
	MatchRecorder.folder = dir
	seed(5)
	World.next_seed = 5
	var world: Node = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().create_timer(2.0).timeout
	var recorder: MatchRecorder = world.get_node_or_null("MatchRecorder")
	var ok := recorder != null and recorder._file != null
	var path := recorder._path if recorder != null else ""
	if ok:
		var d := InputEventKey.new()
		d.physical_keycode = KEY_D
		d.keycode = KEY_D
		d.pressed = true
		recorder._input(d)
		world.player.stamina = 150.0
		MatchStats.strike(world.player)
		world.player.take_damage(3)
		world.player.daze_time = 2.0
		world.caster.cast_resolved.emit("Ignite", "directional", world.player.center(), 0.0, {})
		world.ritual.finished.emit("minimap", 0.9, false)
		await get_tree().create_timer(0.6).timeout
		MatchRecorder.finish(get_tree())
	var text := FileAccess.get_file_as_string(path) if path != "" else ""
	ok = ok and text.contains("HEAD seed") and text.contains(" WZ ") and text.contains(" S ") and text.contains(" M ") and text.contains(" A ") and text.contains("K key D down") \
		and text.contains(" HIT ") and text.contains(" OB ") and text.contains("END") and text.contains(" CAST %d Ignite" % world.player.get_instance_id()) and text.contains(" ST %d dazed" % world.player.get_instance_id()) and text.contains(" SAY ") and text.contains("TERR ") and text.contains(" TR ") and recorder._file == null
	if not ok:
		print("log was: ", text.substr(0, 500))
	DirAccess.remove_absolute(path)
	print("PASS the match recorder writes wizards, hands, blows and the world" if ok else "FAIL match recorder")
	get_tree().quit()

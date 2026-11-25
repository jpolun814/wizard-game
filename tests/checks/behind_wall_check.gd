extends Node

## An AI wizard whose rival has stepped behind a wall of stone does not stop fighting: it has lost sight of them but remembers where they stood, and it goes on casting
## at the place (a spell that comes down from above or is lobbed over), as a person would, for as long as it remembers. And a wall too tall to jump is not run at for good:
## it raises itself over it with a spell it holds (a rocket's flame, a column of air, a geyser).
##
##     godot --headless --fixed-fps 60 --path . tests/checks/behind_wall_check.tscn

func _ready() -> void:
	Library.use_file("user://behind_wall_check.json")
	Library.clear()
	var lab: Lab = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 30:
		await get_tree().process_frame
	lab._levels.set_level(7)
	var partner: Wizard = lab._partner
	var floor_y := partner.global_position.y
	# A tall wall of stone between the two, on the court.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40.0, 230.0)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = Vector2(ArenaGen.column_x(-20), floor_y - 115.0)
	lab.add_child(wall)
	partner.global_position = Vector2(ArenaGen.column_x(-25), floor_y)
	lab.player.global_position = Vector2(ArenaGen.column_x(-16), floor_y)
	partner.brain.rng.seed = 4242  # (the same dice every time: the check proves the idea, not the luck)
	Dice.reset(4242)
	var spent := 0.0
	var last := partner.stamina
	var casts := 0
	for k in 2400:
		await get_tree().process_frame
		lab.player.global_position = Vector2(ArenaGen.column_x(-16), floor_y)  # (they stand where they are)
		if is_instance_valid(lab._partner) and lab._partner == partner:
			if partner.stamina < last - 3.0:
				casts += 1
			last = partner.stamina
	var over: bool = is_instance_valid(lab._partner) and lab._partner.global_position.x > wall.position.x
	var ok := casts >= 2 and over
	print("%s  it went on casting with a wall between (%d casts in 20 seconds)" % ["PASS" if casts >= 2 else "FAIL", casts])
	print("%s  and got over a wall too tall to jump" % ["PASS" if over else "FAIL"])
	Library.clear()
	get_tree().quit(0 if ok else 1)

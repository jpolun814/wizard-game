extends Node

## A brain that stands in one place does not turn left and right on it every frame (it once did, when two wishes, to keep its range and to get under a roof,
## pulled it opposite ways): a sparring partner left to fight a person standing still turns round only now and then, at a low level and at a high one.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/dither_check.tscn

const MOST_TURNS := 60   # in 20 seconds

var watched := 0  # the frames it was seen standing


func _ready() -> void:
	Library.use_file("user://dither_check.json")
	Library.clear()
	var failed := false
	for level in [3, 9]:
		var turns := await _turns_at(level)
		var ok := turns <= MOST_TURNS and watched > 600  # (standing for most of the twenty seconds)
		print("%s  level %d turned round %d times in 20 seconds (at most %d)" % ["PASS" if ok else "FAIL", level, turns, MOST_TURNS])
		failed = failed or not ok
	Library.clear()
	get_tree().quit(1 if failed else 0)


func _turns_at(level: int) -> int:
	var lab: Lab = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 30:
		await get_tree().process_frame
	lab._levels.set_level(level)
	var partner: Wizard = lab._partner
	lab.player.global_position = Vector2(ArenaGen.column_x(Lab.SPAR_COL + 8), partner.global_position.y)
	var turns := 0
	watched = 0
	var last := 0.0
	for k in 1200:
		await get_tree().process_frame
		if not is_instance_valid(lab._partner) or lab._partner.dead:
			last = 0.0  # (beaten, by a spell of its own it may be: the room makes another in a moment)
			continue
		watched += 1
		var walk: float = lab._partner.pad.walk
		if absf(walk) > 1.0:
			if last != 0.0 and signf(walk) != signf(last):
				turns += 1
			last = walk
	lab.queue_free()
	await get_tree().process_frame
	return turns

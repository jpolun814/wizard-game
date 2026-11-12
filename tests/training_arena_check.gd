extends Node

## The training arena (training/training_arena.tscn), without a trainer: duels are fought in every lane, both stand up again for the next bout, nobody
## leaves their lane, and nobody sees into another lane. Played at a few times the speed.
##
##     godot --headless --fixed-fps 60 --path . tests/training_arena_check.tscn

const SECONDS := 150.0

var _failed := 0


func _ready() -> void:
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 240
	var arena: TrainingArena = load("res://training/training_arena.tscn").instantiate()
	add_child(arena)
	for k in 10:
		await get_tree().physics_frame
	var pairs: Array = arena._pairs
	_verdict(pairs.size() == TrainingArena.lanes, "a duel in every lane (%d)" % pairs.size())
	await _leaves_nothing(arena, pairs[0])
	var bouts := {}
	var strayed := 0
	var peeked := 0
	var began := Time.get_ticks_msec()
	var clock := 0.0
	while clock < SECONDS:
		await get_tree().physics_frame
		clock += 1.0 / 60.0
		for pair: Dictionary in pairs:
			var agent: TacticsAgent = pair["agent"]
			if agent.done:
				agent.set_done_false()  # (what the trainer does when it has read the end of a life)
			bouts[pair["lane"]] = pair["bouts"] - 1  # (the bouts begun since the first)
			var left := (arena._lane_left(pair["lane"]) - 1) * ArenaGen.TILE  # (the walls' own columns: a wizard may stand against one)
			var right := (arena._lane_left(pair["lane"]) + TrainingArena.LANE_COLS + 1) * ArenaGen.TILE
			for wizard: Wizard in [pair["learner"], pair["opponent"]]:
				if not wizard.dead and (wizard.global_position.x < left or wizard.global_position.x > right):
					if strayed == 0:
						print("  strayed: lane %d at %s (lane from %.0f to %.0f)" % [pair["lane"], wizard.global_position, left, right])
					strayed += 1
			if Engine.get_physics_frames() % 30 == 0:
				var learner: Wizard = pair["learner"]
				for other: Wizard in SpellTargets.wizards(get_tree()):
					if other != learner and other != pair["opponent"] and learner.eyes.sees_wizard(other):
						if peeked == 0:
							print("  peeked: lane %d at %s sees %s at %s" % [pair["lane"], learner.global_position, other.name, other.global_position])
						peeked += 1
	var least := 1000
	for pair: Dictionary in pairs:
		least = mini(least, bouts.get(pair["lane"], 0))
	print("  bouts by lane %s in %.0f s of play (%.0f s of real time)" % [str(bouts), SECONDS, (Time.get_ticks_msec() - began) / 1000.0])
	_verdict(least >= 2, "bouts end and begin again in every lane (at least %d each)" % least)
	_verdict(strayed == 0, "nobody leaves their lane (%d)" % strayed)
	_verdict(peeked == 0, "nobody sees into another lane (%d)" % peeked)
	print("TRAINING ARENA %s" % ("PASS" if _failed == 0 else "FAILED %d" % _failed))
	get_tree().quit(1 if _failed > 0 else 0)


## What a bout leaves in its lane (here a creature and a pit) is gone when the next begins, and two new wizards stand there.
func _leaves_nothing(arena: TrainingArena, pair: Dictionary) -> void:
	var middle := ArenaGen.column_x(arena._lane_left(pair["lane"]) + TrainingArena.LANE_COLS / 2)
	var left_behind := arena._add_mob("fire_melee", Vector2(middle, ArenaGen.GROUND_Y))
	var under := Vector2(middle + 150.0, ArenaGen.GROUND_Y + 40.0)
	var dug := arena._ground.dig(Vector2(under.x, ArenaGen.GROUND_Y), 60.0, 90.0)
	await get_tree().physics_frame
	var hole := not arena._ground.solid_at(under) and not _solid_ray(arena, under)
	var learner: Wizard = pair["learner"]
	var prison := IcePrison.new()  # (round the learner, who is taken away with the bout: the ice must not go on asking after a body that is gone)
	prison.rect = Rect2(learner.center() - Vector2(40.0, 50.0), Vector2(80.0, 100.0))
	arena.add_child(prison)
	await get_tree().physics_frame
	_verdict(is_instance_valid(prison) and learner.is_frozen(), "an Ice Prison holds the learner")
	var agent: TacticsAgent = pair["agent"]
	var bouts: int = pair["bouts"]
	agent.end_bout()
	agent.set_done_false()  # (what the trainer does when it has read the end of a life)
	for k in 240:
		await get_tree().physics_frame
		if pair["bouts"] > bouts:
			break
	_verdict(dug and hole, "a pit can be dug in a lane (%s, %s)" % [dug, hole])
	for k in 150:
		await get_tree().physics_frame  # (the ice thaws away by itself, a moment after its body is gone)
	_verdict(not is_instance_valid(left_behind), "what the last bout left in the lane is gone")
	_verdict(not is_instance_valid(prison), "an Ice Prison round a wizard who is taken away goes too")
	_verdict(_solid_ray(arena, under), "the pit is filled again")
	_verdict(pair["learner"] != learner and not is_instance_valid(learner) and agent.get_parent() == pair["learner"], "two new wizards stand up, and the learner's agent is in the new one")


func _solid_ray(arena: TrainingArena, point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 1
	return not arena.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


func _verdict(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok    " if ok else "FAILED", what])
	if not ok:
		_failed += 1

extends Node

## The hand (HandBrain): a wizard played only through a person's controls. In the duel arena with dummies for opponents, the keys walk and jump the
## learner, a Fireball cast through the hand at the other wizard hits them, a spell not in the book cannot be chosen, nor any while a stroke is being
## drawn, and the senses and the mask are the size the trainer expects.
##
##     godot --headless --fixed-fps 60 --path . tests/hand_check.tscn -- --opponent=dummy --lanes=1 --near=1

var _failed := 0


func _ready() -> void:
	var arena: DuelArena = load("res://training/duel_arena.tscn").instantiate()
	add_child(arena)
	for k in 20:
		await get_tree().physics_frame
	var pair: Dictionary = arena._pairs[0]
	var me: Wizard = pair["learner"]
	var other: Wizard = pair["opponent"]
	var hand := me.brain as HandBrain
	var middle := ArenaGen.column_x(arena._lane_left(0) + TrainingArena.LANE_COLS / 2)
	me.global_position = Vector2(middle - 200.0, ArenaGen.GROUND_Y - 2.0)
	other.global_position = Vector2(middle + 400.0, ArenaGen.GROUND_Y - 2.0)
	for k in 30:
		await get_tree().physics_frame
	_verdict(hand != null and other.brain is HandBrain and (other.brain as HandBrain).policy == null, "both are played by hands; the opponent is a dummy")
	_verdict(hand.observe().size() == HandBrain.SIZE, "the senses and the mask: %d numbers" % hand.observe().size())
	var sorted_heads: Array = HandBrain.HEADS.keys().duplicate()
	sorted_heads.sort()
	_verdict(HandBrain.HEADS.keys() == sorted_heads, "the choices are in the order of their names, as the trainer sorts them")
	var ignite := Senses.SPELL_ORDER.find("Ignite")
	var mask := hand.mask()
	var cast_from := HandBrain.CAST_AT
	_verdict(mask[cast_from] == 1.0 and mask[cast_from + 1 + ignite] == 1.0, "nothing and Fireball can be chosen")
	_verdict(mask[cast_from + 1 + Senses.SPELL_ORDER.find("Frostbolt")] == 0.0, "a spell not in the book cannot")
	# Keys.
	var x0 := me.global_position.x
	await _press(hand, 2, 0, 0, 30)
	var right := me.global_position.x - x0
	x0 = me.global_position.x
	await _press(hand, 1, 0, 0, 30)
	var left := x0 - me.global_position.x
	_verdict(right > 60.0 and left > 60.0 and me.facing < 0.0, "the keys walk it right (%.0f px) and left (%.0f px), and it faces the way it goes" % [right, left])
	await _press(hand, 0, 1, 0, 1)
	var rose := false
	for k in 30:
		await get_tree().physics_frame
		rose = rose or not me.is_on_floor()
	_verdict(rose, "the jump key jumps")
	for k in 60:
		await get_tree().physics_frame
	# A Fireball at the other wizard.
	other.global_position = me.global_position + Vector2(260.0, 0.0)
	other.velocity = Vector2.ZERO
	await get_tree().physics_frame
	var before := other.max_stamina
	hand.aim = hand.cell_of(other.center())
	hand.cast = 1 + ignite
	hand.move = 0
	hand.jump = 0
	hand.fresh = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	_verdict(me.is_drawing() and hand.mask()[cast_from + 1 + ignite] == 0.0, "the hand draws, and while it draws no spell can be chosen")
	for k in 120:
		await get_tree().physics_frame
	_verdict(other.max_stamina < before, "a Fireball cast through the hand at the other wizard hits them (%.0f to %.0f)" % [before, other.max_stamina])
	var agent: HandAgent = pair["agent"]
	_verdict(agent.near_scale == 1.0 and agent.cause["near"] > 0.0, "the shot is paid for coming near (%.2f)" % agent.cause["near"])
	me.stamina = 2.0
	hand.cast = 1 + ignite
	hand.fresh = true
	for k in 90:
		await get_tree().physics_frame
	_verdict(agent.cause["tired"] < 0.0, "a stroke too tired to pay for costs the learner a little (%.2f)" % agent.cause["tired"])
	print("HAND %s" % ("PASS" if _failed == 0 else "FAILED %d" % _failed))
	get_tree().quit(1 if _failed > 0 else 0)


func _press(hand: HandBrain, move: int, jump: int, cast: int, frames: int) -> void:
	hand.move = move
	hand.jump = jump
	hand.cast = cast
	hand.fresh = true
	for k in frames:
		await get_tree().physics_frame


func _verdict(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok    " if ok else "FAILED", what])
	if not ok:
		_failed += 1

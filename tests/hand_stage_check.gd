extends Node

## The hand (HandBrain) casts each spell of stage 2 of the curriculum (training/duel_arena.gd STAGES): a Frostbolt at the other wizard hits them, a
## Barrier wraps the caster, and a Stone Wall aimed at a point on the ground rises there (its stroke begun on the ground, as a person draws it). None
## of them misfires, and each is counted by spell for the trainer (HandAgent.get_info).
##
##     godot --headless --fixed-fps 60 --path . tests/hand_stage_check.tscn -- --stage=2 --opponent=dummy --lanes=1

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
	var agent: HandAgent = pair["agent"]
	var misfires := [0]
	me.caster.misfired.connect(func() -> void: misfires[0] += 1)
	var middle := ArenaGen.column_x(arena._lane_left(0) + TrainingArena.LANE_COLS / 2)
	me.global_position = Vector2(middle - 200.0, ArenaGen.GROUND_Y - 2.0)
	other.global_position = Vector2(middle + 60.0, ArenaGen.GROUND_Y - 2.0)
	me.facing = 1.0
	for k in 30:
		await get_tree().physics_frame
	for spell: String in ["Ignite", "Frostbolt", "Barrier", "Stone Wall"]:
		_verdict(me.ledger.knows_spell(spell) and hand.can_cast(Senses.SPELL_ORDER.find(spell)), "stage 2's book holds %s, and the hand can cast it" % spell)
	# A Frostbolt at the other wizard.
	var before := other.max_stamina
	await _cast(me, hand, "Frostbolt", other.center(), 120)
	_verdict(other.max_stamina < before, "a Frostbolt cast through the hand at the other wizard hits them (%.0f to %.0f)" % [before, other.max_stamina])
	# A Barrier: it wraps the caster, wherever the circle is drawn.
	await _cast(me, hand, "Barrier", me.center() + Vector2(120.0, -60.0), 40)
	_verdict(me.has_shield(), "a Barrier cast through the hand wraps the caster")
	# A Stone Wall aimed at a point in the air over the ground rises from the ground below it.
	var target := Vector2(me.global_position.x + 130.0, ArenaGen.GROUND_Y - 70.0)
	var walls_before := get_tree().get_nodes_in_group("walls").size()
	await _cast(me, hand, "Stone Wall", target, 60)
	var risen: Node2D = null
	for wall: Node in get_tree().get_nodes_in_group("walls"):
		if wall is Node2D and absf((wall as Node2D).global_position.x - target.x) < 80.0:
			risen = wall
	_verdict(get_tree().get_nodes_in_group("walls").size() > walls_before and risen != null,
		"a Stone Wall aimed at a point over the ground rises from the ground below it (%s)" % ("at x %.0f, aimed at %.0f" % [risen.global_position.x, target.x] if risen != null else "none"))
	_verdict(misfires[0] == 0, "none of the strokes misfired (%d)" % misfires[0])
	var info := agent.get_info()
	_verdict(int(info.get("cast Frostbolt", 0)) == 1 and int(info.get("cast Barrier", 0)) == 1 and int(info.get("cast Stone Wall", 0)) == 1,
		"each cast is counted by spell for the trainer (%s)" % str(agent.spells_cast))
	print("HAND STAGE %s" % ("PASS" if _failed == 0 else "FAILED %d" % _failed))
	get_tree().quit(1 if _failed > 0 else 0)


func _cast(me: Wizard, hand: HandBrain, spell: String, point: Vector2, frames: int) -> void:
	me.stamina = me.max_stamina
	hand.aim = hand.cell_of(point)
	hand.cast = 1 + Senses.SPELL_ORDER.find(spell)
	hand.move = 0
	hand.jump = 0
	hand.fresh = true
	for k in 30:  # (until the hand has read the choice and begun the stroke)
		await get_tree().physics_frame
		if me.is_drawing():
			break
	hand.cast = 0
	for k in frames:
		await get_tree().physics_frame
	while me.is_drawing():
		await get_tree().physics_frame


func _verdict(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok    " if ok else "FAILED", what])
	if not ok:
		_failed += 1

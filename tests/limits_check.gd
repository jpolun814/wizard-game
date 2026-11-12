extends Node

## The limits of a person's body and screen, which a brain's wizard is held to as well (docs/handoff/18_human_limits_ai_plan.md):
## - it sees only its own screen, and no one faded from sight by Sneak (the person at this machine included), unless a hex's star is over them;
## - a Decoy it did not see come out of nothing is taken for its caster;
## - a stroke must lie on its screen, only one is drawn at a time, none while a chant is typed;
## - the view follows the wizard, so a stroke drawn on the move is dragged: a click held still while walking draws a line.
##
##     godot --headless --fixed-fps 60 --path . tests/limits_check.tscn

var _failures := 0


## A brain that only walks, at a set speed: for the stroke a moving wizard draws.
class Walker extends WizardBrain:
	var speed := 0.0

	func think(_delta: float) -> void:
		wizard.walk(speed)


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 8
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var me: Wizard = world.player
	var rivals: Array[Wizard] = []
	for found: Wizard in get_tree().get_nodes_in_group("wizards"):
		if found != me:
			rivals.append(found)
	var looker := rivals[0]
	var other := rivals[1]
	for k in range(2, rivals.size()):
		rivals[k].set_physics_process(false)
		rivals[k].global_position = Vector2(-9000.0, -9000.0 - k * 100.0)
	other.set_physics_process(false)
	var brain: WizardBrain = looker.brain
	looker.ledger = Ledger.of([])  # a bare book: no Hunter's Mark or eye to find the hidden by, nothing of its own to cast
	await _settle()

	# Sight: its own screen, and nothing past it.
	me.set_physics_process(false)
	me.global_position = looker.global_position + Vector2(200.0, 0.0)
	await _frames(3)
	_verdict(brain.eyes_see(me), "a brain sees a person standing near it, on its screen")
	me.global_position = looker.global_position + Vector2(Eyes.HALF.x + 150.0, 0.0)
	await _frames(3)
	_verdict(not brain.eyes_see(me), "but not one past the edge of its screen")
	# Sneak hides the person at this machine too (it once did not).
	me.global_position = looker.global_position + Vector2(200.0, 0.0)
	me.fade_from_sight(20.0)
	await _frames(3)
	_verdict(not brain.eyes_see(me), "a person who has cast Sneak is not seen by a brain")
	var last_seen: Vector2 = brain._known[me.get_instance_id()]["at"] if brain._known.has(me.get_instance_id()) else Vector2.INF
	me.global_position = looker.global_position + Vector2(-Eyes.HALF.x - 400.0, 0.0)  # they slip away unseen, out of its sight (and out of bumping reach)
	await _frames(30)
	var thought: Vector2 = brain._seen_feet(me)
	_verdict(thought.distance_to(last_seen) < 2.0, "it thinks them where it last saw them, not where they went (%s)" % (thought - last_seen))
	await _frames(int((WizardBrain.REMEMBER + 0.5) * 60.0))
	_verdict(not brain._known.has(me.get_instance_id()), "and after a while forgets them")
	me.global_position = looker.global_position + Vector2(200.0, 0.0)  # back on its screen, still faded
	await _frames(3)
	_verdict(not brain.eyes_see(me), "(still unseen on its screen)")
	var hex := Hex.new()
	hex.target = me
	world.add_child(hex)
	await _frames(3)
	_verdict(brain.eyes_see(me), "but a hexed one is: the dark star floats over them")
	hex.queue_free()
	me.break_sneak()
	await _frames(3)

	# Strokes: on the screen, one at a time, never while typing.
	me.global_position = Vector2(-9000.0, -7000.0)
	looker.brain = Walker.new(looker)  # (its own brain would be about its own business: a chant, a spell of its own)
	looker.interrupt_cast()
	await _frames(20)
	var near := _dot(looker.center() + Vector2(40.0, -20.0))
	var far := _dot(looker.center() + Vector2(Eyes.HALF.x + 200.0, 0.0))
	_verdict(not looker.start_drawing(far, Color.WHITE, func(_p: PackedVector2Array) -> void: pass, 0.5), "a stroke off the edge of its screen cannot be begun")
	_verdict(looker.start_drawing(near, Color.WHITE, func(_p: PackedVector2Array) -> void: pass, 0.5), "one on its screen can")
	_verdict(not looker.start_drawing(near, Color.WHITE, func(_p: PackedVector2Array) -> void: pass, 0.5), "but not a second while the first is drawn")
	looker.interrupt_cast()
	looker.brain = brain
	brain._open_chant("haste")
	_verdict(brain.is_typing() and not looker.start_drawing(near, Color.WHITE, func(_p: PackedVector2Array) -> void: pass, 0.5), "nor while a chant is being typed")
	_verdict(not brain._begin_cast("Ignite", near, 0.5) and not brain.is_typing(), "a brain that wants to draw closes the chant box first, and the words are lost")

	# The view drags a stroke: a click held still while the wizard walks draws a line, as it does for a person.
	var walker := Walker.new(looker)
	looker.brain = walker
	walker.speed = Wizard.SPEED
	await _frames(40)  # it is walking, and the view has caught up with it
	var drawn := [PackedVector2Array()]
	var spot := looker.center() + Vector2(0.0, -40.0)
	looker.start_drawing(_dot(spot, 40), Color.WHITE, func(p: PackedVector2Array) -> void: drawn[0] = p, 0.6)
	await _frames(45)
	var span := GestureTemplates.bounds(drawn[0]).size.x if drawn[0].size() > 1 else 0.0
	_verdict(span > 100.0, "a click held still while walking draws a line (%.0f px long)" % span)
	walker.speed = 0.0
	await _frames(40)
	drawn[0] = PackedVector2Array()
	looker.start_drawing(_dot(looker.center() + Vector2(0.0, -40.0), 40), Color.WHITE, func(p: PackedVector2Array) -> void: drawn[0] = p, 0.6)
	await _frames(45)
	span = GestureTemplates.bounds(drawn[0]).size.x if drawn[0].size() > 1 else -1.0
	_verdict(span >= 0.0 and span < 4.0, "and standing still, a point (%.0f px)" % span)
	looker.brain = brain

	# A Decoy: taken for its caster unless it was seen coming.
	me.global_position = Vector2(-9000.0, -7000.0)  # (out of the way: the nearest figure it sees is the one it deals with)
	me.fade_time = 100.0  # (and out of sight, should the world put them back on its ground: a person put back beside it would be nearer than the shadow)
	other.global_position = Vector2(-9000.0, -8000.0)
	var shadow := Decoy.new()
	shadow.caster = other
	shadow.position = Vector2(-9000.0, -8500.0)  # conjured out of its sight
	world.add_child(shadow)
	await _frames(40)
	shadow.global_position = looker.global_position + Vector2(220.0, 0.0)
	await _frames(10)
	_verdict(brain._lure == shadow and brain._foe == other, "a shadow it did not see conjured is taken for its caster")
	shadow.queue_free()
	await _frames(3)
	var seen := Decoy.new()
	seen.caster = other
	seen.position = looker.global_position + Vector2(220.0, 0.0)  # conjured before its eyes
	world.add_child(seen)
	await _frames(10)
	_verdict(brain._lure != seen, "one it watched come out of nothing is known for a shadow")
	seen.queue_free()
	me.fade_time = 0.0

	# A page just read is looked at before its spell is drawn.
	looker.ledger.learn("Ignite")
	await _frames(2)
	_verdict(not brain._ready_to_cast("Ignite"), "a spell whose page was just read is not drawn at once")
	await _frames(int(WizardBrain.READ_MAX * 60.0) + 5)
	_verdict(brain._ready_to_cast("Ignite"), "but is once the page has been looked at")

	_verdict(TacticsBrain.ATTACKS.size() == TacticsBrain.ATTACK_COUNT and TacticsBrain.ATTACKS.all(func(n: String) -> bool: return SpellData.SPELLS.has(n)),
		"the learned tactics' list of attacks is whole and names real spells")

	print("a brain is held to a person's limits" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## A stroke that does not move: the mouse held still, a button down.
func _dot(at: Vector2, count := 2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in count:
		out.append(at)
	return out


func _settle() -> void:
	await _frames(30)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _verdict(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1

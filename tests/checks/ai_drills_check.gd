extends Node

## Situation drills for the AI wizards: one small, controlled scene for each thing a person with some sense does, and a count of how often the AI does it.
## Each drill is run with the idea on and with it off (AI_OFF=name), so a pass means the idea makes the difference, not that the AI happened to do it.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/ai_drills_check.tscn
##     (a name after `--` runs only that drill, e.g. `-- read_stonefall`)

const TRIALS := 16

var _lab: Lab
var _failed := false
var _trial_no := 0
var _floor := 0.0  # the court's floor, noted before any drill moves the partner
var _color := Color.WHITE  # the trail's color: the arena colors a person's own trail by the buttons held, so a drill puts its school's back


func _ready() -> void:
	Library.use_file("user://ai_drills_check.json")
	Library.clear()
	_lab = load("res://scenes/lab.tscn").instantiate()
	add_child(_lab)
	for k in 30:
		await get_tree().process_frame
	_lab._levels.set_level(8)
	_lab.hold_partner = true  # (the room would put it back in its place whenever the player is out of the court)
	_floor = _lab._partner.global_position.y
	var only := OS.get_cmdline_user_args()
	for drill: Array in _drills():
		if only.is_empty() or drill[0] in only:
			await _run(drill)
	Library.clear()
	get_tree().quit(1 if _failed else 0)


## [name, what it is, the change that is switched off for the control, a Callable that plays one trial and returns a number, and the change that must show: a share
## less than the control (a negative number) or a number more (a positive one)]
func _drills() -> Array:
	return [
		["read_stonefall", "steps out from under a boulder it saw drawn", "read", _trial_stonefall, 0.5],
		["push_off_ledge", "chooses a shove for a rival standing at a ledge", "terrain", _trial_ledge, 0.3],
		["beyond_barrier", "casts what is not thrown at a rival behind a Barrier", "shield", _trial_shield, 0.3],
		["barrier_habit", "leans on what is not thrown at a rival it has seen raise a Barrier", "shield", _trial_habit, 0.15],
		["kit_pages", "goes for a page of a school it lacks over an equal one of a school it has", "kit", _trial_kit, 0.5],
		["brace_chant", "says the chant that fills its strength once a rival has been shooting at it and is not yet on it", "brace", _trial_brace, 0.5],
		["rocket_away", "lifts itself clear with a rocket of flame when a rival is on it", "rocket", _trial_rocket, 0.1],
		["safe_window", "keeps its dear spells for a rival who is dazed and cannot answer", "window", _trial_window, 0.04],
		["burn_bridge", "reaches for fire against a rival on lily pads", "burn", _trial_bridge, 0.1],
		["land_shot", "aims where a rival in the air will come down", "landing", _trial_landing, 30.0],
		["habit_lean", "aims to the side a rival has always stepped to", "habit", _trial_habit_lean, 10.0],
		["falling_stone", "steps aside from a boulder it sees falling on it", "stone", _trial_stone, 0.5],
		["ambush_sneak", "goes unseen toward a rival it knows of, off a way", "ambush", _trial_ambush, 0.5],
		["decoy_bait", "gives a rival with heavy blows a shadow to throw them at", "decoy", _trial_decoy, 0.5],
		["shatter_ice", "chooses a heavy blow for a rival frozen in ice", "shatter", _trial_ice, 0.25],
		["keep_reserve", "keeps its dear spells back when it is running low", "reserve", _trial_reserve, -0.2],
		["press_recovery", "throws a quick shot at a rival just seen to cast a dear spell", "recover", _trial_recover, 0.04],
		["burn_thicket", "reaches for fire against a rival standing in thorns", "thicket", _trial_thicket, 0.1],
		["worn_caution", "keeps its distance from a rival when it is worn down to a small maximum", "caution", _trial_worn, -0.2],
		["range_memory", "stops casting what has missed twice at this range", "range_memory", _trial_range, -0.15],
	]


func _run(drill: Array) -> void:
	var with := 0.0
	var without := 0.0
	for k in TRIALS:  # (one trial with the idea, one without, in turn, so whatever drifts over the run falls on both alike)
		_trial_no = k + 1
		OS.set_environment("AI_OFF", "")
		with += await (drill[3] as Callable).call()
		OS.set_environment("AI_OFF", drill[2])
		without += await (drill[3] as Callable).call()
	OS.set_environment("AI_OFF", "")
	with /= TRIALS
	without /= TRIALS
	var need: float = drill[4]
	var ok := (without > 0.0 and with <= without * (1.0 + need)) if need < 0.0 else (with >= without + need)
	print("%s  %s: %.3f a trial with it, %.3f without" % ["PASS" if ok else "FAIL", drill[1], with, without])
	_failed = _failed or not ok


## The partner is put on the court's floor and the player a little way off, both as they were; nothing of the last trial is left.
func _reset() -> Dictionary:
	for group in ["lasting", "walls", "rocks", "fires", "flora", "clouds", "shots", "projectiles"]:
		for node in get_tree().get_nodes_in_group(group):
			if not node is Pond:
				node.queue_free()
	var partner: Wizard = _lab._partner
	partner.brain.rng.seed = _trial_no * 7919 + 13  # (the same dice in the run with an idea and the run without it)
	seed(_trial_no)
	var floor_y := _floor
	partner.max_stamina = Wizard.MAX_STAMINA
	partner.stamina = partner.max_stamina
	partner.global_position = Vector2(ArenaGen.column_x(-24), floor_y)
	partner.velocity = Vector2.ZERO
	_lab.player.global_position = Vector2(ArenaGen.column_x(-16), floor_y)
	_lab.player.velocity = Vector2.ZERO
	_lab.player.stamina = _lab.player.max_stamina
	_lab.player.max_stamina = 9999.0
	return {"partner": partner, "floor": floor_y}


## The player draws a spell where the partner can see it, as a person would, with the trail on the screen.
func _draw(spell_name: String, stroke: PackedVector2Array, seconds := 0.9) -> void:
	var data: Spell = SpellData.SPELLS[spell_name]
	_color = SpellData.SCHOOL_COLORS[data.school]
	var caster: Caster = _lab.caster
	_lab.player.pen.begin(stroke, SpellData.SCHOOL_COLORS[data.school], func(points: PackedVector2Array) -> void: caster.cast_stroke(data.buttons, points), seconds)


func _wait(seconds: float) -> void:
	for k in int(seconds * 60.0):
		await get_tree().physics_frame
		if _lab.player.pen.active():
			_lab.player.cast_color = _color
		_lab.player.pen.tick(get_physics_process_delta_time())  # (a person's wizard has no brain to draw its stroke for it)


## A boulder is drawn above the partner while it watches: does it plan to step out from under it? (Its planning is read at the moment of reaction; what its legs then
## manage is another matter.) Asked again with the stroke drawn well to the side, where it should plan nothing.
func _trial_stonefall() -> float:
	var s := _reset()
	var partner: Wizard = s["partner"]
	var b: WizardBrain = partner.brain
	b.dormant = true  # (its own thinking is held; only the reaction is read)
	partner.global_position = Vector2(ArenaGen.column_x(-24), s["floor"])
	_lab.player.global_position = Vector2(ArenaGen.column_x(-16), s["floor"])
	await _wait(1.6)  # (the view settles on the player: a view still moving drags a stroke out of shape)
	var planned := 0.0
	for offset in [0.0, 400.0]:
		b.react = 0.0
		b._reaction = ""
		b.combat.defend_cooldown = 0.0
		var at := partner.global_position + Vector2(offset, 0.0)
		var shape := GestureTemplates.preview_points("stonefall")
		var low := shape[0]
		var high := shape[0]
		for p in shape:
			low = low.min(p)
			high = high.max(p)
		var out := PackedVector2Array()
		for p in shape:
			out.append(at + Vector2(0.0, -150.0) + (p - (low + high) * 0.5) * 0.9)
		_draw("Stonefall", BrainStrokes.densify(out), 0.9)
		b.opponent = _lab.player
		var escaped := false
		for frame in 60:  # it watches the trail grow, a look at a time
			await _wait(0.017)  # (one step)
			b.sight.look_about(0.016)
			if b.react <= 0.0:
				b._react(0.016, true, _lab.player.global_position - partner.global_position)
			escaped = escaped or b._reaction == "escape"
		if offset == 0.0 and escaped:
			planned += 1.0  # it plans to get out from under it
		elif offset > 0.0 and escaped:
			planned -= 1.0  # and does not run from a boulder that falls elsewhere
		await _wait(1.5)
	return planned


## What the partner would cast in a situation, asked many times: the share of its choices that were one of `wanted`. The brain is not run; only its choice is read, so
## this says what it thinks of the situation and nothing of what it then manages to do.
func _share(partner: Wizard, wanted: Array, asks := 40, stamina := -1.0) -> float:
	var b: WizardBrain = partner.brain
	b.dormant = true
	var hits := 0
	for k in asks:
		partner.pen.drop()
		b.rest.clear()
		b.combat.recent.clear()
		b.cast_cooldown = 0.0
		partner.stamina = partner.max_stamina if stamina < 0.0 else stamina
		b.opponent = _lab.player
		b.sight.look_about(0.1)
		if b.combat.attack(_lab.player.global_position - partner.global_position, true) and b.combat.recent[0] in wanted:
			hits += 1
		partner.pen.drop()
	return float(hits) / asks


## The rival at the end of a high ledge, the partner on it too, a few steps off.
func _trial_ledge() -> float:
	var s := _reset()
	var partner: Wizard = s["partner"]
	var ledge := StaticBody2D.new()
	ledge.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(900.0, 20.0)
	shape.shape = rect
	ledge.add_child(shape)
	var top: float = float(s["floor"]) - 360.0
	ledge.position = Vector2(ArenaGen.column_x(-24), top + 10.0)
	_lab.add_child(ledge)
	partner.global_position = Vector2(ArenaGen.column_x(-24) + 170.0, top - 4.0)
	_lab.player.global_position = Vector2(ArenaGen.column_x(-24) + 400.0, top - 4.0)
	await _wait(0.3)
	var share := _share(partner, ["Push"])
	ledge.queue_free()
	await _wait(0.1)
	return share


## The rival frozen in a block of ice on the open floor.
func _trial_ice() -> float:
	var s := _reset()
	var partner: Wizard = s["partner"]
	partner.global_position = Vector2(ArenaGen.column_x(-24), s["floor"])
	_lab.player.global_position = Vector2(ArenaGen.column_x(-24) + 260.0, s["floor"])
	_lab.player.freeze(5.0)
	await _wait(0.3)
	var share := _share(partner, ["Stonefall", "Earthquake", "Scythe", "Supernova", "Spark"])
	_lab.player.thaw()
	return share


const THROWN := ["Ignite", "Frostbolt", "Barbs", "Pebble"]


## The rival has a Barrier up: of what the partner starts to cast, how much is not thrown (a thrown spell is turned away). Asked through its attack step, so a wait counts as nothing cast.
func _trial_shield() -> float:
	var s := _reset()
	var partner: Wizard = s["partner"]
	partner.global_position = Vector2(ArenaGen.column_x(-24), s["floor"])
	_lab.player.global_position = Vector2(ArenaGen.column_x(-24) + 260.0, s["floor"])
	_lab.player.raise_shield(30.0)
	await _wait(0.3)
	var b: WizardBrain = partner.brain
	b.dormant = true
	var hits := 0
	var asks := 40
	for k in asks:
		partner.pen.drop()
		b.rest.clear()
		b.combat.recent.clear()
		b.cast_cooldown = 0.0
		b.react = 0.0
		partner.stamina = partner.max_stamina
		b.opponent = _lab.player
		b.sight.look_about(0.1)
		b._attack(_lab.player, _lab.player.global_position - partner.global_position, true)
		if partner.pen.active() and not b.combat.recent.is_empty() and not b.combat.recent[0] in THROWN:
			hits += 1
		partner.pen.drop()
	_lab.player.set("_shield_time", 0.0)  # (it lowers)
	return float(hits) / asks


## The rival has been seen to raise a Barrier, and has none up: how much of what the partner would cast comes from above or from the ground (the spells a Barrier does not turn away).
func _trial_habit() -> float:
	var s := _reset()
	var partner: Wizard = s["partner"]
	partner.global_position = Vector2(ArenaGen.column_x(-24), s["floor"])
	_lab.player.global_position = Vector2(ArenaGen.column_x(-24) + 260.0, s["floor"])
	await _wait(0.3)
	var b: WizardBrain = partner.brain
	b.profile.seen.get_or_add(_lab.player.get_instance_id(), {})["Barrier"] = {"n": 2, "at": b.clock}
	var share := _share(partner, ["Stonefall", "Spark", "Stalagmite", "Earthquake", "Sinkhole", "Hailstorm"])
	b.profile.seen.erase(_lab.player.get_instance_id())
	return share


## A page of a school it holds a lot of and one of a school it holds none of: which counts for more to it.
func _trial_kit() -> float:
	var s := _reset()
	var partner: Wizard = s["partner"]
	partner.global_position = Vector2(ArenaGen.column_x(-24), s["floor"])
	await _wait(0.3)
	var saved: Ledger = partner.ledger
	var book := Ledger.new()
	for page in ["Ignite", "Fire Breath", "Firewall", "Flare"]:
		book.learn(page)
	partner.ledger = book
	var fire := PagePickup.new()
	fire.page = "Smoke Screen"
	var water := PagePickup.new()
	water.page = "Frostbolt"
	_lab.add_child(fire)
	_lab.add_child(water)
	fire.global_position = partner.global_position + Vector2(-300.0, 0.0)
	water.global_position = partner.global_position + Vector2(300.0, 0.0)
	var b: WizardBrain = partner.brain
	var chose := 1.0 if b.travel.kit_want(water) > b.travel.kit_want(fire) + 0.2 else 0.0  # (the weight a page of each counts for; the walking to either is the same)
	partner.ledger = saved
	fire.queue_free()
	water.queue_free()
	await _wait(0.1)
	return chose


## A rival who has been shooting at it is somewhere off, quiet all round: does it begin the chant that fills its strength?
func _trial_brace() -> float:
	var s := _reset()
	var partner: Wizard = s["partner"]
	partner.global_position = Vector2(ArenaGen.column_x(-24), s["floor"])
	_lab.player.global_position = Vector2(ArenaGen.column_x(-24) + 520.0, s["floor"])
	await _wait(1.6)  # (the view settles on the player; what lies off the screen is not seen)
	var b: WizardBrain = partner.brain
	b.dormant = true
	b.opponent = _lab.player
	b.sight.known[_lab.player.get_instance_id()] = {"wizard": _lab.player, "at": _lab.player.global_position, "age": 0.0}  # (it has seen the rival, off to one side)
	b.pressure = 1.0
	b._hurt_age = 9.0
	b.mend.brace_wait = 0.0
	b.chant.typing = ""
	b.rest.clear()
	partner.infinite_time = 0.0
	b.mend.tend(Vector2(520.0, 0.0), false, false)
	var began := 1.0 if b.chant.typing == "boundless" else 0.0
	b.chant.typing = ""
	b.pressure = 0.0
	return began


## A rival right on it: of the ways it chooses to get them off, how often a rocket.
func _trial_rocket() -> float:
	var s := _reset()
	var partner: Wizard = s["partner"]
	partner.global_position = Vector2(ArenaGen.column_x(-24), s["floor"])
	_lab.player.global_position = Vector2(ArenaGen.column_x(-24) + 60.0, s["floor"])
	await _wait(0.3)
	var b: WizardBrain = partner.brain
	b.dormant = true
	b.opponent = _lab.player
	var hits := 0
	for k in 60:
		b.rest.clear()
		partner.stamina = partner.max_stamina
		if b.combat.choose_repel() == "rocket":
			hits += 1
	return float(hits) / 60.0


## Where the partner stands, and where the rival stands off from it, with the partner's picture of the rival freshened by hand (what it would have seen).
func _face(partner: Wizard, gap: float) -> WizardBrain:
	var s := _reset()
	partner.global_position = Vector2(ArenaGen.column_x(-24), s["floor"])
	_lab.player.global_position = partner.global_position + Vector2(gap, 0.0)
	var b: WizardBrain = partner.brain
	b.dormant = true
	b.opponent = _lab.player
	b.rest.clear()
	b.sight.known[_lab.player.get_instance_id()] = {"wizard": _lab.player, "at": _lab.player.global_position, "age": 0.0}
	return b


func _trial_window() -> float:
	var partner: Wizard = _lab._partner
	_face(partner, 260.0)
	await _wait(0.3)
	_lab.player.daze_time = 5.0
	var dear: Array = []
	for spell: Spell in SpellData.SPELLS.values():
		if spell.cost >= 50.0 and not spell.pays_max():
			dear.append(spell.spell_name)
	var share := _share(partner, dear, 160)
	_lab.player.daze_time = 0.0
	return share


func _trial_bridge() -> float:
	var partner: Wizard = _lab._partner
	_face(partner, 260.0)
	var pads := LilyPads.new()
	pads.line = BrainStrokes.line(_lab.player.global_position + Vector2(-90.0, -4.0), _lab.player.global_position + Vector2(90.0, -4.0))
	_lab.add_child(pads)
	await _wait(0.6)
	var share := _share(partner, ["Ignite", "Fire Breath", "Firewall", "Flaming Sphere"], 160)
	pads.queue_free()
	await _wait(0.1)
	return share


func _trial_landing() -> float:
	var partner: Wizard = _lab._partner
	var b := _face(partner, 260.0)
	_lab.player.global_position.y -= 300.0
	_lab.player.velocity = Vector2.ZERO
	await _wait(0.12)  # (in the air by now)
	b.sight.known[_lab.player.get_instance_id()] = {"wizard": _lab.player, "at": _lab.player.global_position, "age": 0.0}
	return b.predict(0.6).y - b.sight.seen_center(_lab.player).y


func _trial_habit_lean() -> float:
	var partner: Wizard = _lab._partner
	var b := _face(partner, 260.0)
	b.profile.dodge[_lab.player.get_instance_id()] = 1.0
	await _wait(0.3)
	var lean := b.predict(0.5).x - b.sight.seen_center(_lab.player).x
	b.profile.dodge.erase(_lab.player.get_instance_id())
	return lean


func _trial_stone() -> float:
	var partner: Wizard = _lab._partner
	var b := _face(partner, 400.0)
	await _wait(0.3)
	var rock := Boulder.new()
	_lab.add_child(rock)
	rock.global_position = partner.center() + Vector2(0.0, -220.0)
	rock.linear_velocity = Vector2(0.0, 380.0)
	b.react = 0.0
	b._reaction = ""
	b.combat.defend_cooldown = 0.0
	var escaped := 0.0
	for frame in 20:
		await get_tree().physics_frame
		if is_instance_valid(rock):
			rock.global_position.x = partner.center().x
		if b.react <= 0.0:
			b._react(0.016, true, _lab.player.global_position - partner.global_position)
		if b._reaction == "escape":
			escaped = 1.0
	if is_instance_valid(rock):
		rock.queue_free()
	return escaped


func _trial_ambush() -> float:
	var partner: Wizard = _lab._partner
	var b := _face(partner, 600.0)
	await _wait(0.3)
	b.mend.tend_cooldown = 0.0
	b.mend.tend(Vector2(600.0, 0.0), false, false)
	var went := 1.0 if b.rest.has("Sneak") else 0.0
	partner.pen.drop()
	return went


func _trial_decoy() -> float:
	var partner: Wizard = _lab._partner
	var b := _face(partner, 200.0)
	await _wait(0.3)
	b.pressure = 0.5
	b.profile.seen.get_or_add(_lab.player.get_instance_id(), {})["Stonefall"] = {"n": 1, "at": b.clock}
	b.mend.tend(Vector2(200.0, 0.0), true, true)
	var cast := 1.0 if b.rest.has("Decoy") else 0.0
	b.profile.seen.erase(_lab.player.get_instance_id())
	b.pressure = 0.0
	partner.pen.drop()
	return cast


func _dear() -> Array:
	var dear: Array = []
	for spell: Spell in SpellData.SPELLS.values():
		if spell.cost >= 50.0 and not spell.pays_max():
			dear.append(spell.spell_name)
	return dear


func _trial_reserve() -> float:
	var partner: Wizard = _lab._partner
	_face(partner, 260.0)
	await _wait(0.3)
	return _share(partner, _dear(), 160, 60.0)


func _trial_recover() -> float:
	var partner: Wizard = _lab._partner
	var b := _face(partner, 260.0)
	await _wait(0.3)
	b.profile.dear_at[_lab.player.get_instance_id()] = b.clock
	var share := _share(partner, BrainCombat.SHOTS, 160)
	b.profile.dear_at.clear()
	return share


func _trial_thicket() -> float:
	var partner: Wizard = _lab._partner
	_face(partner, 260.0)
	var thorns := Bramble.new()
	thorns.line = BrainStrokes.line(_lab.player.global_position + Vector2(-90.0, -4.0), _lab.player.global_position + Vector2(90.0, -4.0))
	_lab.add_child(thorns)
	await _wait(0.6)
	var share := _share(partner, ["Ignite", "Fire Breath", "Firewall", "Flaming Sphere"], 160)
	thorns.queue_free()
	await _wait(0.1)
	return share


func _trial_range() -> float:
	var partner: Wizard = _lab._partner
	var b := _face(partner, 260.0)
	await _wait(0.3)
	b.profile.tried_at.clear()
	b.profile.worked_at.clear()
	for spell_name in BrainCombat.SHOTS:
		b.profile.tried_at["%s|1" % spell_name] = 4  # (four tries from this far off, none landed)
	var share := _share(partner, BrainCombat.SHOTS, 160)
	b.profile.tried_at.clear()
	return share


func _trial_worn() -> float:
	var partner: Wizard = _lab._partner
	_face(partner, 90.0)
	await _wait(0.3)
	partner.max_stamina = Wizard.MAX_STAMINA * 0.3
	var share := _share(partner, ["Scythe", "Fire Breath", "Spore Puff", "Thunderclap", "Insect Plague", "Flytrap"], 160)
	partner.max_stamina = Wizard.MAX_STAMINA
	return share

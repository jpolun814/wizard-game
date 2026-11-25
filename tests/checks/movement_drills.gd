extends Check
## Can an AI wizard work out how to get somewhere from what its spells do? (docs/handoff/23_movement_planning.md, stage 0.) It is put in a bare room with a page somewhere and the
## spells named, and nothing in the room is labelled for it. Each drill is played twice: first by a script that moves the real body and casts the real spells, which proves that
## there is a way (PROOF), and then by the AI's own mind (PASS or FAIL). "refuse" drills have no way: the AI must not throw itself away trying, or go on wanting the page.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/movement_drills.tscn [-- only=ledge] [proof=only] [ai=only] [trace=1] [labelled=1]
##
## On 2026-11-25 most of these fail: they are what the movement planning is for. With `labelled=1` the room reads itself and names its pits and faces for the AI, as rooms do
## in the game (RoomScan), which shows how much of what the AI can do today comes from the labels. The planning must do without them.

const ROOM := preload("res://tests/support/drill_room.gd")
const SECONDS := 30.0
const COLUMNS := 48

var drills: Array[Dictionary] = []
var _room: Lab
var _trace := false
var _labelled := false


## A wizard that goes the way the script says.
class ScriptedBrain extends WizardBrain:
	var dir := 0.0
	var climb := false

	func think(_delta: float) -> void:
		wizard.walk(dir * WizardBrain.WALK_SPEED)
		wizard.pad.climb = climb


func _ready() -> void:
	var only := ""
	var proof := true
	var ai := true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.substr(5).replace("%", " ")
		elif arg == "proof=only":
			ai = false
		elif arg == "ai=only":
			proof = false
		elif arg == "trace=1":
			_trace = true
		elif arg == "labelled=1":
			_labelled = true
	_list()
	var unproved := 0
	var passed := 0
	var tried := 0
	for drill in drills:
		if only != "" and not String(drill["name"]).contains(only):
			continue
		if proof and drill.has("proof"):
			await _enter(drill, true)
			var proved: bool = await _prove(drill)
			print("%s  %s" % ["PROOF   " if proved else "NO PROOF", drill["name"]])
			unproved += 0 if proved else 1
			await _leave()
		if ai:
			tried += 1
			await _enter(drill, false)
			var why := await _watch(drill)
			passed += 1 if why == "" else 0
			_verdict(why == "", String(drill["name"]) + ("" if why == "" else ": " + why))
			await _leave()
	print("%d of %d drills passed; %d without proof" % [passed, tried, unproved])
	get_tree().quit(1 if _failures > 0 or unproved > 0 else 0)


# ------------------------------------------------------------------------------------------------ the drills

func _list() -> void:
	var gap := _ground([[16, 30, 9.0]])     # 14 columns, 448 px: more than a jump (about 10) and less than a jump and a step
	var chasm := _ground([[12, 38, 9.0]])   # 26 columns, 832 px: more than any one spell carries a wizard over
	var ledge := _ground([[26, COLUMNS, -6.0]])  # 192 px up: more than a jump (about 138 px)
	var pit := _ground([[14, 26, 6.0]])
	var steps := _ground([[18, 32, -6.0], [32, COLUMNS, -11.0]])
	var loft: Array[Rect2i] = [Rect2i(ArenaGen.FIRST_COL + 26, ArenaGen.GROUND_ROW - 11, COLUMNS - 26, 2)]  # a floor 11 rows up with nothing under it, as over a stairwell
	_add("walk: level ground", _ground([]), 6, 38, [], [["go", 1, 8.0]])
	_add("jump: a narrow gap", _ground([[20, 25, 7.0]]), 6, 38, [], [["to", 17], ["go", 1, 0.12], ["jump"], ["go", 1, 6.0]])
	_add("gap: Shadow Step", gap, 6, 40, ["Shadow Step"], [["to", 13], ["go", 1, 0.12], ["jump"], ["go", 1, 0.4], ["step", -10.0], ["go", 1, 6.0]])
	_add("gap: Featherfall", gap, 6, 40, ["Featherfall"], [["to", 13], ["cast", "Featherfall"], ["wait", 0.3], ["go", 1, 0.12], ["jump"], ["go", 1, 8.0]])
	_add("gap: Rocket Jump", gap, 6, 40, ["Rocket Jump"], [["to", 15], ["cast", "Rocket Jump"], ["wait", 1.0], ["go", 1, 6.0]])
	_add("chasm: Shadow Step, many times", chasm, 4, 43, ["Shadow Step"], [["to", 9], ["go", 1, 0.12], ["jump"], ["go", 1, 0.4], ["step", -20.0], ["step", -20.0], ["step", -20.0], ["land"], ["to", 43]])
	_add("chasm: Updraft and Featherfall", chasm, 4, 43, ["Updraft", "Featherfall"], [["to", 9], ["cast", "Featherfall"], ["wait", 0.3], ["cast", "Updraft"], ["rise", 380.0], ["go", 1, 4.2], ["land"], ["to", 43]])
	_add("chasm: Rocket Jump and Featherfall", chasm, 4, 43, ["Rocket Jump", "Featherfall"], [["to", 10], ["cast", "Featherfall"], ["wait", 0.3], ["cast", "Rocket Jump"], ["wait", 1.4], ["go", 1, 4.2], ["land"], ["to", 43]])
	_add("ledge: Updraft", ledge, 8, 40, ["Updraft"], [["to", 24], ["cast", "Updraft"], ["rise", 230.0], ["go", 1, 5.0]])
	_add("ledge: Rocket Jump", ledge, 8, 40, ["Rocket Jump"], [["to", 24], ["cast", "Rocket Jump"], ["rise", 230.0], ["go", 1, 5.0]])
	_add("ledge: Geyser", ledge, 8, 40, ["Geyser"], [["to", 24], ["cast", "Geyser"], ["rise", 230.0], ["go", 1, 5.0]])
	_add("ledge: Push", ledge, 8, 40, ["Push"], [["to", 24], ["cast", "Push"], ["rise", 230.0], ["go", 1, 5.0]])
	_add("ledge: Liana", ledge, 8, 40, ["Liana"], [["to", 24], ["cast", "Liana"], ["climb", 230.0], ["go", 1, 5.0]])
	_add("ledge: Shadow Step", ledge, 8, 40, ["Shadow Step"], [["to", 21], ["step", -60.0], ["go", 1, 5.0]])
	_add("pit: Rocket Jump", pit, 18, 38, ["Rocket Jump"], [["to", 24], ["cast", "Rocket Jump"], ["rise", 230.0], ["go", 1, 5.0]])
	_add("pit: Updraft", pit, 18, 38, ["Updraft"], [["to", 24], ["cast", "Updraft"], ["rise", 230.0], ["go", 1, 5.0]])
	_add("two ledges: Updraft, twice", steps, 6, 42, ["Updraft"], [["to", 16], ["cast", "Updraft"], ["rise", 230.0], ["go", 1, 0.8], ["land"], ["to", 30], ["cast", "Updraft"], ["rise", 230.0], ["go", 1, 4.0]])
	_add("loft: Shadow Step", _ground([]), 8, 38, ["Shadow Step"], [["to", 18], ["jump"], ["wait", 0.3], ["step", -55.0], ["step", -10.0], ["go", 1, 5.0]], loft)
	_add("loft: Rocket Jump", _ground([]), 8, 38, ["Rocket Jump"], [["to", 24], ["cast", "Rocket Jump"], ["rise", 390.0], ["go", 1, 5.0]], loft)
	_add("loft: Updraft", _ground([]), 8, 38, ["Updraft"], [["to", 24], ["cast", "Updraft"], ["rise", 400.0], ["go", 1, 5.0]], loft)
	_add("thorns: three columns, healthy and with no fire", _ground([]), 6, 38, [], [["go", 1, 12.0]])
	drills[-1]["thorns"] = Vector2i(20, 23)
	_add("thorns: eight columns, healthy and with no fire", _ground([]), 6, 38, [], [["go", 1, 16.0]])
	drills[-1]["thorns"] = Vector2i(18, 26)
	_add("refuse: a gap and nothing to cross it with", gap, 6, 40, [], [])
	drills[-1]["refuse"] = true
	_add("refuse: a ledge, and too worn for a Rocket Jump", ledge, 8, 40, ["Rocket Jump"], [])
	drills[-1]["refuse"] = true
	drills[-1]["max"] = 25.0


## The height of the ground in each column: level, but for [from, to, rows] (to is not in it; rows below 0 are higher).
func _ground(runs: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(COLUMNS)
	for run: Array in runs:
		for k in range(run[0], run[1]):
			out[k] = run[2]
	return out


func _add(title: String, plan: PackedFloat32Array, start: int, page: int, spells: Array, proof: Array, slabs: Array[Rect2i] = []) -> void:
	var drill := {"name": title, "plan": plan, "start": start, "page": page, "spells": spells, "slabs": slabs}
	if not proof.is_empty():
		drill["proof"] = proof
	drills.append(drill)


# ------------------------------------------------------------------------------------------------ the room

## The floor in a column, from the plan: the top of the slab there, if it is asked for (`over`) and there is one, else the ground.
func _floor(drill: Dictionary, k: int, over := false) -> float:
	for slab: Rect2i in drill["slabs"]:
		if over and k >= slab.position.x - ArenaGen.FIRST_COL and k < slab.end.x - ArenaGen.FIRST_COL:
			return float(slab.position.y * ArenaGen.TILE)
	return float((ArenaGen.GROUND_ROW + int(drill["plan"][k])) * ArenaGen.TILE)


func _x(k: float) -> float:
	return (float(ArenaGen.FIRST_COL) + k + 0.5) * float(ArenaGen.TILE)


func _goal(drill: Dictionary) -> Vector2:
	return Vector2(_x(drill["page"]), _floor(drill, drill["page"], true))


func _enter(drill: Dictionary, scripted: bool) -> void:
	Dice.reset(hash(drill["name"]))
	ROOM.plan = drill["plan"]
	ROOM.slabs = drill["slabs"]
	var scene: Node = load("res://scenes/duel.tscn").instantiate()
	scene.set_script(ROOM)
	_room = scene
	add_child(_room)
	for k in 10:
		await get_tree().process_frame
	var wizard: Wizard = _room.player
	wizard.human = false
	wizard.ensure_caster()
	wizard.ledger = Ledger.new()
	for spell_name: String in drill["spells"]:
		wizard.ledger.learn(spell_name)
	wizard.max_stamina = drill.get("max", Wizard.MAX_STAMINA)
	wizard.stamina = wizard.max_stamina
	wizard.movement_enabled = true
	wizard.global_position = Vector2(_x(drill["start"]), _floor(drill, drill["start"]) - 2.0)
	wizard.velocity = Vector2.ZERO
	if drill.has("thorns"):
		var thorns := Bramble.new()
		var points := PackedVector2Array()
		var x := _x(drill["thorns"].x) - 16.0
		while x <= _x(drill["thorns"].y) - 16.0:
			points.append(Vector2(x, _floor(drill, drill["thorns"].x)))
			x += Bramble.SPACING
		thorns.planted_ground = points
		_room.add_child(thorns)
	var pickup := PagePickup.new()
	pickup.page = "Glowcap"
	pickup.position = _goal(drill)
	_room.add_child(pickup)
	if _labelled:
		_room.read_room(Vector2i(ArenaGen.FIRST_COL + int(drill["start"]), int(_floor(drill, drill["start"]) / ArenaGen.TILE) - 1))
		wizard.nav = _room.nav
	else:
		wizard.nav = _room.call("plain_map")
	wizard.brain = ScriptedBrain.new(wizard) if scripted else WizardBrain.new(wizard)
	await _frames(20)


func _leave() -> void:
	_room.queue_free()
	_room = null
	await _frames(4)


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame


func _arrived(drill: Dictionary) -> bool:
	var wizard: Wizard = _room.player
	var off := wizard.global_position - _goal(drill)
	return wizard.is_on_floor() and absf(off.x) < 60.0 and absf(off.y) < 30.0


## Where the wizard is, for a trace: its column, how far up from where it began, and what it has.
func _where(drill: Dictionary) -> String:
	var wizard: Wizard = _room.player
	return "column %.1f, %.0f px up, stamina %.0f, casts %d" % [wizard.global_position.x / 32.0 - ArenaGen.FIRST_COL, _floor(drill, drill["start"]) - wizard.global_position.y, wizard.stamina, wizard.casts_made]


# ------------------------------------------------------------------------------------------------ the AI's turn

## Why it failed, or "" when it did what was wanted.
func _watch(drill: Dictionary) -> String:
	var wizard: Wizard = _room.player
	var refuse: bool = drill.get("refuse", false)
	var still := 0.0
	var last := wizard.global_position
	var casts := wizard.casts_made
	var t := 0.0
	while t < SECONDS:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		still += 1.0 / 60.0 if wizard.global_position.distance_to(last) < 0.5 else 0.0
		last = wizard.global_position
		if _trace and int(t * 60.0) % 60 == 0:
			print("    %4.1f s: %s, goal '%s'" % [t, _where(drill), wizard.brain.goal])
		if wizard.dead:
			return "it died"
		if not refuse and _arrived(drill):
			return ""
		if refuse and wizard.is_on_floor() and wizard.global_position.y > _floor(drill, drill["start"]) + 60.0:
			return "it went into the pit"
	if refuse:
		if wizard.casts_made > casts:
			return "it cast what could not help (%d casts)" % (wizard.casts_made - casts)
		return "it still goes for the page" if wizard.brain.goal == "page" else ""
	return "ended at %s; still %.0f%% of the time, goal '%s'" % [_where(drill), 100.0 * still / SECONDS, wizard.brain.goal]


# ------------------------------------------------------------------------------------------------ the proof

func _prove(drill: Dictionary) -> bool:
	var wizard: Wizard = _room.player
	var mind: ScriptedBrain = wizard.brain
	var ground := wizard.global_position.y
	for act: Array in drill["proof"]:
		match act[0]:
			"to":
				var want := _x(act[1])
				for k in 600:
					var off := want - wizard.global_position.x
					mind.dir = 0.0 if absf(off) < 6.0 else signf(off)
					if mind.dir == 0.0:
						break
					await get_tree().physics_frame
				mind.dir = 0.0
				await _frames(12)
				ground = wizard.global_position.y
			"jump":
				mind.dir = 1.0 if String(drill["name"]).contains("gap") or String(drill["name"]).contains("chasm") else 0.0
				wizard.request_jump()
				await _frames(2)
			"go":
				mind.dir = float(act[1])
				for k in int(float(act[2]) * 60.0):
					await get_tree().physics_frame
					if _arrived(drill):
						return true
			"wait":
				mind.dir = 0.0
				await _frames(int(float(act[1]) * 60.0))
			"land":
				mind.dir = 0.0
				for k in 600:
					await get_tree().physics_frame
					if wizard.is_on_floor():
						break
			"cast":
				mind.dir = 0.0
				_cast(wizard, act[1])
				await _frames(3)
			"step":
				var from := wizard.center()
				wizard.caster.cast_stroke(SpellData.SPELLS["Shadow Step"].buttons, BrainStrokes.line(from, from + Vector2.from_angle(deg_to_rad(act[1])) * SpellData.STEP_MAX))
				await _frames(10)
			"rise":
				mind.dir = 0.0
				for k in 360:
					await get_tree().physics_frame
					if ground - wizard.global_position.y >= float(act[1]):
						break
			"climb":
				mind.climb = true
				for k in 480:
					await get_tree().physics_frame
					if ground - wizard.global_position.y >= float(act[1]):
						break
				mind.climb = false
				wizard.pad.let_go = true
				await _frames(2)
				wizard.pad.let_go = false
		if _trace:
			print("    proof %s -> %s" % [act, _where(drill)])
	return _arrived(drill)


## The spell's own picture, drawn as the brain draws it (BrainMoves.lifting).
func _cast(wizard: Wizard, spell_name: String) -> void:
	var at := wizard.center()
	var spell: Spell = SpellData.SPELLS[spell_name]
	var stroke: PackedVector2Array
	match spell_name:
		"Push":
			stroke = wizard.brain.hand.push_stroke(at, Vector2(0.1, -1.0).normalized())
		"Liana":
			stroke = BrainStrokes.offset(GestureTemplates.preview_points("vine"), Vector2(at.x + 50.0 * BrainMoves.VINE_SCALE, wizard.global_position.y - 75.0 * BrainMoves.VINE_SCALE), BrainMoves.VINE_SCALE)
		"Featherfall":
			stroke = wizard.brain.hand.tend_stroke("Featherfall", Vector2.ZERO)
		_:
			stroke = BrainStrokes.offset(GestureTemplates.preview_points(spell.gesture), at, 0.6)
	wizard.caster.cast_stroke(spell.buttons, stroke)

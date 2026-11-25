extends Check
## How each spell that moves a body moves it, frame by frame, against what was written down (tests/reference/movement_paths.json). It was made before the spells' movement
## was put in their data (docs/handoff/23_movement_planning.md, stage 1), so that a spell moved over is shown to play exactly as it did. Each spell is cast through the real
## caster in a bare room, with no key held, with right held, and with a jump first and right held.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/movement_paths_check.tscn [-- only=Push] [update=1]
##
## A spell that is meant to move differently: run it with update=1 (and `only=` for that spell alone), look at what changed, and keep the new file.

const ROOM := preload("res://tests/support/drill_room.gd")
const FILE := "res://tests/reference/movement_paths.json"
const COLUMNS := 48
const START := 14
const FRAMES := 200
const EVERY := 4
const NEAR := 0.6  # pixels

## What is cast: spell -> the angle the stroke is drawn at (for those that go along the stroke), or the chant's gift.
const CASTS := {
	"Shadow Step": [0.0, -30.0, -55.0], "Gust": [0.0], "Tide Surf": [0.0], "Push": [-90.0, -45.0],
	"Rocket Jump": [0.0], "Featherfall": [0.0], "Updraft": [0.0], "Geyser": [0.0], "Tornado": [0.0], "Liana": [0.0],
	"Wild Shape": [0.0], "Golem": [0.0], "Obsidian Armor": [0.0], "Adrenaline": [0.0], "Supernova": [0.0], "Black Hole": [0.0], "Mudslide": [0.0], "Bramble": [0.0],
	"nothing": [0.0], "chant:haste": [0.0], "chant:double_jump": [0.0],
}
const HOLDS := ["still", "right", "jump"]

var _room: Lab


class HeldBrain extends WizardBrain:
	var dir := 0.0

	func think(_delta: float) -> void:
		wizard.walk(dir * 3000.0)  # (as fast as the body can: an AI asks for 300 at most, whatever haste it has)
		wizard.pad.climb = dir == 0.0 and wizard.ledger.knows("Liana")


func _ready() -> void:
	var only := ""
	var update := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.substr(5).replace("%", " ")
		elif arg == "update=1":
			update = true
	var kept: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else {}
	for spell_name: String in CASTS:
		if only != "" and spell_name != only:
			continue
		for angle: float in CASTS[spell_name]:
			for hold: String in HOLDS:
				var key := "%s %d %s" % [spell_name, angle, hold]
				var path := await _record(spell_name, angle, hold)
				if update:
					kept[key] = path
					print("KEPT  %s: ends %.0f across, %.0f up" % [key, path[-2], -path[-1]])
				else:
					_compare(key, kept.get(key, []), path)
	if update:
		var file := FileAccess.open(FILE, FileAccess.WRITE)
		file.store_string(JSON.stringify(kept, "", false))
		file.close()
	print("every spell moves as it did" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _compare(key: String, was: Array, now: Array) -> void:
	if was.is_empty():
		_verdict(false, key + ": nothing is written down for it (run with update=1)")
		return
	for k in mini(was.size(), now.size()) / 2:
		var off := Vector2(now[2 * k] - was[2 * k], now[2 * k + 1] - was[2 * k + 1])
		if off.length() > NEAR:
			_verdict(false, "%s: %.0f px off after %.2f s (at %.0f, %.0f, and it was at %.0f, %.0f)" % [key, off.length(), k * EVERY / 60.0, now[2 * k], now[2 * k + 1], was[2 * k], was[2 * k + 1]])
			return
	_verdict(was.size() == now.size(), key)


## Where the body goes: x, y, x, y..., in pixels from where it began, every few frames from the cast.
func _record(spell_name: String, angle: float, hold: String) -> Array:
	Dice.reset(11)
	var plan := PackedFloat32Array()
	plan.resize(COLUMNS)
	ROOM.plan = plan
	ROOM.slabs = [] as Array[Rect2i]
	_room = load("res://scenes/duel.tscn").instantiate()
	_room.set_script(ROOM)
	add_child(_room)
	for k in 6:
		await get_tree().process_frame
	var wizard: Wizard = _room.player
	wizard.human = false
	wizard.ensure_caster()
	wizard.ledger = Ledger.new()
	wizard.movement_enabled = true
	if SpellData.SPELLS.has(spell_name):
		wizard.ledger.learn(spell_name)
	wizard.global_position = Vector2((float(ArenaGen.FIRST_COL + START) + 0.5) * ArenaGen.TILE, float(ArenaGen.GROUND_ROW * ArenaGen.TILE) - 2.0)
	wizard.velocity = Vector2.ZERO
	var mind := HeldBrain.new(wizard)
	wizard.brain = mind
	wizard.facing = 1.0
	for k in 20:
		await get_tree().physics_frame
	Dice.reset(12)
	var from := wizard.global_position
	mind.dir = 0.0 if hold == "still" else 1.0
	if hold == "jump":
		wizard.request_jump()
		for k in 12:
			await get_tree().physics_frame
	_cast(wizard, spell_name, angle)
	var path := []
	for k in FRAMES:
		await get_tree().physics_frame
		if k % EVERY == 0:
			path.append(snappedf(wizard.global_position.x - from.x, 0.1))
			path.append(snappedf(wizard.global_position.y - from.y, 0.1))
	_room.queue_free()
	for k in 3:
		await get_tree().physics_frame
	return path


func _cast(wizard: Wizard, spell_name: String, angle: float) -> void:
	if spell_name == "nothing":
		return
	if spell_name == "chant:haste":
		wizard.grant_haste(20.0)
		return
	if spell_name == "chant:double_jump":
		wizard.grant_air_jump(20.0)
		wizard.request_jump()
		return
	var spell: Spell = SpellData.SPELLS[spell_name]
	var at := wizard.center()
	var stroke := BrainStrokes.offset(GestureTemplates.preview_points(spell.gesture), at, 0.6)
	match spell_name:
		"Shadow Step", "Gust":
			stroke = BrainStrokes.line(at, at + Vector2.from_angle(deg_to_rad(angle)) * SpellData.STEP_MAX)
		"Push":
			stroke = wizard.brain.hand.push_stroke(at, Vector2.from_angle(deg_to_rad(angle)))
		"Tide Surf":
			stroke = wizard.brain.hand.surf_stroke(1.0)
		"Liana":
			stroke = BrainStrokes.offset(GestureTemplates.preview_points("vine"), Vector2(at.x + 50.0 * BrainMoves.VINE_SCALE, wizard.global_position.y - 75.0 * BrainMoves.VINE_SCALE), BrainMoves.VINE_SCALE)
		"Featherfall":
			stroke = wizard.brain.hand.tend_stroke("Featherfall", Vector2.ZERO)
		"Supernova", "Black Hole":
			stroke = BrainStrokes.offset(GestureTemplates.preview_points(spell.gesture), at + Vector2(220.0, -30.0), 0.6)
		"Mudslide", "Bramble":
			stroke = BrainStrokes.offset(GestureTemplates.preview_points(spell.gesture), Vector2(at.x + 60.0, wizard.global_position.y - 12.0), 1.0)
	var before := wizard.casts_made
	wizard.caster.cast_stroke(spell.buttons, stroke)
	for node in _room.get_children():
		if node is Tornado:
			node._dice.seed = 5  # (it flings by chance: the same throws whatever else has rolled dice, alone or in the suite)
	if wizard.casts_made == before:
		_verdict(false, "%s at %d was not read as itself" % [spell_name, angle])

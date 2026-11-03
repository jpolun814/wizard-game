extends Node

## The brain knows every spell. Each spell in the game is given, alone, to a wizard that the brain plays, in the place where a wizard would want it, and the
## wizard must cast it of its own accord (or, for the spells that raise it up to a rival over its head, get up to them). A spell with no line in
## `WizardBrain.USES` fails at once. The ways over water are met by `cross_check`, and are only listed here.
##
##     godot --headless --fixed-fps 60 --path . tests/brain_spells_check.tscn            (add `-- only=Hex,Sneak` for some)
## It prints PASS or FAIL for each spell and exits with code 1 if any failed.

const SECONDS := 18.0       # how long each is given
const ELSEWHERE := {"Frost Bridge": "cross_check kind=flood", "Lily Pads": "cross_check kind=flood spells=Lily%Pads"}

## How each spell is set up: "gap" the pixels between the two wizards, and flags for what the spell is for. Spells not listed are tried with the defaults.
const SCENES := {
	"Icicles": {"ceiling": true},
	"Flare": {"dark": true}, "Glowcap": {"dark": true}, "Moonbeam": {"dark": true},
	"Offering": {"tired": true}, "Adrenaline": {"tired": true}, "Sneak": {"low": true},
	"Hunter's Mark": {"gap": 720.0},
	"Burst": {"gap": 80.0, "rush": true}, "Silence": {"gap": 270.0}, "Tide Surf": {"gap": 220.0},
	"Stone Wall": {"shot_at": true}, "Smoke Screen": {"shot_at": true}, "Decoy": {"shot_at": true}, "Crimson Veil": {"shot_at": true},
	"Obsidian Armor": {"shot_at": true}, "Eclipse": {"shot_at": true, "gap": 300.0},
	"Barrier": {"shot_at": true, "gap": 400.0, "hold": true}, "Gust": {"shot_at": true, "gap": 400.0, "hold": true}, "Shadow Step": {"shot_at": true},
	"Geyser": {"up": true}, "Updraft": {"up": true}, "Push": {"up": true}, "Liana": {"up": true}, "Great Oak": {"up": true}, "Tornado": {"up": true},
}

var _failures := 0
var _only: Array = []


## A rival that stands still.
class QuietBrain extends WizardBrain:
	func think(_delta: float) -> void:
		wizard.walk(0.0)


## A rival that stands still and throws a fireball at whoever is nearest, now and then.
class ShootingBrain extends WizardBrain:
	var _timer := 1.0

	func think(delta: float) -> void:
		wizard.walk(0.0)
		_timer -= delta
		if _timer > 0.0 or wizard.is_drawing():
			return
		var target: Wizard = null
		for other: Wizard in SpellTargets.wizards(wizard.get_tree()):
			if other != wizard and other.global_position.x > -5000.0:
				target = other
		if target == null:
			return
		_timer = 1.3
		var start: Vector2 = wizard.center() + Vector2(signf(target.center().x - wizard.center().x) * 12.0, -6.0)
		_begin_cast("Ignite", _line(start, start + (target.center() - start).normalized() * 90.0), QUICK_DRAW)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			_only = Array(arg.substr(5).replace("%", " ").split(","))
	var names: Array = SpellData.SPELLS.keys()
	names.sort()
	for spell_name: String in names:
		if not WizardBrain.USES.has(spell_name):
			_verdict(false, "%s: the brain has no use for it (no line in WizardBrain.USES)" % spell_name)
	for spell_name: String in WizardBrain.USES:
		if not SpellData.SPELLS.has(spell_name):
			_verdict(false, "%s is in WizardBrain.USES and is not a spell" % spell_name)
	for spell_name: String in names:
		if (not _only.is_empty() and not _only.has(spell_name)) or not WizardBrain.USES.has(spell_name):
			continue
		if ELSEWHERE.has(spell_name):
			print("NOTE  %s is met by %s" % [spell_name, ELSEWHERE[spell_name]])
			continue
		await _try(spell_name)
	print("every spell has its use" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## One spell, in a fresh world: the wizard that holds it and a rival, on level ground.
func _try(spell_name: String) -> void:
	var scene: Dictionary = SCENES.get(spell_name, {})
	MatchState.hurry = 100.0
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 8
	var tree := get_tree()
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await tree.process_frame
	await tree.process_frame
	var person: Wizard = world.player
	var tester: Wizard = null
	var rival: Wizard = null
	for found: Wizard in tree.get_nodes_in_group("wizards"):
		if found == person:
			continue
		if tester == null:
			tester = found
		elif rival == null:
			rival = found
		else:
			found.set_physics_process(false)
			found.global_position = Vector2(-9000.0, -9000.0)
	for mob in tree.get_nodes_in_group("mobs"):
		mob.set_physics_process(false)
		mob.global_position = Vector2(-9000.0, -9000.0)
	for page in tree.get_nodes_in_group("pages"):
		page.queue_free()
	world.set_process(false)  # or it carries the person back from the place it is put away to the place it began
	var spot: Vector2 = person.global_position
	person.set_physics_process(false)
	person.global_position = Vector2(-9000.0, -9300.0)
	var gap: float = scene.get("gap", 220.0)
	tester.global_position = spot
	tester.velocity = Vector2.ZERO
	rival.global_position = spot + Vector2(gap, 0.0)
	rival.velocity = Vector2.ZERO
	rival.brain = ShootingBrain.new(rival) if scene.get("shot_at", false) else QuietBrain.new(rival)
	rival.ledger = Ledger.of(["Ignite"])
	var top := spot.y  # the height the wizard must reach when it is to get up to the rival
	if scene.get("up", false):
		var ledge := StaticBody2D.new()
		var body := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(240.0, 40.0)
		body.shape = box
		ledge.add_child(body)
		top = spot.y - 120.0
		ledge.position = Vector2(spot.x + 200.0, top + 20.0)
		ledge.collision_layer = 1
		world.add_child(ledge)
		rival.global_position = Vector2(spot.x + 200.0, top - 2.0)
	if scene.get("ceiling", false):
		var roof := StaticBody2D.new()
		var slab := CollisionShape2D.new()
		var plate := RectangleShape2D.new()
		plate.size = Vector2(1200.0, 40.0)
		slab.shape = plate
		roof.add_child(slab)
		roof.position = Vector2(spot.x + gap * 0.5, spot.y - 260.0)
		roof.collision_layer = 1
		world.add_child(roof)
	if scene.get("dark", false):
		for node in tree.get_nodes_in_group("darkness"):
			node.color = Color(0.08, 0.08, 0.12)
	for k in 30:  # the pair settle on the ground
		await tree.physics_frame
	tester.ledger = Ledger.of([spell_name])
	var time := 0.0
	var done := false
	while time < SECONDS and not done and not tester.dead:
		await tree.physics_frame
		time += 1.0 / 60.0
		rival.stamina = 200.0
		if scene.get("rush", false):
			rival.global_position = tester.global_position + Vector2(70.0, 0.0)  # a rival who keeps on top of it
		elif scene.get("hold", false):
			rival.global_position = tester.global_position + Vector2(gap, 0.0)  # and one who keeps its distance, so that its shots take as long to arrive each time
			rival.velocity = Vector2.ZERO
		rival.max_stamina = 200.0
		if scene.get("tired", false):
			tester.stamina = minf(tester.stamina, 12.0)
		elif scene.get("low", false):
			tester.max_stamina = minf(tester.max_stamina, 80.0)
			tester.stamina = maxf(tester.stamina, 40.0)
		else:
			tester.stamina = maxf(tester.stamina, 100.0)
			tester.max_stamina = maxf(tester.max_stamina, 150.0)
		if scene.get("up", false):
			done = tester.global_position.y <= top + 8.0 and tester.global_position.x > spot.x + 90.0
		else:
			done = tester.last_spell == spell_name
	var how := "reached the rival's ledge" if scene.get("up", false) else "cast it"
	_verdict(done, "%s: the brain %s (%.1f s; %s)" % [spell_name, how, time, (tester.brain as WizardBrain).status()])
	world.queue_free()
	await tree.process_frame


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

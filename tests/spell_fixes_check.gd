extends Node

## Small fixes made together: a cast breaks Sneak, a Crimson Veil is marked and turns a hit away, a Geyser puts out Fire Breath
## and throws up whoever stands in it while it plays, and a Smoke Screen holds smoke.
##
##     godot --headless --path . --fixed-fps 60 tests/spell_fixes_check.tscn

var _failures := 0


class QuietBrain extends WizardBrain:
	func think(_delta: float) -> void:
		wizard.walk(0.0)


func _check(ok: bool, text: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", text])
	if not ok:
		_failures += 1


func _ready() -> void:
	World.random_start = false
	World.next_seed = 8
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var tree := get_tree()
	var person: Wizard = world.player
	for found: Wizard in tree.get_nodes_in_group("wizards"):
		if found != person:
			found.brain = QuietBrain.new(found)
			found.set_physics_process(false)
			found.global_position = Vector2(-9000.0, -9000.0)
	for mob in tree.get_nodes_in_group("mobs"):
		mob.set_physics_process(false)
		mob.global_position = Vector2(-9000.0, -9000.0)
	world.set_process(false)
	for i in 40:
		await get_tree().physics_frame

	# Sneak breaks on a cast, but not on the cast of Sneak itself.
	person.fade_time = 5.0
	world.spawn_spell("Sneak", "directional", person.center(), 0.0, {"length": 100.0}, person)
	person.fade_time = 5.0
	world.spawn_spell("Ignite", "directional", person.center(), 0.0, {"length": 200.0}, person)
	_check(person.fade_time <= 0.0, "a spell breaks Sneak")

	# Crimson Veil: marked while it holds, and a hit is turned away.
	person.veil = 2
	var before := person.max_stamina + person.stamina
	person.take_damage(20)
	_check(person.veil == 1, "a veil turns a hit away (%d left)" % person.veil)
	_check(person.max_stamina + person.stamina == before, "and the hit costs nothing")

	# Geyser: puts out Fire Breath and carries a wizard up while it plays.
	var spot: Vector2 = person.global_position
	var breath := FireBreath.new()
	breath.caster_node = person
	breath.aim = 0.0
	world.add_child(breath)
	for i in 20:
		await get_tree().physics_frame
	var geyser := Geyser.new()
	geyser.position = spot
	world.add_child(geyser)
	var top := 0.0
	for i in 150:
		await get_tree().physics_frame
		top = maxf(top, spot.y - person.global_position.y)
	_check(top > 60.0, "a Geyser throws up whoever stands in it (%d px)" % int(top))
	_check(not is_instance_valid(breath) or breath.is_queued_for_deletion(), "and puts out Fire Breath")

	# Smoke Screen holds smoke along its line.
	var screen := SmokeScreen.new()
	screen.line = PackedVector2Array([spot + Vector2(200.0, 0.0), spot + Vector2(200.0, -100.0)])
	world.add_child(screen)
	for i in 330:  # the smoke has to build up first
		await get_tree().physics_frame
	_check(screen.smoke_along(spot + Vector2(150.0, -50.0), spot + Vector2(250.0, -50.0)) > SmokePlume.DEPTH, "a sight line through a thickened Smoke Screen passes through more smoke than can be seen through")
	_check(screen.smoke_along(spot + Vector2(-250.0, -50.0), spot + Vector2(-150.0, -50.0)) == 0.0, "and one far from it does not")

	print("small fixes hold" if _failures == 0 else "%d FAILED" % _failures)
	tree.quit(1 if _failures > 0 else 0)

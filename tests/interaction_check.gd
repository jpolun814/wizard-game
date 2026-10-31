extends Node

## Spells that meet each other: cold and water put fire out (a Frostbolt, a Geyser, Blizzard snow), fire bakes a Mudslide dry, lightning sets a
## plant alight, and lightning that lands in a pool shocks whoever stands in it.
##
##     godot --headless --path . --fixed-fps 60 tests/interaction_check.tscn
## It prints PASS or FAIL for each meeting and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	World.random_start = false
	World.next_seed = 8
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var feet: Vector2 = world.player.global_position
	var spot := feet + Vector2(0.0, -20.0)

	var wall := Firewall.new()
	world.add_child(wall)
	wall.setup("Firewall", spot + Vector2(150.0, 0.0), 0.0)
	var patch := Hazard.place(world, spot + Vector2(-150.0, 20.0), 40.0, 30.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_verdict(not SpellTargets.douse(get_tree(), spot + Vector2(900.0, 0.0), 50.0), "water far from every fire puts out nothing")
	_verdict(SpellTargets.douse(get_tree(), wall.global_position, 50.0), "water at a Firewall puts it out")
	_verdict(SpellTargets.douse(get_tree(), patch.global_position, 50.0), "water at burning ground puts it out")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_verdict(not is_instance_valid(wall) or wall.is_queued_for_deletion(), "the Firewall is gone")
	_verdict(not is_instance_valid(patch) or patch.is_queued_for_deletion(), "the burning ground is gone")

	var frost := Projectile.new()
	world.add_child(frost)
	frost.setup("Frostbolt", spot + Vector2(400.0, 0.0), 0.0)
	var wall2 := Firewall.new()
	world.add_child(wall2)
	wall2.setup("Firewall", spot + Vector2(420.0, 0.0), 0.0)
	frost.global_position = wall2.global_position  # (the ground may rise or fall here)
	frost._impact_effect()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_verdict(not is_instance_valid(wall2) or wall2.is_queued_for_deletion(), "a Frostbolt that lands at a Firewall puts it out")

	var mud := Mudslide.new()
	mud.width = 100.0
	world.add_child(mud)
	mud.global_position = spot + Vector2(-500.0, 0.0)
	var patch2 := Hazard.place(world, mud.global_position + Vector2(20.0, 20.0), 40.0, 30.0)
	for k in 200:
		await get_tree().physics_frame
	_verdict(not is_instance_valid(mud) or mud.is_queued_for_deletion(), "fire beside a Mudslide bakes it dry")
	if is_instance_valid(patch2):
		patch2.queue_free()

	var bramble := Bramble.new()
	var thorn_at := SpellTargets.ground_below(world.get_world_2d(), feet + Vector2(-250.0, -300.0))
	bramble.line = PackedVector2Array([thorn_at + Vector2(-40.0, 0.0), thorn_at + Vector2(40.0, 0.0)])
	world.add_child(bramble)
	await get_tree().physics_frame
	var strike := SparkStrike.new()
	world.add_child(strike)
	strike.setup("Spark", thorn_at + Vector2(0.0, -100.0), 0.0)
	for k in 30:
		await get_tree().physics_frame
	_verdict(not is_instance_valid(bramble) or bramble.is_queued_for_deletion() or bramble.is_burning(), "lightning sets a Bramble alight")

	var whirl := Tornado.new()
	var whirl_at := SpellTargets.ground_below(world.get_world_2d(), feet + Vector2(250.0, -300.0))
	whirl.global_position = whirl_at
	world.add_child(whirl)
	Hazard.place(world, whirl_at + Vector2(0.0, 10.0), 40.0, 8.0)
	for k in 60:
		await get_tree().physics_frame
	_verdict(whirl.ablaze, "a Tornado that stands over a fire becomes a fire whirl")

	var pond := Pond.new()
	pond.width = 240.0
	pond.depth = 100.0
	world.add_child(pond)
	pond.global_position = feet + Vector2(-120.0, -2.0)  # sunk round where the wizard stands
	var wizard: Wizard = world.player
	await get_tree().physics_frame
	await get_tree().physics_frame
	var before := wizard.stamina
	var bolt := SparkStrike.new()
	world.add_child(bolt)
	bolt.setup("Spark", feet + Vector2(0.0, -100.0), 0.0)
	for k in 30:
		await get_tree().physics_frame
	_verdict(wizard.stamina < before, "lightning that lands in a pool shocks whoever stands in it (%.0f to %.0f)" % [before, wizard.stamina])

	var wiz: Wizard = world.player
	_verdict(wiz.haste_time < 100.0 and wiz.air_jump_time < 100.0, "before the chants are said, neither Swift Feet nor the Second Leap holds")
	wiz.ledger.settle("haste")
	wiz.ledger.settle("double_jump")
	_verdict(wiz.haste_time > 1000.0 and wiz.air_jump_time > 1000.0, "once said, Swift Feet and the Second Leap hold for good")

	_verdict(not wiz.holding_breath(), "a wizard in the open air is not holding their breath")
	var max_before := wiz.max_stamina
	wiz.smother(true)
	_verdict(wiz.holding_breath(), "a wizard with the air drawn out holds their breath")
	for k in 600:
		await get_tree().physics_frame
	_verdict(wiz.max_stamina < max_before, "and when the air runs out they suffocate (%.0f to %.0f)" % [max_before, wiz.max_stamina])
	wiz.smother(false)
	_verdict(not wiz.holding_breath(), "and they breathe again when it is let back in")

	var victim: Wizard = null
	for other: Wizard in SpellTargets.wizards(get_tree()):
		if other != wiz:
			victim = other
	world.spawn_spell("Vacuum", "positional", victim.center() + Vector2(20.0, -10.0), 0.0, {}, wiz)
	await get_tree().physics_frame
	_verdict(victim.smothered and victim.holding_breath(), "a Vacuum drawn over someone smothers them")
	wiz.damaged.emit(5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_verdict(not victim.smothered, "and lets go when its caster is hurt")
	world.spawn_spell("Vacuum", "positional", victim.center(), 0.0, {}, wiz)
	await get_tree().physics_frame
	_verdict(victim.smothered, "a Vacuum drawn again smothers them again")
	world.spawn_spell("Gust", "directional", wiz.center(), 0.0, {"length": 80.0}, wiz)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_verdict(not victim.smothered, "and lets go when its caster casts something else")

	var column := Updraft.new()
	column.global_position = wiz.global_position
	world.add_child(column)
	var low := wiz.global_position.y
	var high := low
	for k in 90:
		await get_tree().physics_frame
		high = minf(high, wiz.global_position.y)
	_verdict(low - high > 150.0, "an Updraft carries whoever stands in it up (%.0f px)" % (low - high))
	world.spawn_spell("Silence", "positional", wiz.center(), 0.0, {}, victim)
	await get_tree().physics_frame
	_verdict(wiz.silenced() and wiz.is_muted(), "whoever stands in a ring of Silence is silenced")
	wiz.global_position += Vector2(600.0, 0.0)
	await get_tree().physics_frame
	_verdict(not wiz.silenced(), "and is not once they have stepped out")

	var seer: Wizard = world.player
	seer.ledger = Ledger.of(["Ignite"])  # (the waiting room's book holds everything; this one holds almost nothing)
	seer.ledger.learn("chant:scrying")
	world._on_ritual_finished("scrying", 1.0, false)
	await get_tree().process_frame
	var shown := get_tree().get_nodes_in_group("scryings")
	_verdict(shown.size() == 1 and shown[0].target is PagePickup, "the Chant of Scrying points to a page")
	if shown.size() == 1:
		var near: PagePickup = Scrying.nearest_unread(get_tree(), seer.center(), seer.ledger)
		_verdict(near == shown[0].target, "the page it points to is the nearest one not yet read")
		seer.ledger.learn(near.page)
		await get_tree().process_frame
		await get_tree().process_frame
		_verdict(get_tree().get_nodes_in_group("scryings").is_empty() or get_tree().get_nodes_in_group("scryings")[0].is_queued_for_deletion(), "and the arrow goes once that page is read")

	var fought := false
	var fled := false
	for trial in 12:
		victim.rage_time = 0.0
		victim.fear_time = 0.0
		victim.last_spell = ""
		victim.stamina = victim.max_stamina
		var stir := FightOrFlight.new()
		stir.target = victim
		stir.caster = wiz
		world.add_child(stir)
		await get_tree().physics_frame
		if victim.rage_time > 0.0:
			fought = true
			for k in 90:
				await get_tree().physics_frame
			_verdict(victim.last_spell != "" or victim.stamina < victim.max_stamina, "someone made to fight casts spells of their own accord (%s)" % victim.last_spell)
		elif victim.fear_time > 0.0 and victim.afraid_of == wiz:
			fled = true
		stir.queue_free()
		if fought and fled:
			break
	_verdict(fought and fled, "Fight or Flight sends them one way or the other by chance (fought %s, fled %s)" % [fought, fled])
	victim.rage_time = 0.0
	victim.fear_time = 0.0

	var geyser := Geyser.new()
	world.add_child(geyser)
	geyser.global_position = wiz.global_position + Vector2(-900.0, 0.0)
	for k in int((Geyser.WARNING + 0.3) * 60.0):
		await get_tree().physics_frame
	var fireball := Projectile.new()
	world.add_child(fireball)
	fireball.setup("Ignite", geyser.global_position + Vector2(0.0, -60.0), 0.0)
	fireball.global_position = geyser.global_position + Vector2(0.0, -60.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_verdict(not is_instance_valid(fireball) or fireball.is_queued_for_deletion(), "a fireball that flies into a rising Geyser goes out")
	geyser.queue_free()

	wiz.fade_from_sight(5.0)
	for k in 3:
		await get_tree().physics_frame
	_verdict(wiz.is_faded() and wiz.get_node("Look").modulate.a < 0.5, "Sneak leaves the wizard faint")
	wiz.fade_time = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	_verdict(not wiz.is_faded() and wiz.get_node("Look").modulate.a > 0.9, "and the wizard shows again when it ends")

	var mark := HuntersMark.new()
	mark.caster = world.player
	world.add_child(mark)
	await get_tree().process_frame
	var prey: Wizard = HuntersMark.nearest_other(get_tree(), world.player.center(), world.player)
	_verdict(prey != null and mark.target == prey and prey != world.player, "Hunter's Mark points to the nearest other wizard")
	mark.queue_free()

	print("the spells meet as they should" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

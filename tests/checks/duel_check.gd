extends Check
## The Duel: a small room, the person and one AI wizard each dealt a starting book as a match deals it, the AI waking after a moment and fighting, every round
## written down (DuelLog), and a new round, with new books, once one of them falls.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/duel_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.


func _ready() -> void:
	Duel.wins = 0
	Duel.losses = 0
	Duel.round_number = 0
	DuelLog.folder = "user://duel_logs_check"
	await get_tree().process_frame
	get_tree().current_scene = null  # (this check stays where it is, above the room, while the room is changed under it)
	get_tree().change_scene_to_file("res://scenes/duel.tscn")
	await _frames(20)
	var duel: Duel = get_tree().current_scene
	_verdict(duel != null, "the duel room opens")
	if duel == null:
		get_tree().quit(1)
		return
	var room_width := (ArenaGen.right_wall - ArenaGen.FIRST_COL) * ArenaGen.TILE
	_verdict(room_width <= 1100, "the room is about a screen wide (%d px)" % room_width)
	var rival := duel.rival
	_verdict(is_instance_valid(rival) and rival.brain is WizardBrain, "there is one AI wizard")
	var spells := func(w: Wizard) -> Array: return w.ledger.pages.keys().filter(func(p: String) -> bool: return SpellData.SPELLS.has(p))
	_verdict(spells.call(duel.player).size() == 10 and spells.call(rival).size() == 10, "each is dealt ten spells (%s / %s)" % [spells.call(duel.player), spells.call(rival)])
	_verdict(rival.brain.dormant, "the AI waits a moment at first")
	var first_book: Array = spells.call(duel.player)
	duel.player.infinite_time = 1.0e6
	duel.player.max_stamina = 1.0e6  # (the person stands still: it must not end the round)
	duel.player.stamina = 1.0e6
	var cast := [false]  # (a lambda keeps its own copy of a plain local: the array is shared)
	rival.ensure_caster().cast_resolved.connect(func(_s: String, _t: String, _o: Vector2, _a: float, _i: Dictionary) -> void: cast[0] = true)
	for k in 60 * 25:
		await get_tree().physics_frame
		if cast[0]:
			break
	_verdict(not rival.brain.dormant and cast[0], "then it fights")
	await get_tree().create_timer(1.5).timeout  # (the log is flushed every second)
	var folder := DirAccess.open(DuelLog.folder)
	var newest := ""
	if folder != null:
		for name in folder.get_files():
			if name > newest:
				newest = name
	var text := FileAccess.get_file_as_string(DuelLog.folder + "/" + newest) if newest != "" else ""
	_verdict(text.begins_with("0.00 ROUND 1") and "\n" in text and " P person " in text and " P ai " in text and " C ai " in text, "the round is written down (%s)" % newest)
	# Run dry, it stops casting and stands until its stamina is back. (A stroke already begun is finished, as a person's would be: the test waits for a free hand.)
	for k in 120:
		if not rival.pen.active() and rival.brain.react <= 0.0:
			break
		await get_tree().physics_frame
	rival.stamina = 20.0
	var dry_casts := [0]
	var dry_from := [Engine.get_physics_frames()]  # (a spell whose stroke was already finished goes off a moment later: that one is not counted)
	rival.ensure_caster().cast_resolved.connect(func(spell: String, _t: String, _o: Vector2, _a: float, _i: Dictionary) -> void:
		if spell in Pages.RANGED and Engine.get_physics_frames() - dry_from[0] > 18:
			dry_casts[0] += 1)  # (attacks: Adrenaline, the spell for being worn out, and a shield against a shot coming are still cast)
	for k in 150:  # (the person is kept well away from it: someone who stands on top of it is thrown off whatever its stamina, which is not an attack)
		var away := -1.0 if rival.global_position.x > duel.global_position.x + ArenaGen.column_x((ArenaGen.FIRST_COL + ArenaGen.right_wall) / 2) else 1.0
		duel.player.global_position.x = ArenaGen.column_x(ArenaGen.FIRST_COL + 4) if away < 0.0 else ArenaGen.column_x(ArenaGen.right_wall - 5)
		await get_tree().physics_frame
	_verdict(dry_casts[0] == 0 and rival.brain.recharging, "run dry, the AI holds its attacks and gets its stamina back (%d casts, stamina %.0f)" % [dry_casts[0], rival.stamina])
	for k in 60 * 10:  # (it stands only while nothing makes it move; ten seconds is plenty)
		await get_tree().physics_frame
		if not rival.brain.recharging:
			break
	_verdict(not rival.brain.recharging, "and then fights again (stamina %.0f)" % rival.stamina)
	# A wizard badly wounded feels too weak to stand and fight, whatever its book; whole, it does not.
	_verdict(rival.brain.strength >= WizardBrain.TIMID_BELOW and rival.brain.caution() == 0.0, "whole, the AI feels fit to fight, and is not careful (%.2f)" % rival.brain.strength)
	var whole_near: float = rival.brain.combat.near_limit()
	rival.max_stamina = Wizard.MAX_STAMINA * 0.36
	rival.stamina = rival.max_stamina
	await get_tree().create_timer(1.3).timeout
	_verdict(rival.brain.caution() > 0.3 and rival.brain.combat.near_limit() > whole_near + 20.0, "wounded, it grows careful and keeps farther off (threat %.2f, caution %.2f, keeps %.0f px against %.0f)" % [rival.brain.rival_threat(), rival.brain.caution(), rival.brain.combat.near_limit(), whole_near])
	rival.max_stamina = Wizard.MAX_STAMINA * 0.2
	rival.stamina = rival.max_stamina
	await get_tree().create_timer(1.3).timeout
	_verdict(rival.brain.strength < WizardBrain.TIMID_BELOW, "under a third, it gets out (%.2f)" % rival.brain.strength)
	rival.take_damage(100000, true, true)
	await get_tree().create_timer(Duel.NEXT_ROUND_IN + 1.0).timeout
	await _frames(20)
	var again: Duel = get_tree().current_scene
	_verdict(again != null and again != duel and Duel.round_number == 2 and Duel.wins == 1, "the AI falls, the round is won, and the next begins (round %d, wins %d)" % [Duel.round_number, Duel.wins])
	if again != null:
		var log2 := FileAccess.get_file_as_string(DuelLog.folder + "/" + newest)
		_verdict(log2.strip_edges().ends_with("END person"), "the first round's log says who won")
		_verdict(is_instance_valid(again.rival) and spells.call(again.player).size() == 10, "with a new book (was %s, now %s)" % [first_book, spells.call(again.player)])
	print("the duel works" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame

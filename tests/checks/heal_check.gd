extends Check
## The ways to heal (`Mending`, the chants Mending, Rest, Recovery, Stitch, Gamble, Long Rest, Second Chance and Restoration, and the spells Cauterize, Breathe, Mud Mask and
## Healing Spring): each does what its page says, every heal over time shares one allowance, only one is on a wizard at a time, a hit ends a Breathe and wakes a sleeper, moving
## ends a Rest, and a second chance turns away any death, once.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/heal_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _arena: Node
var _player: Wizard
var _rival: Wizard


func _ready() -> void:
	_arena = load("res://scenes/lab.tscn").instantiate()
	add_child(_arena)
	await _frames(6)
	_player = _arena.player
	_player.infinite_time = 0.0
	_arena.heals_wounds = false  # (the waiting room mends whoever is hurt by itself: here the heals are on their own)
	for w: Wizard in get_tree().get_nodes_in_group("wizards"):
		if w != _player:
			_rival = w
	_verdict(_rival != null, "there is a rival to try them on")
	if _rival == null:
		get_tree().quit(1)
		return
	if _rival.brain is WizardBrain:
		_rival.brain.dormant = true
	_chants_are_distinct()
	_pages()
	await _quick_chants()
	await _rest()
	await _breathe_and_mud()
	await _one_at_a_time_and_the_cap()
	await _stitch()
	await _recovery()
	await _gamble()
	await _long_rest()
	await _second_chance()
	await _cauterize()
	await _spring()
	await _bubbles()
	await _sounds()
	print("the heals work" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## A wizard worn down to this much, with nothing going on.
func _hurt(max_now: float, who: Wizard = null) -> void:
	var w: Wizard = who if who != null else _player
	w.mending.end()
	w.wake()
	w.max_stamina = max_now
	w.stamina = max_now
	w.burning_time = 0.0
	w.wet_time = 0.0
	w.set("_grace", 0.0)


func _cast(spell_name: String) -> void:
	_arena.spawn_spell(spell_name, SpellData.SPELLS[spell_name].targeting, _player.center(), 0.0, {}, _player)


func _say(id: String, power := 1.0) -> void:
	_arena.rituals.grant(_player, id, power)


func _chants_are_distinct() -> void:
	for id: String in Mending.CHANTS:
		var best := ""
		var best_acc := 0.0
		for other: String in RitualInput.RITUALS:
			var acc := RitualInput.accuracy(RitualInput.RITUALS[id]["text"], RitualInput.RITUALS[other]["text"])
			if other != id and acc > best_acc:
				best = other
				best_acc = acc
		_verdict(RitualInput.RITUALS.has(id) and best_acc < RitualInput.BACKFIRE_BELOW, "the words of %s are not taken for another chant's (nearest: %s, %.2f)" % [id, best, best_acc])
		var line := Mending.line_of(id)
		_verdict(line.begins_with("+") or line.begins_with("up to +"), "%s has a heal line: %s" % [id, line])
		_verdict(Spellbook.ritual_effect(id) != "", "%s has a line in the book" % id)


func _pages() -> void:
	for name: String in ["Cauterize", "Healing Spring", "Breathe", "Mud Mask"]:
		_verdict(SpellData.SPELLS.has(name) and SpellData.SPELLS[name].heals() and SpellData.SPELLS[name].heal_line().begins_with("+"), "%s is a spell that heals, and says how much with a plus sign" % name)
	_verdict(SpellData.SPELLS["Cauterize"].heal_line() == "+55 max stamina" and SpellData.SPELLS["Breathe"].heal_line() == "+3 max stamina/sec", "the lines are as drafted")
	_verdict(Mending.line_of("second_chance") == "+60 max stamina", "a second chance says +60 (30 percent of the greatest)")
	for page: String in Pages.HEALS:
		_verdict(Pages.every().has(page), "%s is a page" % page)


func _quick_chants() -> void:
	_hurt(100.0)
	_player.stamina = 40.0
	_say("mending")
	_verdict(is_equal_approx(_player.max_stamina, 105.0) and is_equal_approx(_player.stamina, 45.0), "Mending gives 5 at once, to the most and to what is held (%.0f / %.0f)" % [_player.max_stamina, _player.stamina])
	_hurt(100.0)
	_say("restoration", 1.0)
	_verdict(is_equal_approx(_player.max_stamina, 200.0), "Restoration said perfectly gives 120 and stops at the greatest a wizard can have (%.0f)" % _player.max_stamina)
	_hurt(40.0)
	_say("restoration", 0.5)
	_verdict(is_equal_approx(_player.max_stamina, 100.0), "and said half as well, 60 (%.0f)" % _player.max_stamina)
	_hurt(198.0)
	_say("mending")
	_verdict(_player.max_stamina == Wizard.MAX_STAMINA, "nothing mends past the greatest (%.0f)" % _player.max_stamina)


func _rest() -> void:
	_hurt(100.0)
	_player.velocity = Vector2.ZERO
	_say("rest")
	_verdict(_player.mending.is_on("rest"), "Rest begins")
	await get_tree().create_timer(2.0).timeout
	var got := _player.max_stamina - 100.0
	_verdict(got > 4.0 and got <= 6.5, "Rest mends about 3 a second while still (%.1f in 2 s)" % got)
	_player.velocity = Vector2(220.0, 0.0)
	await _frames(40)
	_verdict(not _player.mending.is_on("rest"), "and moving ends it")
	_hurt(100.0)
	_say("rest")
	_say("mending")
	_verdict(not _player.mending.is_on("rest"), "saying another chant ends a Rest too")


func _breathe_and_mud() -> void:
	_hurt(100.0)
	_cast("Breathe")
	_verdict(_player.mending.is_on("breathe"), "Breathe begins")
	await get_tree().create_timer(1.5).timeout
	var got := _player.max_stamina - 100.0
	_verdict(got > 3.0 and got < 6.0, "Breathe mends 3 a second (%.1f in 1.5 s)" % got)
	_player.take_damage(5)
	_verdict(not _player.mending.is_on("breathe"), "and a blow ends it")
	_hurt(100.0)
	_cast("Mud Mask")
	await get_tree().create_timer(1.0).timeout
	_player.take_damage(5)
	_verdict(_player.mending.is_on("mud_mask"), "a blow does not end a Mud Mask")
	await get_tree().create_timer(1.0).timeout
	_verdict(_player.max_stamina > 95.0 + 1.5, "Mud Mask goes on mending after a blow (%.1f)" % _player.max_stamina)
	_player.mending.end()


func _one_at_a_time_and_the_cap() -> void:
	_hurt(60.0)
	_player.mending.begin("rest")
	_player.mending.begin("breathe")
	_verdict(_player.mending.is_on("breathe") and not _player.mending.is_on("rest"), "a new heal over time takes the place of the old")
	_hurt(60.0)
	var took := _player.mending.pour(100.0)
	_verdict(took <= Mending.CAP + 0.01, "every heal over time draws on one allowance: at once, no more than %.0f (%.2f)" % [Mending.CAP, took])
	_player.mending.pour(100.0)  # (the allowance is spent)
	var before := _player.max_stamina
	for k in 60:  # a second of sources all pouring as hard as they like
		_player.mending.pour(50.0 / 60.0)
		await get_tree().physics_frame
	var gained := _player.max_stamina - before
	_verdict(gained <= Mending.CAP + 0.6 and gained > Mending.CAP - 1.5, "and in a second no more than that gets in (%.1f)" % gained)


func _stitch() -> void:
	_hurt(100.0)
	_say("stitch")
	_verdict(_player.mending.is_on("stitch"), "Stitch begins")
	await get_tree().create_timer(1.2).timeout  # (the allowance every heal over time shares has filled again)
	MatchStats.strike(_player)
	_rival.set("_grace", 0.0)
	_rival.take_damage(5)
	await _frames(2)
	_verdict(_rival.max_stamina < 200.0, "(the rival was struck: %.0f)" % _rival.max_stamina)
	_verdict(is_equal_approx(_player.max_stamina, 103.0), "and pays 3 for a blow landed (%.1f)" % _player.max_stamina)
	_rival.max_stamina = 200.0
	_rival.set("_grace", 0.0)
	_player.mending.end()
	var before := _player.max_stamina
	MatchStats.strike(_player)
	_rival.take_damage(5)
	_verdict(_player.max_stamina == before, "with no Stitch on, a blow pays nothing")
	_rival.max_stamina = 200.0


func _recovery() -> void:
	_hurt(200.0)
	_player.set("_grace", 0.0)
	_player.take_damage(30)
	_say("recovery")
	_verdict(is_equal_approx(_player.max_stamina, 200.0), "Recovery brings back what was just taken (%.0f)" % _player.max_stamina)
	_hurt(200.0)
	_say("recovery")
	_verdict(is_equal_approx(_player.max_stamina, 200.0), "and with nothing to bring back, it does nothing")
	_hurt(100.0)
	_player.mending.lost(90.0)
	_say("recovery")
	_verdict(is_equal_approx(_player.max_stamina, 140.0), "and never more than 40 (%.0f)" % _player.max_stamina)


func _gamble() -> void:
	var ups := 0
	var downs := 0
	for k in 400:
		_hurt(100.0)
		_say("gamble")
		if _player.max_stamina > 100.0:
			ups += 1
		elif _player.max_stamina < 100.0:
			downs += 1
	_verdict(ups + downs == 400 and ups > 270 and ups < 330, "a Gamble is won three times in four (%d of 400)" % ups)
	_hurt(20.0, _rival)
	_rival.lose_max(30.0)
	_verdict(_rival.dead, "and a lost one can kill")
	_rival.revive()
	_rival.max_stamina = 200.0


func _long_rest() -> void:
	_hurt(100.0)
	_player.burning_time = 4.0
	_player.slow_time = 4.0
	_player.root_time = 3.0
	_say("long_rest")
	_verdict(_player.asleep and _player.fainted and _player.mending.is_on("long_rest"), "Long Rest puts the wizard to sleep")
	_verdict(_player.burning_time <= 0.0 and _player.slow_time <= 0.0 and _player.root_time <= 0.0, "and takes the ills off them")
	await get_tree().create_timer(1.0).timeout
	var got := _player.max_stamina - 100.0
	_verdict(got > 8.0 and got < 14.0, "a sleeper mends about 12 a second (%.1f in 1 s)" % got)
	_player.set("_grace", 0.0)
	_player.take_damage(5)
	_verdict(not _player.asleep and not _player.fainted and not _player.mending.is_on("long_rest"), "a blow wakes them")
	_hurt(185.0)
	_say("long_rest")
	await get_tree().create_timer(1.6).timeout
	_verdict(not _player.asleep and is_equal_approx(_player.max_stamina, 200.0), "and they wake of themselves when they are whole (%.0f)" % _player.max_stamina)


func _second_chance() -> void:
	_hurt(100.0)
	_player.ledger.armed = false
	_player.velocity = Vector2.ZERO
	await _frames(40)  # (a place to stand is noted down)
	var place := _player.global_position
	_say("second_chance")
	_verdict(_player.mending.is_armed(), "a second chance is armed")
	_verdict(not _player.mending.arm(), "and only one can be armed at a time")
	_player.global_position += Vector2(900.0, 0.0)
	_player.lose_max(500.0)
	_verdict(not _player.dead, "death is turned away")
	_verdict(is_equal_approx(_player.max_stamina, 60.0) and is_equal_approx(_player.stamina, 60.0), "at 30 percent of the greatest (%.0f)" % _player.max_stamina)
	_verdict(_player.global_position.distance_to(place) < 120.0, "back at the last place they stood safely (%.0f away)" % _player.global_position.distance_to(place))
	_verdict(not _player.mending.is_armed(), "and it is used up")
	_player.take_damage(10)
	_verdict(is_equal_approx(_player.max_stamina, 60.0), "no blow lands for a moment after")
	_hurt(60.0, _rival)
	_rival.ledger.armed = true
	_rival.drown(200.0)
	_verdict(not _rival.dead, "a drowning is turned away too (it works against any way of dying)")
	_rival.revive()
	_rival.max_stamina = 200.0
	_hurt(100.0)
	_player.ledger.armed = false
	_player.lose_max(500.0)
	_verdict(_player.dead, "with none armed, death comes")
	_player.revive()
	_player.max_stamina = 100.0


func _cauterize() -> void:
	_hurt(100.0)
	_cast("Cauterize")
	_verdict(is_equal_approx(_player.max_stamina, 155.0) and _player.burning_time > 0.0, "Cauterize mends 55 at once and sets the wizard alight (%.0f, burning %.1f)" % [_player.max_stamina, _player.burning_time])
	_hurt(100.0)
	_player.wet_time = 5.0
	_cast("Cauterize")
	_verdict(is_equal_approx(_player.max_stamina, 100.0) and _player.burning_time <= 0.0, "a wet wizard is not mended and does not burn")
	_player.wet_time = 0.0


func _spring() -> void:
	_hurt(100.0)
	_player.velocity = Vector2.ZERO
	await _frames(10)
	_cast("Healing Spring")
	await _frames(4)
	var spring := HealingSpring.of(get_tree(), _player)
	_verdict(spring != null, "a Healing Spring wells up")
	if spring == null:
		return
	_player.global_position = Vector2(spring.global_position.x, spring.global_position.y - 2.0)
	_player.velocity = Vector2.ZERO
	var before := _player.max_stamina
	await get_tree().create_timer(2.0).timeout
	var got := _player.max_stamina - before
	_verdict(got > 2.5 and got < 6.0, "whoever stands in it mends about 2 a second (%.1f in 2 s)" % got)
	_verdict(_player.wet_time > 0.0, "and it is water: they are wet, by the law of waters")
	_verdict(spring.standing_in(spring.global_position) and not spring.standing_in(spring.global_position + Vector2(200.0, 0.0)) and not spring.standing_in(spring.global_position + Vector2(0.0, -200.0)), "and someone who is not in it is not mended")
	_hurt(100.0, _rival)
	_rival.global_position = Vector2(spring.global_position.x, spring.global_position.y - 2.0)
	_rival.velocity = Vector2.ZERO
	await get_tree().create_timer(1.5).timeout
	_verdict(_rival.max_stamina > 101.5, "the caster's rivals are mended by it as readily (%.1f)" % _rival.max_stamina)
	_cast("Healing Spring")
	await _frames(4)
	var count := 0
	for s: HealingSpring in get_tree().get_nodes_in_group("springs"):
		if s.caster == _player and not s.is_queued_for_deletion():
			count += 1
	_verdict(count == 1, "a wizard has one spring: a new one takes the place of the old (%d)" % count)


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame


func _bubbles() -> void:
	_hurt(100.0)
	_player.ledger.armed = false
	for spring: HealingSpring in get_tree().get_nodes_in_group("springs"):
		spring.queue_free()
	await get_tree().create_timer(0.6).timeout  # (the spring's water has stopped flowing into them)
	_player.bubbles.tick()
	_verdict(not _player.bubbles.names().has("mending") and not _player.bubbles.names().has("second_chance"), "a wizard with nothing mending them has neither bubble")
	_player.mending.begin("breathe")
	_player.bubbles.tick()
	_verdict(_player.bubbles.names().has("mending") and _player.bubbles.ring_of("mending") > 0.0, "a heal in progress shows a Mending bubble with a clock")
	_player.mending.end()
	_say("second_chance")
	_player.bubbles.tick()
	_verdict(_player.bubbles.names().has("second_chance"), "an armed second chance shows its bubble")
	_player.ledger.armed = false


func _sounds() -> void:
	Sfx.recording = true
	for spell: String in ["Cauterize", "Breathe", "Mud Mask", "Healing Spring"]:
		_hurt(100.0)
		Sfx.heard.clear()
		_cast(spell)
		await _frames(3)
		var own := spell.to_lower().replace(" ", "_") + "__mend"
		_verdict(Sfx.heard.has(own) and Sfx.has_sound(own), "%s makes its own healing sound (%s)" % [spell, own])
	_hurt(100.0)
	Sfx.heard.clear()
	_say("mending")
	_verdict(Sfx.heard.has("rituals__mend"), "a healing chant said makes the healing sound")
	Sfx.recording = false

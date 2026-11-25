extends GdUnitTestSuite
## What a spell is worth to the AI follows from the spell's own numbers: change a number and the worth moves, with nothing re-measured.


func test_damage_line_is_read_into_numbers() -> void:
	assert_float(SpellFacts.parse_damage("5 dmg + 6 dmg/sec")["direct"]).is_equal(5.0)
	assert_float(SpellFacts.parse_damage("5 dmg + 6 dmg/sec")["per_sec"]).is_equal(6.0)
	assert_float(SpellFacts.parse_damage("12 dmg/sec")["direct"]).is_equal(0.0)
	assert_float(SpellFacts.parse_damage("")["per_sec"]).is_equal(0.0)


func test_every_known_spell_has_a_damage_and_a_way_it_lands() -> void:
	assert_bool(SpellFacts.known("Frostbolt")).is_true()
	assert_bool(SpellFacts.known("Eldritch Blast")).is_true()
	assert_bool(SpellFacts.known("Firewall")).is_true()
	for spell_name: String in SpellData.SPELLS.keys():
		if SpellFacts.known(spell_name):
			assert_bool(SpellFacts.total(spell_name, 200.0) > 0.0 or SpellFacts.controls(spell_name)).is_true()


func test_a_slow_thing_is_less_likely_to_land_the_farther_off_the_rival() -> void:
	assert_bool(SpellFacts.chance("Ignite", 500.0, false, false) < SpellFacts.chance("Ignite", 150.0, false, false)).is_true()
	assert_float(SpellFacts.chance("Ignite", 500.0, true, false)).is_equal(1.0)  # a rival who is held cannot get out of the way
	assert_float(SpellFacts.chance("Eldritch Blast", 500.0, false, false)).is_equal(1.0)  # a beam arrives at once


func test_a_dearer_spell_is_worth_less_when_stamina_is_short_and_a_cost_change_moves_it() -> void:
	var plenty := SpellFacts.worth("Frostbolt", 250.0, false, false, 0.0, 1.0)
	var short := SpellFacts.worth("Frostbolt", 250.0, false, false, 1.0, 1.0)
	assert_bool(short < plenty).is_true()
	var spell: Spell = SpellData.SPELLS["Frostbolt"]
	var cost := spell.cost
	spell.cost = cost * 2.0
	var dearer := SpellFacts.worth("Frostbolt", 250.0, false, false, 1.0, 1.0)
	spell.cost = cost
	assert_bool(dearer < short).is_true()


func test_heals_are_worth_what_they_give_for_what_they_cost() -> void:
	assert_float(SpellFacts.net_heal("Cauterize", false)).is_equal(55.0 - 30.0)  # the burn it leaves takes 30 back
	assert_float(SpellFacts.net_heal("Cauterize", true)).is_equal(55.0)  # (a wet wizard does not burn, though the spell then does nothing: the AI never draws it wet)
	assert_float(SpellFacts.net_heal("Breathe", false)).is_equal(30.0)
	assert_float(SpellFacts.heal_worth("Breathe", 10.0, false)).is_equal(10.0 / SpellData.SPELLS["Breathe"].cost)  # no use in more than is missing
	assert_float(SpellFacts.heal_worth("Gust", 100.0, false)).is_equal(0.0)


func test_the_heal_figures_are_the_ones_mending_uses() -> void:
	assert_float(SpellData.SPELLS["Breathe"].span).is_equal(Mending.OVER_TIME["breathe"]["seconds"])
	assert_float(SpellData.SPELLS["Mud Mask"].span).is_equal(Mending.OVER_TIME["mud_mask"]["seconds"])
	assert_float(SpellFacts.parse_heal(SpellData.SPELLS["Breathe"].heal)["per_sec"]).is_equal(Mending.OVER_TIME["breathe"]["rate"])
	assert_float(SpellFacts.parse_heal(SpellData.SPELLS["Mud Mask"].heal)["per_sec"]).is_equal(Mending.OVER_TIME["mud_mask"]["rate"])
	assert_float(SpellFacts.parse_heal(SpellData.SPELLS["Cauterize"].heal)["at_once"]).is_equal(SelfMending.CAUTERIZE_GIVES)
	assert_float(SpellFacts.parse_heal(SpellData.SPELLS["Healing Spring"].heal)["per_sec"]).is_equal(HealingSpring.GIVES)


func test_a_volley_catches_more_of_a_near_rival_than_a_far_one() -> void:
	assert_bool(SpellFacts.total("Barbs", 80.0) > SpellFacts.total("Barbs", 400.0)).is_true()


## The figures in a spell's resource are copies of constants in its effect script. Where one can be set against the other, they must agree, or the AI would judge the spell by a number the game no longer uses.
func test_the_numbers_in_the_data_are_the_ones_the_scripts_use() -> void:
	var speeds := {"Ignite": Fireball.SPEED, "Frostbolt": IceSpear.SPEED, "Barbs": Thorn.SPEED, "Pebble": Pebble.SPEED, "Spore Puff": SporePuff.SPEED, "Flaming Sphere": FlamingSphere.SPEED}
	for spell_name: String in speeds.keys():
		assert_float(SpellData.SPELLS[spell_name].speed).override_failure_message("%s: speed in the data is not the script's" % spell_name).is_equal(float(speeds[spell_name]))
	assert_int(SpellData.SPELLS["Barbs"].pellets).is_equal(Barbs.COUNT)
	assert_float(SpellData.SPELLS["Barbs"].spread).is_equal(Barbs.FAN)
	assert_float(SpellData.SPELLS["Eldritch Blast"].reach).is_equal(EldritchBlast.RANGE)
	assert_float(SpellData.SPELLS["Jolt"].reach).is_equal(Jolt.RANGE)
	assert_float(SpellData.SPELLS["Thorn Whip"].reach).is_equal(ThornWhip.REACH)
	assert_float(SpellData.SPELLS["Hemorrhage"].span).is_equal(Hemorrhage.SECONDS)
	assert_float(SpellData.SPELLS["Scythe"].reach).is_equal(Scythe.RADIUS)
	assert_float(SpellData.SPELLS["Firewall"].warning).is_equal(Firewall.WARN)
	assert_float(SpellData.SPELLS["Firewall"].span).is_equal(Firewall.LIFE)
	assert_float(SpellData.SPELLS["Fire Breath"].span).is_equal(FireBreath.LIFE)
	# the damage text against the script's blows
	var per_sec := func(spell_name: String) -> float: return SpellFacts.parse_damage(SpellData.SPELLS[spell_name].damage)["per_sec"]
	var direct := func(spell_name: String) -> float: return SpellFacts.parse_damage(SpellData.SPELLS[spell_name].damage)["direct"]
	assert_float(direct.call("Ignite")).is_equal(float(Fireball.HARM))
	assert_float(direct.call("Frostbolt")).is_equal(float(IceSpear.HARM))
	assert_float(direct.call("Barbs")).is_equal(float(Thorn.HARM))
	assert_float(direct.call("Pebble")).is_equal(float(Pebble.HARM))
	assert_float(direct.call("Eldritch Blast")).is_equal(float(EldritchBlast.HARM))
	assert_float(direct.call("Jolt")).is_equal(float(Jolt.HARM))
	assert_float(direct.call("Scythe")).is_equal(float(Scythe.HARM))
	assert_float(direct.call("Spark")).is_equal(float(SparkStrike.DAMAGE))
	assert_float(direct.call("Thorn Whip")).is_equal(float(ThornWhip.HARM))
	assert_float(per_sec.call("Spore Puff")).is_equal(float(SporePuff.DAMAGE) / SporePuff.TICK)
	assert_float(per_sec.call("Stalagmite")).is_equal(float(Stalagmite.DAMAGE) / Stalagmite.TICK)
	assert_float(per_sec.call("Hemorrhage")).is_equal(float(Hemorrhage.HARM) / Hemorrhage.TICK)


func test_a_spell_that_holds_a_rival_is_worth_what_the_rival_could_be_made_to_take() -> void:
	var low := SpellFacts.worth("Ice Prison", 200.0, false, true, 0.0, 1.0, false, 10.0)
	var high := SpellFacts.worth("Ice Prison", 200.0, false, true, 0.0, 1.0, false, 40.0)
	assert_float(high).is_greater(low)
	assert_float(SpellFacts.worth("Ice Prison", 200.0, false, true, 0.0, 1.0, false, 0.0)).is_equal(0.0)
	# a longer hold, a spell worth more: the number is the spell's own
	var held: Spell = SpellData.SPELLS["Ice Prison"]
	var before := SpellFacts.worth("Ice Prison", 200.0, false, true, 0.5, 1.0, false, 20.0)
	held.hold *= 2.0
	var after := SpellFacts.worth("Ice Prison", 200.0, false, true, 0.5, 1.0, false, 20.0)
	held.hold /= 2.0
	assert_float(after).is_greater(before)


func test_the_hold_in_the_data_is_the_one_the_scripts_use() -> void:
	assert_float(SpellData.SPELLS["Ice Prison"].hold).is_equal(IcePrison.FREEZE_SECONDS)
	assert_float(SpellData.SPELLS["Faint"].hold).is_equal(Wizard.FAINT_TIME)
	assert_float(SpellData.SPELLS["Silence"].hold).is_equal(Silence.LIFE)
	assert_float(SpellData.SPELLS["Thunderclap"].hold).is_equal(Thunderclap.DAZE)
	assert_float(SpellData.SPELLS["Fight or Flight"].hold).is_equal(FightOrFlight.SECONDS)
	assert_float(SpellData.SPELLS["Flytrap"].hold).is_equal(Flytrap.HOLD_SECONDS)
	assert_float(SpellData.SPELLS["Sinkhole"].warning).is_equal(Sinkhole.WARNING)


func test_the_damage_a_second_is_the_best_of_what_is_open() -> void:
	var rate := SpellFacts.damage_rate(["Ignite", "Ice Prison", "Spark"], 200.0)
	assert_float(rate).is_greater(0.0)
	assert_float(SpellFacts.damage_rate(["Ice Prison", "Faint"], 200.0)).is_equal(0.0)


func test_a_defense_is_worth_the_harm_it_takes_away() -> void:
	assert_bool(SpellFacts.defends("Crimson Veil") and SpellFacts.defends("Obsidian Armor") and SpellFacts.defends("Decoy")).is_true()
	assert_bool(SpellFacts.defends("Ignite")).is_false()
	var calm := SpellFacts.defense_worth("Obsidian Armor", 2.0, 14.0, 0.0, 1.0)
	var hard := SpellFacts.defense_worth("Obsidian Armor", 12.0, 14.0, 0.0, 1.0)
	assert_float(hard).is_greater(calm)
	# a dearer shield is worth less once stamina is short
	var shield: Spell = SpellData.SPELLS["Crimson Veil"]
	var before := SpellFacts.defense_worth("Crimson Veil", 6.0, 14.0, 1.0, 1.0)
	shield.cost *= 2.0
	var after := SpellFacts.defense_worth("Crimson Veil", 6.0, 14.0, 1.0, 1.0)
	shield.cost /= 2.0
	assert_float(after).is_less(before)


func test_the_defense_figures_are_the_scripts() -> void:
	assert_int(SpellData.SPELLS["Crimson Veil"].blows).is_equal(Wizard.VEIL_BLOWS)
	assert_float(SpellData.SPELLS["Obsidian Armor"].lasts).is_equal(Wizard.OBSIDIAN_SECONDS)
	assert_float(SpellData.SPELLS["Obsidian Armor"].absorbs).is_equal(1.0 - Wizard.OBSIDIAN_SHOTS)
	assert_float(SpellData.SPELLS["Decoy"].lasts).is_equal(Decoy.SECONDS)
	assert_float(SpellData.SPELLS["Headwind"].lasts).is_equal(Headwind.SECONDS)


func test_the_cheapest_way_is_taken_first() -> void:
	var order := SpellFacts.cheapest_first(["Shadow Step", "chant:double_jump", "Obsidian Armor"])
	assert_str(order[0]).is_equal("chant:double_jump")  # costs no stamina
	var costs := []
	for name: String in SpellFacts.cheapest_first(WizardBrain.WAYS["wall"]):
		costs.append(SpellData.SPELLS[name].cost)
	var sorted := costs.duplicate()
	sorted.sort()
	assert_array(costs).is_equal(sorted)
	# a change of cost changes the order
	var dear: Spell = SpellData.SPELLS["Geyser"]
	var before: String = SpellFacts.cheapest_first(["Geyser", "Push"]).front()
	dear.cost += 100.0
	var after: String = SpellFacts.cheapest_first(["Geyser", "Push"]).front()
	dear.cost -= 100.0
	assert_str(after).is_equal("Push")
	assert_str(before).is_not_equal("")


func test_a_wizard_nearly_spent_can_deal_little_however_strong_its_book() -> void:
	var book := ["Spark", "Ignite", "Pebble"]
	var plenty := SpellFacts.damage_rate(book, 250.0)
	assert_float(SpellFacts.damage_rate(book, 250.0, 200.0, 4.0)).is_equal_approx(plenty, 0.01)  # (plenty to pay for the best of them: the flat figure)
	assert_bool(SpellFacts.damage_rate(book, 250.0, 20.0, 4.0) < plenty * 0.6).is_true()
	assert_float(SpellFacts.damage_rate(book, 250.0, 0.0, 4.0)).is_equal(0.0)


func test_a_hold_is_worth_less_to_a_wizard_who_cannot_afford_to_follow_it() -> void:
	var book := ["Spark", "Ignite"]
	var rich := SpellFacts.control_value("Ice Prison", SpellFacts.damage_rate(book, 250.0, 150.0, SpellData.SPELLS["Ice Prison"].hold))
	var poor := SpellFacts.control_value("Ice Prison", SpellFacts.damage_rate(book, 250.0, 10.0, SpellData.SPELLS["Ice Prison"].hold))
	assert_bool(poor < rich * 0.5).is_true()


func test_a_spell_that_can_do_next_to_nothing_is_below_the_floor() -> void:
	assert_bool(SpellFacts.expected_harm("Tornado", 300.0, false, false, false, 0.0) < SpellFacts.MIN_EXPECTED).is_true()  # (a whirlwind and no way to follow it)
	assert_bool(SpellFacts.expected_harm("Ignite", 300.0, false, false, false, 0.0) > SpellFacts.MIN_EXPECTED).is_true()
	assert_bool(SpellFacts.expected_harm("Ice Prison", 250.0, true, false, false, 20.0) < SpellFacts.MIN_EXPECTED).is_true()  # (a rival already held cannot be held again)


func test_the_worth_still_follows_the_expected_harm() -> void:
	assert_float(SpellFacts.worth("Ignite", 300.0, false, false, 0.0, 1.0)).is_equal_approx(SpellFacts.expected_harm("Ignite", 300.0, false, false), 0.001)


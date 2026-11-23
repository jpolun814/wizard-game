extends GdUnitTestSuite
## Every spell is complete data: a school, a gesture the game can draw, a description, a cost, the spellbook lines, an effect that loads.

const SCHOOLS := ["Fire", "Water", "Air", "Earth", "Flora", "Shadow", "Blood"]


func _spells() -> Array:
	return SpellData.SPELLS.values()


func _fail(spell: Spell, what: String) -> String:
	return "%s: %s" % [spell.spell_name, what]


func test_there_are_spells() -> void:
	assert_int(_spells().size()).is_greater(40)


func test_every_spell_has_a_name_a_school_and_a_description() -> void:
	for spell: Spell in _spells():
		assert_str(spell.spell_name).override_failure_message("a spell has no name").is_not_empty()
		assert_bool(spell.school in SCHOOLS).override_failure_message(_fail(spell, "unknown school " + spell.school)).is_true()
		assert_str(spell.effect).override_failure_message(_fail(spell, "no description")).is_not_empty()


func test_every_spell_has_a_positive_cost() -> void:
	for spell: Spell in _spells():
		assert_float(spell.cost).override_failure_message(_fail(spell, "cost is not positive")).is_greater(0.0)


func test_every_gesture_can_be_drawn() -> void:
	for spell: Spell in _spells():
		assert_str(spell.gesture).override_failure_message(_fail(spell, "no gesture")).is_not_empty()
		var shown := GestureTemplates.preview_points(spell.gesture)
		assert_bool(shown.size() >= 2).override_failure_message(_fail(spell, "gesture " + spell.gesture + " has no preview to draw")).is_true()


func test_every_effect_script_exists_and_loads() -> void:
	for spell: Spell in _spells():
		if spell.effect_path != "":
			assert_bool(ResourceLoader.exists(spell.effect_path)).override_failure_message(_fail(spell, "effect missing: " + spell.effect_path)).is_true()
			assert_object(load(spell.effect_path)).override_failure_message(_fail(spell, "effect does not load")).is_not_null()


func test_the_cost_line_is_a_figure_and_a_unit() -> void:
	for spell: Spell in _spells():
		var line := spell.cost_line()
		assert_bool(line.ends_with("stamina")).override_failure_message(_fail(spell, "cost line " + line)).is_true()
		assert_bool(line.substr(0, 1).is_valid_int()).override_failure_message(_fail(spell, "cost line " + line)).is_true()
		var span := spell.cost_span()
		assert_bool(span.x <= span.y).override_failure_message(_fail(spell, "cost range backwards")).is_true()


func test_only_necromancy_is_paid_in_maximum_stamina() -> void:
	for spell: Spell in _spells():
		assert_bool(spell.cost_line().contains("max") == (spell.school == "Blood")).override_failure_message(_fail(spell, "max stamina mismatch")).is_true()


func test_the_damage_line_is_a_figure_or_nothing() -> void:
	for spell: Spell in _spells():
		var line := spell.damage_line()
		if line != "" and line != "Kills":  # (the snail kills at a touch)
			assert_bool(line.substr(0, 1).is_valid_int() and line.contains("dmg")).override_failure_message(_fail(spell, "damage line " + line)).is_true()


func test_the_states_a_spell_names_are_states_the_game_has() -> void:
	var names := StatusBubbles.NAMES.keys()
	for spell: Spell in _spells():
		for state in spell.applies + spell.removes:
			assert_bool(state in names).override_failure_message(_fail(spell, "unknown state " + state)).is_true()


func test_descriptions_have_no_team_words_or_british_spelling() -> void:
	var banned := ["foe", "enemy", "enemies", "ally", "allies", "rival", "opponent", "colour", "grey", "favourite", "centre"]
	for spell: Spell in _spells():
		var words := spell.effect.to_lower().replace(".", " ").replace(",", " ").replace(":", " ").split(" ", false)
		for word: String in banned:
			assert_bool(word in words).override_failure_message(_fail(spell, "uses the word " + word)).is_false()

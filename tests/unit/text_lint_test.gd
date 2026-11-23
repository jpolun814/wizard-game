extends GdUnitTestSuite
## The owner's wording rules (CLAUDE.md, section 0) as checks on every line a player reads that is written as data: a spell's description, a chant's line and name,
## a state's name and tooltip. A new spell or state is held to them the day it is added.

const TEAM_WORDS := ["foe", "foes", "enemy", "enemies", "ally", "allies", "rival", "rivals", "opponent", "opponents", "your team", "teammate"]
const BRITISH := ["colour", "colours", "favourite", "grey", "centre", "armour", "honour", "behaviour", "neighbour", "metre", "defence", "licence", "travelled", "cancelled", "ageing", "manoeuvre", "analyse", "realise", "recognise"]
const VAGUE_TIME := ["for a while", "for a little while"]
const KEYS := ["tab", "enter", "mouse", "click", "button", "keyboard", "press "]


func _words(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var word := ""
	for ch in text.to_lower():
		if (ch >= "a" and ch <= "z") or ch == "'":
			word += ch
		elif word != "":
			out.append(word)
			word = ""
	if word != "":
		out.append(word)
	return out


func _spell_lines() -> Dictionary:
	var out := {}
	for spell: Spell in SpellData.SPELLS.values():
		out["spell " + spell.spell_name] = spell.effect
	return out


func _chant_lines() -> Dictionary:
	var out := {}
	for id: String in RitualInput.RITUALS:
		out["chant " + id] = Spellbook.ritual_effect(id)
	return out


func _tips() -> Dictionary:
	var out := {}
	for id: String in StatusBubbles.TIPS:
		out["tip " + id] = StatusBubbles.TIPS[id]
	return out


func _all() -> Dictionary:
	var out := _spell_lines()
	out.merge(_chant_lines())
	out.merge(_tips())
	return out


func test_there_are_lines_to_check() -> void:
	assert_int(_spell_lines().size()).is_greater(40)
	assert_int(_chant_lines().size()).is_greater(5)
	assert_int(_tips().size()).is_greater(15)


func test_no_line_is_empty() -> void:
	for key: String in _all():
		assert_str(_all()[key]).override_failure_message("%s is empty" % key).is_not_empty()


func test_no_figures_in_tooltips() -> void:
	# Owner, 2026-11-23: a book description now says what happens, with its durations, so it may hold a number. A state's tooltip still gives none.
	for key: String in _tips():
		var text: String = _tips()[key]
		for ch in text:
			assert_bool(ch >= "0" and ch <= "9").override_failure_message("%s has a figure: %s" % [key, text]).is_false()


func test_no_team_words() -> void:
	for key: String in _all():
		var words := _words(_all()[key])
		var lowered: String = _all()[key].to_lower()
		for bad: String in TEAM_WORDS:
			var found := (" " in bad and bad in lowered) or (not " " in bad and bad in words)
			assert_bool(found).override_failure_message("%s uses the team word '%s': %s" % [key, bad, _all()[key]]).is_false()


func test_american_spelling() -> void:
	for key: String in _all():
		var words := _words(_all()[key])
		for bad: String in BRITISH:
			assert_bool(bad in words).override_failure_message("%s is spelled the British way ('%s'): %s" % [key, bad, _all()[key]]).is_false()


func test_no_vague_durations() -> void:
	for key: String in _all():
		for bad: String in VAGUE_TIME:
			assert_bool(bad in _all()[key].to_lower()).override_failure_message("%s says '%s': %s" % [key, bad, _all()[key]]).is_false()


func test_a_book_line_never_names_keys_or_buttons() -> void:
	for key: String in _spell_lines():
		var words := _words(_spell_lines()[key])
		for bad: String in KEYS:
			assert_bool(bad.strip_edges() in words).override_failure_message("%s names an interface thing '%s': %s" % [key, bad, _spell_lines()[key]]).is_false()
	for key: String in _chant_lines():
		for bad: String in KEYS:
			assert_bool(bad.strip_edges() in _words(_chant_lines()[key])).override_failure_message("%s names an interface thing '%s'" % [key, bad]).is_false()


func test_descriptions_are_sentences_that_end_in_a_stop() -> void:
	for key: String in _spell_lines():
		var text: String = _spell_lines()[key]
		assert_bool(text.ends_with(".") or text.ends_with("!") or text.ends_with("?")).override_failure_message("%s does not end like a sentence: %s" % [key, text]).is_true()
		assert_bool(text.length() <= 150).override_failure_message("%s is long (%d characters): %s" % [key, text.length(), text]).is_true()
	for key: String in _chant_lines():
		assert_bool(_chant_lines()[key].ends_with(".")).override_failure_message("%s does not end in a stop" % key).is_true()


func test_a_description_is_not_shouted() -> void:
	for key: String in _spell_lines():
		var text: String = _spell_lines()[key]
		assert_bool(text == text.to_upper() and text.length() > 3).override_failure_message("%s is in capitals: %s" % [key, text]).is_false()


func test_tooltips_are_short_fragments_with_no_full_stop_and_no_advice() -> void:
	for id: String in StatusBubbles.TIPS:
		for line: String in StatusBubbles.TIPS[id].split("\n"):
			assert_bool(line.ends_with(".")).override_failure_message("tooltip %s ends a line with a full stop: %s" % [id, line]).is_false()
			assert_bool(" to counter" in line.to_lower() or "counter " in line.to_lower() or "use " in line.to_lower().left(4)).override_failure_message("tooltip %s tells the reader what to cast: %s" % [id, line]).is_false()


func test_every_chant_has_a_name_and_words_a_person_can_type() -> void:
	var seen := {}
	for id: String in RitualInput.RITUALS:
		var r: Dictionary = RitualInput.RITUALS[id]
		assert_str(r["name"]).override_failure_message("chant %s has no name" % id).is_not_empty()
		var text: String = r["text"]
		for ch in text:
			assert_bool((ch >= "a" and ch <= "z") or ch == " ").override_failure_message("chant %s has a character that cannot be typed plainly: '%s' in '%s'" % [id, ch, text]).is_true()
		assert_bool(seen.has(text)).override_failure_message("chant %s repeats the words of %s" % [id, seen.get(text, "")]).is_false()
		seen[text] = id

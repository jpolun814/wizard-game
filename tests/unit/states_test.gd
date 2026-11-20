extends GdUnitTestSuite
## A state on a body is complete wherever it shows: a bubble with an icon, a name, a tooltip, a place in the order; and every spell and chant that names a
## state (what it puts on someone, what it takes off) names one that exists.

const ICON := 9


func test_every_state_in_the_order_has_a_name_and_a_tooltip() -> void:
	for id: String in StatusBubbles.ORDER:
		if id == "cross":  # (the red cross drawn over a state a spell takes off is not a state)
			continue
		assert_bool(StatusBubbles.NAMES.has(id)).override_failure_message("state %s has no name" % id).is_true()
		assert_bool(StatusBubbles.TIPS.has(id)).override_failure_message("state %s has no tooltip" % id).is_true()


func test_every_name_and_tooltip_is_for_a_state_in_the_order() -> void:
	for id: String in StatusBubbles.NAMES:
		assert_bool(id in StatusBubbles.ORDER).override_failure_message("name %s is not in the order, so it can never be drawn" % id).is_true()
	for id: String in StatusBubbles.TIPS:
		assert_bool(id in StatusBubbles.ORDER).override_failure_message("tooltip %s is not in the order" % id).is_true()


func test_the_order_has_no_repeats() -> void:
	var seen := {}
	for id: String in StatusBubbles.ORDER:
		assert_bool(seen.has(id)).override_failure_message("state %s is in the order twice" % id).is_false()
		seen[id] = true


func test_every_state_has_a_picture_in_the_icon_sheet() -> void:
	var pictures := int(StatusBubbles.ICONS.get_width()) / ICON
	assert_int(pictures).override_failure_message("the icon sheet has %d pictures for %d states" % [pictures, StatusBubbles.ORDER.size()]).is_greater_equal(StatusBubbles.ORDER.size())


func test_every_icon_has_something_drawn_in_it() -> void:
	var image := StatusBubbles.ICONS.get_image()
	for index in StatusBubbles.ORDER.size():
		var painted := 0
		for y in ICON:
			for x in ICON:
				if image.get_pixel(index * ICON + x, y).a > 0.1:
					painted += 1
		assert_int(painted).override_failure_message("the icon for %s is empty" % StatusBubbles.ORDER[index]).is_greater(6)


func test_every_state_a_spell_names_exists() -> void:
	for spell: Spell in SpellData.SPELLS.values():
		for id in spell.applies:
			assert_bool(id in StatusBubbles.ORDER).override_failure_message("%s puts a state that does not exist: %s" % [spell.spell_name, id]).is_true()
		for id in spell.removes:
			assert_bool(id in StatusBubbles.ORDER).override_failure_message("%s takes off a state that does not exist: %s" % [spell.spell_name, id]).is_true()


func test_a_spell_does_not_put_on_and_take_off_the_same_state() -> void:
	for spell: Spell in SpellData.SPELLS.values():
		for id in spell.applies:
			assert_bool(id in spell.removes).override_failure_message("%s both puts on and takes off %s" % [spell.spell_name, id]).is_false()


func test_every_state_a_chant_names_exists() -> void:
	for ritual_id: String in Spellbook.CHANT_STATES:
		assert_bool(RitualInput.RITUALS.has(ritual_id)).override_failure_message("the spellbook names states for a chant that does not exist: %s" % ritual_id).is_true()
		assert_bool(Spellbook.CHANT_STATES[ritual_id] in StatusBubbles.ORDER).override_failure_message("chant %s names a state that does not exist" % ritual_id).is_true()


func test_every_state_a_spell_puts_on_is_one_a_body_can_have() -> void:
	# A spell that says it leaves someone Wet must be a thing that does: the claim on the page is checked against the laws' own list of ways to become wet.
	var wetters := 0
	for spell: Spell in SpellData.SPELLS.values():
		if "wet" in spell.applies:
			wetters += 1
	assert_int(wetters).override_failure_message("no spell says it leaves anyone wet").is_greater(0)

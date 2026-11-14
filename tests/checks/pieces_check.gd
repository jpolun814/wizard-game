extends Check
## Small pieces the bigger checks lean on: the four words that name a world, and the table of spells and the buttons that cast them.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/pieces_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.



func _ready() -> void:
	_names_of_worlds()
	_spell_table()
	print("the pieces hold" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _names_of_worlds() -> void:
	var every := true
	for k in 600:
		var value := k * 7919 % Incantation.seed_count()
		every = every and Incantation.seed_of(Incantation.words_for(value)) == value
	_verdict(every, "a world's four words give back its seed, for any seed")
	var words := Incantation.words_for(12345)
	_verdict(Incantation.is_world_name(words) and Incantation.is_world_name("  " + words.to_upper() + " "), "four known words, in any case, are a world's name")
	_verdict(not Incantation.is_world_name("") and not Incantation.is_world_name("one two") and not Incantation.is_world_name(words + " " + words), "other words are not")
	_verdict(not Incantation.is_world_name("xxxx yyyy zzzz wwww"), "four words that are not known are not")
	var hashed := Incantation.seed_of("any other text")
	_verdict(hashed == Incantation.seed_of("Any Other Text ") and hashed >= 0 and hashed < Incantation.seed_count(), "any other text makes the same seed each time, within range")
	var blank := Incantation.seed_of("   ")
	_verdict(blank >= 0 and blank < Incantation.seed_count(), "blank text makes some seed within range")


func _spell_table() -> void:
	_verdict(SpellData.width_of(PackedVector2Array([Vector2(10, 5), Vector2(-20, 9), Vector2(40, 0)])) == 60.0 and SpellData.width_of(PackedVector2Array()) == 0.0, "the width of a drawn line is its horizontal span")
	_verdict(SpellData.button_name(SpellData.LEFT) == "Left" and SpellData.button_name(SpellData.LEFT | SpellData.RIGHT) == "Left + Right" and SpellData.button_name(7) == "Left + Middle + Right", "buttons are named for the book")
	var table := SpellData.bindings()
	var all_found := true
	var lost := ""
	for spell_name: String in SpellData.SPELLS:
		var spell: Spell = SpellData.SPELLS[spell_name]
		var entry: Dictionary = table.get(spell.buttons, {}).get(spell.gesture, {})
		if entry.get("spell", "") != spell_name:
			all_found = false
			lost = spell_name
	_verdict(all_found, "every spell is found by its buttons and its shape (%s)" % ("none lost" if lost == "" else lost + " is not"))
	var colors := true
	for school: String in SpellData.SCHOOL_BUTTONS:
		colors = colors and SpellData.SCHOOL_COLORS.has(school)
	_verdict(colors, "every school has a color")


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame



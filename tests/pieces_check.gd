extends Node

## Small pieces the bigger checks lean on: the four words that name a world, the table of spells and the buttons that cast them, and a
## fireball called down onto the ground, which hurts whoever stands where it lands and no one else.
##
##     godot --headless --fixed-fps 60 --path . tests/pieces_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	_names_of_worlds()
	_spell_table()
	await _falling_shot()
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
	var colours := true
	for school: String in SpellData.SCHOOL_BUTTONS:
		colours = colours and SpellData.SCHOOL_COLORS.has(school)
	_verdict(colours, "every school has a colour")


func _falling_shot() -> void:
	var arena: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(arena)
	await _frames(4)
	var player: Wizard = arena.player
	player.infinite_time = 0.0
	arena._since_hurt = -100000.0
	var health: float = player.max_stamina
	var far := FallingShot.call_down(arena, player.global_position + Vector2(600.0, 0.0), Color.ORANGE, 8)
	await _frames(int((FallingShot.WARNING + FallingShot.FALL) * 60.0) + 8)
	_verdict(player.max_stamina == health, "a fireball that lands far from a wizard leaves them be")
	var shot := FallingShot.call_down(arena, player.global_position, Color.ORANGE, 8)
	_verdict(shot.danger_at(shot.global_position) and not shot.danger_at(shot.global_position + Vector2(300.0, 0.0)), "its mark warns of where it will land, and only there")
	await _frames(int((FallingShot.WARNING + FallingShot.FALL) * 60.0) - 20)
	_verdict(player.max_stamina == health, "it does nothing while it is still falling")
	await _frames(40)
	_verdict(player.max_stamina < health, "it hurts the wizard it lands on (%d to %d)" % [health, player.max_stamina])
	_verdict(not is_instance_valid(shot) or shot.is_queued_for_deletion(), "and is spent")
	if is_instance_valid(far):
		far.queue_free()
	arena.queue_free()


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

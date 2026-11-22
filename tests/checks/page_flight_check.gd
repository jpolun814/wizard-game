extends Check
## Reading pages. The tutorial's first pages say "Press Tab to read" from afar; a page that is read flies to the reader, one at a time, and its name rises beside them in
## its school's color (so does each page of a fallen wizard's book); the book stays shut. A spell cast with too little stamina says so, plainly, and the
## stamina bar flares. The open book says the arrow keys turn its pages.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/page_flight_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.


func _ready() -> void:
	var room: Tutorial = load("res://scenes/tutorial.tscn").instantiate()
	add_child(room)
	for k in 90:
		await get_tree().physics_frame
	var player: Wizard = room.player
	var pages: Array = get_tree().get_nodes_in_group("pages")
	pages.sort_custom(func(a: PagePickup, b: PagePickup) -> bool: return a.global_position.x < b.global_position.x)
	var first: PagePickup = pages[0]
	var second: PagePickup = pages[1]
	_verdict(first.always_hint and not second.always_hint, "the first pages of the tutorial say what to press, and the others do not")
	_verdict(not first.is_underfoot() and first._hint.visible and "Tab" in first._hint.text, "from afar: %s" % first._hint.text)
	_verdict(not second._hint.visible, "and a page elsewhere says it only to someone standing under it")
	# Reading a fan of three: the pages fly one at a time, and each name rises in its school's color.
	var count := first.new_pages(player.ledger).size()
	_verdict(count == 3, "the first place holds three pages")
	var names: Array[String] = first.new_pages(player.ledger)
	room.read_page(first, player)
	await get_tree().physics_frame
	var flights := room.get_children().filter(func(n: Node) -> bool: return n is PageFlight)
	_verdict(flights.size() == 1, "reading sends the pages flying (%d flights)" % flights.size())
	_verdict(player.ledger.knows_spell(names[0]), "and the book has them at once")
	await get_tree().create_timer(PageFlight.FLIGHT + 0.1).timeout
	var seen := _words(room)
	_verdict(seen.size() == 1 and seen[0].text == Pages.title_of(names[0]), "the first page has arrived and its name has risen (%d shown)" % seen.size())
	_verdict(seen.size() == 1 and seen[0].get_theme_color("font_color").is_equal_approx(PageFlight.color_of(names[0]).lightened(0.25)), "in the color of its school")
	var every := {}
	for k in 100:  # (each name floats up and goes: they are all counted as they come)
		await get_tree().physics_frame
		for label: Label in _words(room):
			every[label.text] = true
	_verdict(every.size() == 3 and names.all(func(n: String) -> bool: return every.has(Pages.title_of(n))), "all three names have risen, one after another (%s)" % ", ".join(every.keys()))
	await get_tree().create_timer(0.3).timeout
	_verdict(not room.spellbook.visible, "and the book does not open over the words (a page already read still opens it)")
	room.spellbook.show_page(names[0])
	await get_tree().create_timer(0.3).timeout
	# The open book says how to turn its pages.
	room.spellbook._ever_turned = false
	await get_tree().physics_frame
	await get_tree().process_frame
	_verdict(room.spellbook._turn_hint.visible and "arrow" in room.spellbook._turn_hint.text, "the open book says the arrow keys turn the pages")
	_verdict(room.spellbook._turn_arrows[1].visible and not room.spellbook._turn_arrows[0].visible, "with an arrow only toward a page there is to turn to")
	# Too little stamina is said plainly, and the bar flares.
	player.stamina = 1.0
	var before := _words(room).size()
	room.casting.by("Ignite", "directional", player.center(), 0.0, {}, player)
	await get_tree().physics_frame
	var plain := _words(room).filter(func(l: Label) -> bool: return l.text == "Not enough stamina")
	_verdict(plain.size() == 1 and _words(room).size() > before, "a spell with too little stamina says so")
	_verdict(room.hud.stamina_bar._alarm > 0.5, "and the stamina bar flares")
	print("the pages are read" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## The words floating in the room now.
func _words(room: Node) -> Array:
	return room.get_children().filter(func(n: Node) -> bool: return n is FloatText and not n.is_queued_for_deletion() and n.text != "" and not n.text.begins_with("-") and n.text != "Misfire")

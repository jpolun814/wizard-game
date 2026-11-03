extends SceneTree

## Checks the pages: what each wizard is dealt, that a ledger knows only what it holds, and that the waiting room's ledger holds everything.
##
## Run from the project folder:
##     godot --headless -s tests/test_pages.gd
## It prints each failure and exits with code 1 if anything failed.

var _failures := 0
var _checks := 0


func _initialize() -> void:
	for seed_value in 200:
		var first := Pages.deal(seed_value, 4)
		var again := Pages.deal(seed_value, 4)
		_check(first.size() == 4, "seed %d: four ledgers are dealt" % seed_value)
		for k in first.size():
			_check(first[k].pages.keys() == again[k].pages.keys(), "seed %d: wizard %d is dealt the same pages twice" % [seed_value, k])
			_check(first[k].count() == 5, "seed %d: wizard %d starts with %d pages, not 5" % [seed_value, k, first[k].count()])
			_check(not first[k].everything, "seed %d: wizard %d holds everything" % [seed_value, k])
			var attacks := 0
			var moves := 0
			var defences := 0
			for page in first[k].pages:
				attacks += 1 if Pages.ATTACKS.has(page) else 0
				moves += 1 if Pages.MOVES.has(page) else 0
				defences += 1 if Pages.DEFENCES.has(page) else 0
			_check(attacks == 1 and moves == 1 and defences == 1, "seed %d: wizard %d does not start with one attack, one move and one defence" % [seed_value, k])
			for chant in Pages.CHANTS:
				_check(first[k].knows(chant), "seed %d: wizard %d lacks %s" % [seed_value, k, chant])
		# The attacks and the defences are all different between the four wizards (there are enough of them); the moves are three, so one repeats.
		var attacks_dealt := {}
		var defences_dealt := {}
		for ledger in first:
			for page in ledger.pages:
				if Pages.ATTACKS.has(page):
					attacks_dealt[page] = true
				if Pages.DEFENCES.has(page):
					defences_dealt[page] = true
		_check(attacks_dealt.size() == 4, "seed %d: the four wizards do not start with four different attacks" % seed_value)
		_check(defences_dealt.size() == 4, "seed %d: the four wizards do not start with four different defences" % seed_value)
	# A ledger knows what it holds, and learns more; one wizard's learning is not another's.
	var ledgers := Pages.deal(1, 2)
	var page := "Glowcap"
	_check(not ledgers[0].knows(page) and not ledgers[1].knows(page), "a wizard knows a page that was never found")
	ledgers[0].learn(page)
	_check(ledgers[0].knows(page) and not ledgers[1].knows(page), "learning a page taught it to someone else")
	_check(ledgers[0].knows_spell(page), "knows_spell disagrees with knows")
	ledgers[0].learn("chant:mark")
	_check(ledgers[0].knows_chant("recall") and ledgers[0].knows_chant("mark"), "the Return does not share the Mark's page")
	_check(not ledgers[1].knows_chant("recall"), "a wizard who lacks the Mark casts the Return")
	ledgers[0].settle("haste")
	ledgers[0].settle("rift")
	_check(ledgers[0].is_settled("haste") and not ledgers[0].is_settled("rift") and not ledgers[1].is_settled("haste"), "a chant that lasts is not settled for one wizard only, or a chant that does not last is")
	ledgers[0].learn_all()
	_check(ledgers[0].count() == Pages.every().size(), "learn_all does not give every page")
	# The waiting room: every page, with nothing to find.
	var room := Ledger.complete()
	_check(room.knows("Glowcap") and room.knows_chant("rift") and room.knows_chant("recall"), "the waiting room lacks a page")
	_check(room.count() == Pages.every().size(), "the waiting room's count is not every page")
	# A world lays only so many pages: more in a big world, fewer where there is little room, never fewer than the least, and a kind of gate
	# the world has always keeps a page that opens it.
	_check(Pages.count_for("underground", 1000) > Pages.count_for("ashlands", 1000), "the volcano world holds as many pages as the underground")
	_check(Pages.count_for("portals", 1000) < Pages.count_for("graveyard", 1000), "the portal world holds as many pages as a graveyard")
	_check(Pages.count_for("graveyard", 360) < Pages.count_for("graveyard", 1000) and Pages.count_for("portals", 360) >= Pages.LEAST, "a smaller world is not held to a smaller count")
	for seed_value in 100:
		var counts: Array[int] = [14, 12, 11, 8]
		var plan := Pages.allotment(seed_value, 4, counts)
		var dealt := Pages.deal(seed_value + 31, 4)
		var seen := {}
		for world: Array in plan["worlds"]:
			for lying: String in world:
				_check(not seen.has(lying), "seed %d: %s lies in two worlds" % [seed_value, lying])
				seen[lying] = true
				_check(not dealt.any(func(l: Ledger) -> bool: return l.knows(lying)), "seed %d: %s lies in a world and is dealt to a wizard" % [seed_value, lying])
		for spare_page: String in plan["spare"]:
			_check(not seen.has(spare_page), "seed %d: %s is spare and lies in a world" % [seed_value, spare_page])
		for k in counts.size():
			_check(plan["worlds"][k].size() == counts[k], "seed %d: world %d has %d pages, not %d" % [seed_value, k, plan["worlds"][k].size(), counts[k]])
		var again := Pages.allotment(seed_value, 4, counts)
		_check(again["worlds"] == plan["worlds"], "seed %d: the allotment changes between two asks" % seed_value)
		for kind in ["gas", "wall", "piranhas", "sentinel"]:
			var spare: Array[String] = []
			spare.assign(plan["spare"])
			var first: Array[String] = []
			first.assign(plan["worlds"][0])
			var kept := Pages.with_openers(first, spare, dealt, [kind])
			var wanted := Pages.openers_of(kind)
			_check(kept.size() == first.size(), "seed %d: opener swap changes the count" % seed_value)
			for kept_page in kept:
				_check(first.has(kept_page) or spare.has(kept_page), "seed %d: %s comes from nowhere" % [seed_value, kept_page])
			_check(kept.any(func(p: String) -> bool: return wanted.has(p)) or dealt.any(func(l: Ledger) -> bool: return wanted.any(func(p: String) -> bool: return l.knows(p))) or not spare.any(func(p: String) -> bool: return wanted.has(p)), "seed %d: nothing opens a %s gate" % [seed_value, kind])
	print("%d checks" % _checks)
	print("all page checks passed" if _failures == 0 else "%d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL  " + message)

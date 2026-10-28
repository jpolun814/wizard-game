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
	ledgers[0].learn_all()
	_check(ledgers[0].count() == Pages.every().size(), "learn_all does not give every page")
	# The waiting room: every page, with nothing to find.
	var room := Ledger.complete()
	_check(room.knows("Glowcap") and room.knows_chant("rift") and room.knows_chant("recall"), "the waiting room lacks a page")
	_check(room.count() == Pages.every().size(), "the waiting room's count is not every page")
	print("%d checks" % _checks)
	print("all page checks passed" if _failures == 0 else "%d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL  " + message)

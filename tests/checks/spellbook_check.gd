extends Check

## Every page of the spellbook is set properly: its writing fits the page, the damage and cost lines are at the foot (damage first, cost last, under the description),
## a chant's page is as complete, and a page not yet cast carries its NEW mark until the spell is cast. Built from the waiting room's book, where every page is known.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/spellbook_check.tscn

var _lab: Lab
var _book: Spellbook


func _ready() -> void:
	Library.use_file("user://spellbook_check.json")
	Library.clear()
	Lab.plain_room = false
	_lab = load("res://scenes/lab.tscn").instantiate()
	add_child(_lab)
	for k in 30:
		await get_tree().physics_frame
	_book = _lab.spellbook
	_book.show_page("Ignite")
	await get_tree().create_timer(1.5).timeout  # (the book falls open, and its writing is laid out only once it shows)
	var names: Array = SpellData.SPELLS.keys()
	names.sort()
	for spell_name: String in names:
		await _spell_page(spell_name)
	for id: String in RitualInput.RITUALS:
		await _chant_page(id)
	await _new_marks()
	Library.clear()
	print("%d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame


## The column the page is written in, after the book has been opened at it.
func _column_of(page: String) -> VBoxContainer:
	_book.show_page(page)
	await _frames(4)
	var index: int = _book.get("_page_of").get(page, -1)
	if index < 0:
		return null
	return _book.get("_left") if index % 2 == 0 else _book.get("_right")


func _labels(column: Node) -> Array:
	# The writing in reading order, including what sits in the foot's own rows (the lines beside a picture in the corner).
	var out := []
	for child in column.get_children():
		if child is Label:
			out.append(child)
		elif child is BoxContainer:
			out.append_array(_labels(child))
	return out


func _fits(column: VBoxContainer, what: String) -> void:
	# What a reader sees: the lowest line of writing must end above the page number (a label on the page's own area, beside the column), and none may be cut at the edge.
	var number_top: float = column.get_parent().size.y
	for sibling in column.get_parent().get_children():
		if sibling is Label:
			number_top = minf(number_top, sibling.position.y)
	var lowest := 0.0
	for child in column.get_children():
		if child is Label or child is HBoxContainer or child is TextureRect:
			lowest = maxf(lowest, child.position.y + child.size.y)
	_verdict(lowest <= number_top + 4.0, "%s: its writing ends above the page number (%.0f px, the number is at %.0f)" % [what, lowest, number_top])


func _spell_page(spell_name: String) -> void:
	var spell: Spell = SpellData.SPELLS[spell_name]
	var column := await _column_of(spell_name)
	_verdict(column != null, "%s: it has a page" % spell_name)
	if column == null:
		return
	_fits(column, spell_name)
	var texts := []
	for label: Label in _labels(column):
		texts.append(label.text)
	_verdict(spell.effect in texts, "%s: its description is on the page" % spell_name)
	_verdict(spell.cost_line() in texts, "%s: its cost line is on the page" % spell_name)
	if spell.damage_line() != "":
		_verdict(spell.damage_line() in texts, "%s: its damage line is on the page" % spell_name)
		_verdict(texts.find(spell.damage_line()) < texts.find(spell.cost_line()), "%s: damage comes before cost" % spell_name)
	_verdict(texts.find(spell.effect) < texts.find(spell.cost_line()), "%s: the description comes before the cost" % spell_name)
	_verdict(texts.find(spell.cost_line()) == texts.size() - 1 or texts.back() == "", "%s: the cost line is the last thing on the page" % spell_name)
	var badge := _has_badge(column)
	_verdict(not badge, "%s: nothing is marked NEW in the waiting room, where every page is known" % spell_name)


func _chant_page(id: String) -> void:
	var column := await _column_of("chant:" + id)
	if column == null:
		return  # (a chant with no page of its own: a toggle or an unlisted one)
	_fits(column, "chant " + id)
	var texts := []
	for label: Label in _labels(column):
		texts.append(label.text)
	_verdict(Spellbook.ritual_effect(id) in texts, "chant %s: its description is on the page" % id)
	if Spellbook.ritual_cost_line(id) != "":
		_verdict(Spellbook.ritual_cost_line(id) in texts, "chant %s: its cost line is on the page" % id)


## A spell not yet cast carries the star and "NEW!" under its name, and loses them once it has been cast.
func _new_marks() -> void:
	var ledger: Ledger = _lab.player.ledger
	var kept := ledger.everything
	ledger.everything = false
	for name in SpellData.SPELLS:
		ledger.learn(name)
	ledger.cast.clear()
	_book.refresh()
	await _frames(3)
	var column := await _column_of("Ignite")
	_verdict(_has_badge(column), "a page not yet cast carries the NEW mark")
	ledger.mark_cast("Ignite")
	_book.show_page("Ignite")
	await _frames(4)
	_verdict(not _has_badge(await _column_of("Ignite")), "and loses it once the spell has been cast")
	ledger.everything = kept


func _has_badge(column: VBoxContainer) -> bool:
	for child in column.get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				if sub is Label and "NEW" in sub.text:
					return true
	return false

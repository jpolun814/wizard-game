extends Node

## The second layout of what a trained network senses (Senses): it is the size it says, it reads the ground under the feet, water and the breath held
## in it, a shot in flight and which way it flies, rising air, and it costs little enough to be asked many times a second.
##
##     godot --headless --fixed-fps 60 --path . tests/senses_check.tscn

var _failed := 0
var _lab: Node
var _player: Wizard


func _ready() -> void:
	_lab = load("res://scenes/lab.tscn").instantiate()
	add_child(_lab)
	for k in 20:
		await get_tree().physics_frame
	_player = get_tree().get_first_node_in_group("player")
	var pond: Pond = get_tree().get_nodes_in_group("ponds")[0]
	var dry := SpellTargets.solid_below(_lab.get_world_2d(), Vector2(pond.global_position.x + pond.width + 300.0, 100.0))
	_player.global_position = dry + Vector2(0.0, -4.0)
	for k in 40:
		await get_tree().physics_frame
	var obs := _player.senses.observe()
	_verdict(obs.size() == Senses.SIZE, "the senses are the size of the layout (%d of %d)" % [obs.size(), Senses.SIZE])
	_verdict(_fine(obs, 0, 1) & Senses.SOLID != 0 and _fine(obs, 0, 1) & Senses.SEEN != 0, "the ground under the feet is solid and seen")
	_verdict(_fine(obs, 0, -1) & Senses.SOLID == 0, "the air over the head is open")
	_verdict(obs[10] == 0.0 and obs[7] == 1.0, "on dry land the wizard is not under water and has all its breath")

	# Rising air beside the wizard.
	var draft := Updraft.new()
	draft.position = dry + Vector2(96.0, -10.0)
	_lab.add_child(draft)
	for k in 5:
		await get_tree().physics_frame
	obs = _player.senses.observe()
	var lifted := false
	for dy in range(-4, 1):
		lifted = lifted or _fine(obs, 3, dy) & Senses.LIFTS != 0
	_verdict(lifted, "the column of rising air is sensed beside the wizard")
	draft.queue_free()

	# A shot the wizard throws: it is a thing, a shot, and it is seen moving the way it flies.
	_lab._spawn_marked("Ignite", "directional", _player.center(), 0.0, {"length": 90.0, "accuracy": 0.9}, _player)
	await get_tree().physics_frame  # (it soon meets something in the waiting room: it is looked at as it leaves the hand)
	obs = _player.senses.observe()
	var thing := Senses.ground_span().y
	var shot_seen := false
	var named := false
	for i in Senses.THINGS:
		var at := thing + i * Senses.THING
		if obs[at + 11] == 1.0 and obs[at + 2] > 0.2 and absf(obs[at + 3]) < 0.2:
			shot_seen = true
			named = is_equal_approx(obs[at + 20], float(Senses.SPELL_ORDER.find("Ignite") + 1) / Senses.BOOK_SPELLS)
	_verdict(shot_seen, "a shot in flight is seen, flying the way it was thrown")
	_verdict(named, "and it is seen to be a Fireball")

	# The book: every spell of the waiting room's, in its place; the spare places empty.
	var book := thing + Senses.THINGS * Senses.THING + Senses.RIVALS * Senses.RIVAL + Senses.RIVALS * 3 + (Senses.PAGES + Senses.REMEMBERED_PAGES) * Senses.PAGE_SLOT + 3
	var held := 0
	for i in Senses.BOOK_SPELLS:
		held += int(obs[book + i * Senses.PAGE])
	var fire := Senses.SPELL_ORDER.find("Ignite")
	var page := obs.slice(book + fire * Senses.PAGE, book + (fire + 1) * Senses.PAGE)
	var ignite: Spell = SpellData.SPELLS["Ignite"]
	_verdict(is_equal_approx(page[1] * 200.0, ignite.cost) and page[4] > 0.0, "a page's cost and damage are read as its page says them (%s)" % str(page))
	_verdict(held == SpellData.SPELLS.size() and Senses.SPELL_ORDER.size() == SpellData.SPELLS.size(), "the book holds every spell, each in its place (%d)" % held)
	var missing: Array = SpellData.SPELLS.keys().filter(func(n: String) -> bool: return not n in Senses.SPELL_ORDER)
	_verdict(missing.is_empty(), "every spell has a place in the book's order %s" % str(missing))

	# The words on screen: a spell too dear is "Too tired"; a stroke that means nothing costs a brain's wizard what it costs a person, and is told.
	_verdict(Senses.WORD_COUNT == Wizard.WORDS.size(), "the words are counted alike (%d)" % Wizard.WORDS.size())
	var words := Senses.SIZE - Senses.SPARE - Senses.WORD_COUNT
	_player.tell("too_tired")
	obs = _player.senses.observe()
	_verdict(obs[words + Wizard.WORDS.find("too_tired")] > 0.9 and obs[words + Wizard.WORDS.find("misfire")] == 0.0, "\"Too tired\" on the screen is sensed, and only it")
	var rival: Wizard = _lab._add_wizard("dark_wizard", _player.global_position + Vector2(200.0, 0.0))
	for k in 10:
		await get_tree().physics_frame
	var before := rival.stamina
	_lab.misfire_by(rival)
	_verdict(rival.stamina < before and rival.told.has("misfire"), "a brain's misfire costs stamina and is told (%.0f to %.0f)" % [before, rival.stamina])
	rival.take_damage(12)
	obs = _player.senses.observe()
	var slot := thing + Senses.THINGS * Senses.THING
	var about := slot + 17 + Senses.STROKE_POINTS * 2
	_verdict(obs[slot + 16] == 1.0 and obs[about] > 0.0 and obs[about + 2] > 0.2, "the other wizard is seen: which one it is, and the damage number over it (%s)" % str(obs.slice(about, about + 3)))
	rival.queue_free()
	var pickup := PagePickup.new()
	pickup.page = "Frostbolt"
	_lab.add_child(pickup)
	pickup.global_position = _player.center() + Vector2(-150.0, -20.0)
	for k in 5:
		await get_tree().physics_frame
	obs = _player.senses.observe()
	var pages := slot + Senses.RIVALS * Senses.RIVAL + Senses.RIVALS * 3
	_verdict(obs[pages + 2] == 1.0 and obs[pages + 3 + Senses.SCHOOLS.find("Water")] == 1.0, "a page on the ground is seen in its school's colour")
	pickup.queue_free()

	# The minimap, once the Rite of the Land is said.
	var map := Senses.map_span()
	var ground_on_map := 0.0
	for i in range(map.x, map.y):
		ground_on_map += obs[i]
	_verdict(ground_on_map == 0.0, "no minimap before the Rite of the Land")
	_player.ledger.settle("minimap")
	obs = _player.senses.observe()
	ground_on_map = 0.0
	for i in range(map.x, map.y):
		ground_on_map += obs[i]
	_verdict(ground_on_map > 0.0 and obs[map.y + 2] == 1.0, "after it, the whole world's ground and the wizard's place on it")

	# Memory: the ground it saw is remembered after it has walked away from it.
	var seen_before := _remembered(obs)
	_player.global_position = dry + Vector2(-700.0, -4.0)
	for k in 10:
		await get_tree().physics_frame
	obs = _player.senses.observe()
	_verdict(seen_before > 0.0 and _remembered(obs) > seen_before, "the ground seen before is remembered, and more is added (%.1f, then %.1f)" % [seen_before, _remembered(obs)])

	# Into the pond, deep: water all round, the breath held and running down.
	_player.global_position = Vector2(pond.global_position.x + pond.width * 0.5, pond.surface_at(pond.global_position.x + pond.width * 0.5) + 90.0)
	var underwater := false
	for k in 60:
		await get_tree().physics_frame
		if _player.underwater():
			underwater = true
			break
	for k in 60:
		await get_tree().physics_frame
	obs = _player.senses.observe()
	_verdict(underwater and obs[10] == 1.0 and obs[8] == 1.0, "under water the wizard senses it and holds its breath")
	_verdict(obs[7] < 1.0, "the breath it has left is sensed going down (%.2f)" % obs[7])
	_verdict(_fine(obs, 0, -1) & Senses.LIQUID != 0 and _fine(obs, 0, -1) & Senses.NO_AIR != 0, "the water about its head is a liquid with no air in it")

	# Cost: asked many times a second by several wizards.
	var began := Time.get_ticks_usec()
	for k in 50:
		_player.senses.observe()
	var each := float(Time.get_ticks_usec() - began) / 50.0 / 1000.0
	print("  one look takes %.2f ms" % each)

	_verdict(each < 6.0, "a look costs little (%.2f ms)" % each)

	print("SENSES %s" % ("PASS" if _failed == 0 else "FAILED %d" % _failed))
	get_tree().quit(1 if _failed > 0 else 0)


## How much remembered ground there is, all told.
func _remembered(obs: PackedFloat32Array) -> float:
	var from := Senses.ground_span().y - Senses.MEM_W * Senses.MEM_H * Senses.MEM_CHANNELS
	var sum := 0.0
	for i in range(from, Senses.ground_span().y, Senses.MEM_CHANNELS):
		sum += obs[i]
	return sum


## The tile bits of the fine ground box at (dx, dy) from the feet, rebuilt from its channels.
func _fine(obs: PackedFloat32Array, dx: int, dy: int) -> int:
	var cell := (dy + Senses.FINE_UP) * Senses.FINE_W + dx + Senses.FINE_HALF
	var code := 0
	for c in Senses.CHANNELS:
		if obs[Senses.SELF + cell * Senses.CHANNELS + c] > 0.5:
			code |= Senses.CHANNEL_BITS[c]
	return code


func _verdict(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok    " if ok else "FAILED", what])
	if not ok:
		_failed += 1

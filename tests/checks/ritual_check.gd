extends Node

## The chants: how closely a spoken chant must match its words, what each one gives the speaker, and what a garbled, half-said or
## unknown chant does. The words reach the arena as the incantation box sends them (its `finished` signal).
##
##     godot --headless --fixed-fps 60 --path . tests/checks/ritual_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0
var _arena: Node


func _ready() -> void:
	_words()
	_arena = load("res://scenes/lab.tscn").instantiate()
	add_child(_arena)
	await _frames(4)
	var player: Wizard = _arena.player
	player.infinite_time = 0.0
	var ledger := Ledger.new()
	_verdict(not ledger.knows_chant("boundless"), "a chant is not known until its page is")
	ledger.learn_all()
	_verdict(ledger.knows_chant("boundless"), "and is known once it is")
	_arena.learn_every_page()
	# Each gift.
	_say("boundless")
	_verdict(player.infinite_time > 0.0, "Boundless Vigour: stamina does not run out")
	_say("haste")
	_verdict(player.haste_time > 0.0, "Swift Feet: faster on foot")
	_say("double_jump")
	_verdict(player.air_jump_time > 0.0, "the Second Leap: a jump in the air is allowed")
	# A bonfire burns beside the wizard.
	_say("bonfire")
	await _frames(3)
	_verdict(get_tree().get_nodes_in_group("fires").any(func(n: Node) -> bool: return n is Bonfire), "the Bonfire kindles a fire")
	# The rift tears the wizard away, wearing them down.
	var before: Vector2 = player.global_position
	var wear: float = player.max_stamina
	player.stamina = player.max_stamina
	_say("rift")
	_verdict(player.global_position.distance_to(before) > 1.0 or player.max_stamina < wear, "the Rift sets the wizard down elsewhere, at a cost")
	_verdict(player.max_stamina < wear, "and wears their strength down")
	# A garbled chant hurts the speaker; one stopped short does not.
	player.global_position = before  # the rift put them anywhere, perhaps somewhere that hurts
	player.velocity = Vector2.ZERO
	for fire in get_tree().get_nodes_in_group("fires"):
		fire.queue_free()  # the bonfire from before would mend the wound being measured
	await _frames(90)  # the rift's own wound leaves a moment of grace
	var health: float = player.max_stamina
	_arena.player.stamina = player.max_stamina
	_arena.rituals.finished("haste", 0.2, false)
	_verdict(player.max_stamina < health, "a garbled chant backfires")
	health = player.max_stamina
	_arena.rituals.finished("haste", 0.2, true)
	_verdict(player.max_stamina == health, "a chant stopped short fades harmlessly")
	_say("deep_breath")
	_verdict(player.deep_breath_time > 0.0, "the Deep Breath: the breath is held")
	print("the chants work" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## How closely the words must be spoken: the same words are whole, a slip lessens them, and too many slips are nothing.
func _words() -> void:
	var text: String = RitualInput.RITUALS["haste"]["text"]
	_verdict(RitualInput.accuracy(text, text) == 1.0, "the right words are whole accuracy")
	_verdict(RitualInput.accuracy("  " + text.to_upper() + " ", text) == 1.0, "capitals and spaces at the ends do not matter")
	var slip := RitualInput.accuracy(text.substr(0, text.length() - 1) + "x", text)
	_verdict(slip < 1.0 and slip > RitualInput.FULL_POWER_AT - 0.1, "one slip lessens it a little (%.2f)" % slip)
	_verdict(RitualInput.accuracy("", text) == 0.0, "no words are no accuracy")
	_verdict(RitualInput.power_for(RitualInput.BACKFIRE_BELOW - 0.01) == 0.0 and RitualInput.power_for(RitualInput.FULL_POWER_AT) == 1.0, "power runs from nothing at the backfire edge to full")
	var half := RitualInput.power_for((RitualInput.BACKFIRE_BELOW + RitualInput.FULL_POWER_AT) * 0.5)
	_verdict(absf(half - 0.5) < 0.01, "and halfway between is half")
	_verdict(RitualInput.start_accuracy(text.substr(0, 5), text) > 0.99 and RitualInput.start_accuracy(text, text) == 0.0, "the start of a chant is a chant stopped short, a whole one is not")
	_verdict(RitualInput.levenshtein("kitten", "sitting") == 3, "the edit distance counts changes")


## Says a chant perfectly.
func _say(id: String) -> void:
	_arena.ritual.finished.emit(id, RitualInput.accuracy(RitualInput.RITUALS[id]["text"], RitualInput.RITUALS[id]["text"]), false)


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

extends Check
## The punch (`Punch`, the P key): it does 1 damage to whoever is in front of the wizard and in reach, for no stamina, and not again until its own 0.25 second
## cooldown is over. It starts no safety window, so a spell lands the moment after it, and it misses what is behind the wizard or out of reach.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/punch_check.tscn

var _arena: Node
var _player: Wizard
var _rival: Wizard


func _ready() -> void:
	_arena = load("res://scenes/lab.tscn").instantiate()
	add_child(_arena)
	await _frames(6)
	_player = _arena.player
	_player.infinite_time = 0.0
	_arena.heals_wounds = false
	for w: Wizard in get_tree().get_nodes_in_group("wizards"):
		if w != _player:
			_rival = w
	if _rival == null:
		_verdict(false, "there is a rival to try it on")
		get_tree().quit(1)
		return
	if _rival.brain is WizardBrain:
		_rival.brain.dormant = true
	_player.facing = 1.0
	_rival.global_position = _player.global_position + Vector2(40.0, 0.0)
	_rival.velocity = Vector2.ZERO
	await _frames(3)
	var before := _rival.max_stamina
	var stamina_before := _player.stamina
	_verdict(_player.punch.swing(), "a swing begins")
	await _frames(12)
	_verdict(is_equal_approx(_rival.max_stamina, before - 1.0), "it does 1 damage (%.1f -> %.1f)" % [before, _rival.max_stamina])
	_verdict(_player.stamina >= stamina_before - 0.01, "it costs no stamina")
	await _frames(20)
	_verdict(_player.punch.swing(), "after the cooldown it swings again")
	await _frames(12)
	_verdict(is_equal_approx(_rival.max_stamina, before - 2.0), "and lands again, with no safety window between: %.1f" % _rival.max_stamina)
	# a second swing straight away is refused
	await _frames(20)
	_player.punch.swing()
	_verdict(not _player.punch.swing(), "a swing during the cooldown is refused")
	await _frames(14)
	# out of reach, and behind (the puncher is the one that is moved: the lab has hazards a rival put somewhere else would stand in)
	var home := _player.global_position
	_player.global_position = home + Vector2(-300.0, 0.0)
	await _frames(4)
	var now := _rival.max_stamina
	_player.punch.swing()
	await _frames(14)
	_verdict(is_equal_approx(_rival.max_stamina, now), "out of reach it misses (%.1f -> %.1f)" % [now, _rival.max_stamina])
	_player.global_position = home
	_player.facing = -1.0
	await _frames(20)
	now = _rival.max_stamina
	_player.punch.swing()
	await _frames(14)
	_verdict(is_equal_approx(_rival.max_stamina, now), "behind the wizard it misses (%.1f -> %.1f)" % [now, _rival.max_stamina])
	_player.facing = 1.0
	await _frames(20)
	now = _rival.max_stamina
	_player.punch.swing()
	await _frames(14)
	_verdict(is_equal_approx(_rival.max_stamina, now - 1.0), "and in front, in reach, it lands (%.1f -> %.1f)" % [now, _rival.max_stamina])
	print("the punch works" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame

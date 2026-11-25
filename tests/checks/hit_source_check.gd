extends Check
## The safety that follows a hit (`Wizard.take_damage`): a hit with no source shares one safety, as it always did; a hit that names a source has a safety of its own
## for that source, so the same source cannot hit again within `Wizard.HURT_GRACE` but a different one lands at once, and the two kinds do not stop each other.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/hit_source_check.tscn

var _arena: Node
var _rival: Wizard


func _ready() -> void:
	_arena = load("res://scenes/lab.tscn").instantiate()
	add_child(_arena)
	await _frames(6)
	_arena.heals_wounds = false
	for w: Wizard in get_tree().get_nodes_in_group("wizards"):
		if w != _arena.player:
			_rival = w
	if _rival == null:
		_verdict(false, "there is a rival to try it on")
		get_tree().quit(1)
		return
	if _rival.brain is WizardBrain:
		_rival.brain.dormant = true
	var a := Node.new()
	var b := Node.new()
	add_child(a)
	add_child(b)
	_rival.max_stamina = 200.0
	_rival.take_damage(10, true, false, a)
	_verdict(is_equal_approx(_rival.max_stamina, 190.0), "a hit from one source lands")
	_rival.take_damage(10, true, false, a)
	_verdict(is_equal_approx(_rival.max_stamina, 190.0), "the same source cannot hit again at once")
	_rival.take_damage(10, true, false, b)
	_verdict(is_equal_approx(_rival.max_stamina, 180.0), "a different source lands at once")
	_rival.take_damage(10)
	_verdict(is_equal_approx(_rival.max_stamina, 170.0), "a hit with no source is not stopped by the sourced ones")
	_rival.take_damage(10)
	_verdict(is_equal_approx(_rival.max_stamina, 170.0), "and a second with none is stopped, as it always was")
	_rival.take_damage(10, true, false, a)
	_verdict(is_equal_approx(_rival.max_stamina, 170.0), "a source still in its safety stays stopped")
	await _frames(40)
	_rival.take_damage(10, true, false, a)
	_verdict(is_equal_approx(_rival.max_stamina, 160.0), "after the safety the same source lands again")
	_rival.take_damage(10, false, false, b)
	_verdict(is_equal_approx(_rival.max_stamina, 150.0), "a hit that takes no safety (a burn) always lands")
	var wall := RefCounted.new()
	var one := Firewall.new()
	var two := Firewall.new()
	_verdict(one.hit_source() != two.hit_source(), "two walls are two sources")
	one.cast_source = wall
	two.cast_source = wall
	_verdict(one.hit_source() == two.hit_source(), "the columns of one wall are one source")
	one.free()
	two.free()
	# The one who struck last is gone with the world it was in, and the next blow lands at the start of another: it has no striker, and is not an error.
	_arena.player.max_stamina = 200.0
	MatchStats.strike(_rival)
	_rival.free()
	_arena.player.take_damage(5, true, false, a)
	await _frames(2)
	_verdict(MatchStats.last_striker_is_cleared() and is_equal_approx(_arena.player.max_stamina, 195.0), "a blow after the wizard who struck last is gone lands, with no striker")
	print("hits keep a safety for each source" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame

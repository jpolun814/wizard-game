extends Check
## Jolt, Bathe and Headwind. Jolt is lightning, so the world strikes a wet body harder with it (no rule of its own), and it hurries whoever it strikes. Bathe washes the
## caster clean (a flame, oil, a chill, a snail) and leaves them wet. Headwind slows what comes into it, shots included, and not its caster or the caster's own shots.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/new_spells_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _arena: Node
var _player: Wizard
var _rival: Wizard


func _ready() -> void:
	_arena = load("res://scenes/lab.tscn").instantiate()
	add_child(_arena)
	await _frames(6)
	_player = _arena.player
	_player.infinite_time = 1.0e6
	for w: Wizard in get_tree().get_nodes_in_group("wizards"):
		if w != _player:
			_rival = w
	_verdict(_rival != null, "there is a rival to try them on")
	if _rival == null:
		get_tree().quit(1)
		return
	if _rival.brain is WizardBrain:
		_rival.brain.dormant = true  # (it does nothing, but its body goes on: a blow's moment of grace runs out)
	await _jolt()
	await _bathe()
	await _headwind()
	print("the new spells work" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _cast(spell_name: String, aim := 0.0) -> void:
	_arena.spawn_spell(spell_name, SpellData.SPELLS[spell_name].targeting, _player.center(), aim, {}, _player)


## The rival stands where the bolt will find it, on the same line as the caster's staff.
func _place_rival(at: Vector2) -> void:
	_rival.global_position = at
	_rival.velocity = Vector2.ZERO
	_rival.reset_physics_interpolation()


func _jolt() -> void:
	_player.global_position = Vector2(_player.global_position.x, _player.global_position.y)
	_place_rival(_player.global_position + Vector2(200.0, 0.0))
	var before := _rival.max_stamina
	_cast("Jolt")
	await _frames(3)
	var dry := before - _rival.max_stamina
	_verdict(dry > 0.0, "a bolt of Jolt strikes the rival (%.0f)" % dry)
	_verdict(_rival.haste_time > 0.0 and _rival.haste_time <= Jolt.HASTE_SECONDS + 0.1, "and sets them off for a moment (%.1f s)" % _rival.haste_time)
	await get_tree().create_timer(1.0).timeout  # (the moment of grace after a blow)
	_rival.haste_time = 0.0
	_rival.wet_time = 8.0
	_place_rival(_player.global_position + Vector2(200.0, 0.0))  # (it has fallen to the ground since)
	_rival.wet_time = 8.0
	_rival.set("_grace", 0.0)  # (a dormant wizard does not run its moment of grace down)
	before = _rival.max_stamina
	_cast("Jolt")
	await _frames(3)
	var wet := before - _rival.max_stamina
	_verdict(wet > dry * 1.4, "and a wet rival takes it harder (%.0f against %.0f)" % [wet, dry])
	_rival.wet_time = 0.0
	await get_tree().create_timer(1.0).timeout
	_place_rival(_player.global_position + Vector2(-200.0, 0.0))  # behind the caster: a bolt that flies the other way finds no one
	await _frames(4)
	before = _rival.max_stamina
	_cast("Jolt")
	await _frames(3)
	_verdict(_rival.max_stamina == before, "and a bolt flies only the way it was drawn")


func _bathe() -> void:
	_place_rival(_player.global_position + Vector2(900.0, 0.0))
	_player.burning_time = 5.0
	_player.oiled_time = 5.0
	_player.slow_time = 5.0
	_player.daze_time = 5.0
	var snail := InvincibleSnail.conjure(_arena, _player.global_position + Vector2(300.0, 0.0), _player, _rival, true)
	await _frames(2)
	_verdict(_player.burning_time > 0.0 and _player.oiled_time > 0.0, "burning and oiled before bathing")
	_cast("Bathe")
	await _frames(3)
	_verdict(_player.burning_time <= 0.0 and _player.oiled_time <= 0.0, "Bathe puts out the flame and washes off the oil")
	_verdict(_player.slow_time <= 0.0 and _player.daze_time <= 0.0, "and the chill and the daze")
	_verdict(_player.wet_time > 0.0, "and leaves the wizard wet")
	await _frames(40)
	_verdict(not is_instance_valid(snail) or snail.is_queued_for_deletion() or snail.modulate.a < 1.0, "and the snail that was after them loses them")
	_player.wet_time = 0.0


func _headwind() -> void:
	_player.wet_time = 0.0
	_player.slow_time = 0.0
	_place_rival(_player.global_position + Vector2(90.0, 0.0))
	_cast("Headwind")
	await _frames(6)
	_verdict(_rival.slow_time > 0.0, "a rival in the wind is slowed")
	_verdict(_player.slow_time <= 0.0, "and the one who raised it is not")
	# A shot is slowed in it and flies the same way: one loosed by the rival from inside, and one far outside, are compared after the same flight.
	_place_rival(_player.global_position + Vector2(90.0, 0.0))
	var inside := EnemyBolt.fire(_arena, _player.global_position + Vector2(60.0, -140.0), _player.global_position + Vector2(160.0, -140.0), Color.WHITE, 1, null)
	var outside := EnemyBolt.fire(_arena, _player.global_position + Vector2(2000.0, -140.0), _player.global_position + Vector2(2100.0, -140.0), Color.WHITE, 1, null)
	var inside_from := inside.global_position
	var outside_from := outside.global_position
	await _frames(6)
	var went_in := inside.global_position.distance_to(inside_from)
	var went_out := outside.global_position.distance_to(outside_from)
	_verdict(went_in < went_out * 0.8 and went_in > 0.0, "a shot in the wind goes slower (%.0f px against %.0f)" % [went_in, went_out])
	_verdict(absf(inside.heading().angle() - outside.heading().angle()) < 0.05, "and goes the same way")
	# Every shot is slowed, of whatever kind: a ball of lava is a thing flying at the wizard like any other.
	var lava_in := LavaBall.throw(_arena, _player.global_position + Vector2(60.0, -120.0), Vector2(100.0, 0.0))
	var lava_out := LavaBall.throw(_arena, _player.global_position + Vector2(2000.0, -120.0), Vector2(100.0, 0.0))
	var lava_in_from := lava_in.global_position
	var lava_out_from := lava_out.global_position
	await _frames(6)
	_verdict(lava_in.global_position.distance_to(lava_in_from) < lava_out.global_position.distance_to(lava_out_from) * 0.8, "a ball of lava in the wind goes slower too (%.0f px against %.0f)" % [lava_in.global_position.distance_to(lava_in_from), lava_out.global_position.distance_to(lava_out_from)])
	# Hail is a shot too: the stones of a Hailstorm fall slower in the wind.
	var hail_in := HailStone.new()
	hail_in.global_position = _player.global_position + Vector2(-40.0, -170.0)
	_arena.add_child(hail_in)
	var hail_out := HailStone.new()
	hail_out.global_position = _player.global_position + Vector2(0.0, -400.0)
	_arena.add_child(hail_out)
	var hail_in_from := hail_in.global_position
	var hail_out_from := hail_out.global_position
	await _frames(6)
	var fell_in := hail_in.global_position.distance_to(hail_in_from)
	var fell_out := hail_out.global_position.distance_to(hail_out_from)
	_verdict(fell_in < fell_out * 0.8 and fell_in > 0.0, "hail in the wind falls slower (%.0f px against %.0f)" % [fell_in, fell_out])
	hail_in.queue_free()
	hail_out.queue_free()
	# A falling stone of a cave, a falling boulder and a rolling ball of fire are shots too: each goes slower in the wind (a pair, one inside and one far outside).
	var rock_in := FallingRock.new()
	rock_in.global_position = _player.global_position + Vector2(-40.0, -170.0)
	var rock_out := FallingRock.new()
	rock_out.global_position = _player.global_position + Vector2(0.0, -400.0)
	var boulder_in := Boulder.new()
	boulder_in.global_position = _player.global_position + Vector2(-60.0, -170.0)
	var boulder_out := Boulder.new()
	boulder_out.global_position = _player.global_position + Vector2(0.0, -500.0)
	for thing in [rock_in, rock_out, boulder_in, boulder_out]:
		_arena.add_child(thing)
	var starts := {}
	for thing in [rock_in, rock_out, boulder_in, boulder_out]:
		starts[thing] = thing.global_position
	await _frames(12)
	for pair: Array in [["a falling rock", rock_in, rock_out], ["a falling boulder", boulder_in, boulder_out]]:
		var a: Node2D = pair[1]
		var b: Node2D = pair[2]
		if is_instance_valid(a) and is_instance_valid(b):
			var went_a := a.global_position.distance_to(starts[a])
			var went_b := b.global_position.distance_to(starts[b])
			_verdict(went_a < went_b * 0.8 and went_a > 0.0, "%s in the wind falls slower (%.0f px against %.0f)" % [pair[0], went_a, went_b])
		else:
			_verdict(false, "%s was lost before it could be measured" % pair[0])
	for thing in [rock_in, rock_out, boulder_in, boulder_out]:
		if is_instance_valid(thing):
			thing.queue_free()
	var ball_in := FlamingSphere.new()
	ball_in.global_position = _player.global_position + Vector2(-100.0, -20.0)
	var ball_out := FlamingSphere.new()
	ball_out.global_position = _player.global_position + Vector2(-500.0, -20.0)
	_arena.add_child(ball_in)
	_arena.add_child(ball_out)
	await _frames(4)
	var ball_in_from := ball_in.global_position
	var ball_out_from := ball_out.global_position
	await _frames(10)
	if is_instance_valid(ball_in) and is_instance_valid(ball_out):
		var rolled_in := ball_in.global_position.distance_to(ball_in_from)
		var rolled_out := ball_out.global_position.distance_to(ball_out_from)
		_verdict(rolled_in < rolled_out * 0.8 and rolled_in > 0.0, "a rolling ball of fire in the wind goes slower (%.0f px against %.0f)" % [rolled_in, rolled_out])
	else:
		_verdict(false, "a ball of fire was lost before it could be measured")
	for ball in [ball_in, ball_out]:
		if is_instance_valid(ball):
			ball.queue_free()
	var every_shot := true
	for shot: Node in get_tree().get_nodes_in_group("shots"):
		every_shot = every_shot and shot.has_method("hinder")
	_verdict(every_shot, "and every shot in the world can be slowed")
	for lava in [lava_in, lava_out]:
		if is_instance_valid(lava):
			lava.queue_free()
	var own := EnemyBolt.fire(_arena, _player.global_position + Vector2(60.0, -200.0), _player.global_position + Vector2(160.0, -200.0), Color.WHITE, 1, _player)
	var own_from := own.global_position
	await _frames(6)
	_verdict(own.global_position.distance_to(own_from) > went_out * 0.9, "but the caster's own shot is not slowed")


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame

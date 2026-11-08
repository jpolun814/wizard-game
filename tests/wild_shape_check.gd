extends Node

## Wild Shape: the wizard becomes a werewolf that cannot cast and claws whoever is in front, until the first blow lands, which turns them back
## with the stamina they had before, without their dying of it.
##
##     godot --headless --fixed-fps 60 --path . tests/wild_shape_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0
var _world: World
var _player: Wizard
var _spot := Vector2.ZERO


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 8
	_world = load("res://scenes/world.tscn").instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_player = _world.player
	_player.ledger.learn_all()
	for rival in _world._rivals:
		rival.set_physics_process(false)
		rival.global_position = Vector2(-9000.0, -9000.0)
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.queue_free()
	for page in get_tree().get_nodes_in_group("pages"):
		page.queue_free()
	_world.set_process(false)
	_spot = _player.global_position
	await _wait(0.5)

	_player.stamina = 150.0
	_player.max_stamina = 170.0
	var had := _player.stamina
	_world.spawn_spell("Wild Shape", "positional", _player.center(), 0.0, {"accuracy": 0.9}, _player)
	await _wait(0.3)
	_verdict(_player.wild, "the spell turns the wizard into a werewolf")
	_verdict(is_equal_approx(_player.max_stamina, Wizard.WILD_STAMINA), "the wolf has a pool of its own (%.0f)" % _player.max_stamina)
	_verdict(_player.silenced() and _player.is_muted(), "and can cast and chant nothing")
	_verdict(String(_player._sprite.sprite_frames.resource_path) != "" or _player._sprite.sprite_frames.has_animation("release"), "and wears the wolf's frames")
	var dummy: Mob = _world._add_mob("basic", _spot + Vector2(50.0, 0.0))
	dummy._spawn = 0.0
	dummy.set_physics_process(false)
	dummy.max_hp = 500
	dummy.hp = 500
	_player.facing = 1.0
	await _wait(0.5)
	var pool := _player.max_stamina
	_player.claw()
	await _wait(0.5)
	_verdict(dummy.hp < 500, "a swipe of the claws hurts whoever is in front (%d of 500 left)" % dummy.hp)
	_verdict(_player.wild and _player.max_stamina == pool, "and does not use up the pool")
	var far: Mob = _world._add_mob("basic", _spot + Vector2(-400.0, 0.0))
	far._spawn = 0.0
	far.set_physics_process(false)
	far.max_hp = 500
	far.hp = 500
	await _wait(0.8)
	_player.claw()
	await _wait(0.5)
	_verdict(far.hp == 500, "a body far off or behind is not touched")
	# Time and swipes do not end it; a single blow does, and does not kill the wizard.
	await _wait(6.0)
	_verdict(_player.wild and _player.max_stamina == Wizard.WILD_STAMINA, "the shape stays as long as no blow lands")
	_player.take_damage(1)
	await _wait(0.2)
	_verdict(not _player.wild and not _player.dead, "one blow turns the wizard back, and does not kill them")
	_verdict(absf(_player.stamina - had) < 8.0 and _player.max_stamina == 170.0, "with the stamina they had before (%.0f of %.0f, had %.0f)" % [_player.stamina, _player.max_stamina, had])
	print("Wild Shape works" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

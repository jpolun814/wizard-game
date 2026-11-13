extends Node

## Thorn Whip and Insect Plague, cast in a real world. The whip drags what it hits toward the caster (an enemy, a rival wizard, a page), is stopped by a
## wall, burnt by a flame, and cannot move a giant. The swarm goes after the nearest wizard, takes no notice of its caster at first, stings, scatters
## when it is hit, gives up when it has no one to follow, and does not last for ever.
##
##     godot --headless --fixed-fps 60 --path . tests/group_b_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0
var _world: World
var _player: Wizard
var _rival: Wizard
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
	for rival in _world._rivals:
		rival.set_physics_process(false)
		rival.global_position = Vector2(-9000.0, -9000.0)
	_rival = _world._rivals[0]
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.queue_free()
	for page in get_tree().get_nodes_in_group("pages"):
		page.queue_free()
	_world.set_process(false)
	_spot = _player.global_position
	await _wait(0.5)
	await _whip()
	await _swarm()
	await _swarm_counters()
	print("the thorn whip and the swarm work" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _mob(kind: String, dx: float) -> Mob:
	var mob: Mob = _world._add_mob(kind, _spot + Vector2(dx, 0.0))
	mob.max_hp = 500
	mob.hp = 500
	return mob


func _wall(dx: float, height: float) -> StaticBody2D:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(24.0, height)
	shape.shape = box
	wall.add_child(shape)
	wall.collision_layer = 1
	wall.position = _spot + Vector2(dx, 4.0 - height * 0.5)
	_world.add_child(wall)
	return wall


func _cast(spell: String, targeting: String, aim: float, at := Vector2.ZERO) -> void:
	var origin := _player.center() if at == Vector2.ZERO else at
	_world.spawn_spell(spell, targeting, origin, aim, {"length": 90.0, "accuracy": 0.9}, _player)


func _whip() -> void:
	var dummy := _mob("dummy", 260.0)
	await _wait(1.6)
	var before := dummy.global_position.x
	_cast("Thorn Whip", "directional", 0.0)
	await _wait(1.0)
	var moved := before - dummy.global_position.x
	_verdict(dummy.max_hp - dummy.hp >= ThornWhip.HARM, "and the thorns bite it (%d hurt)" % (dummy.max_hp - dummy.hp))
	_verdict(moved > 80.0, "the whip drags an enemy toward the caster (%.0f px)" % moved)
	_verdict(dummy.global_position.x > _player.global_position.x + 20.0, "and lets go before it reaches them (%.0f px off)" % (dummy.global_position.x - _player.global_position.x))
	dummy.global_position = _spot + Vector2(260.0, 0.0)
	await _wait(0.5)
	var wall := _wall(100.0, 220.0)
	await _wait(0.2)
	before = dummy.global_position.x
	_cast("Thorn Whip", "directional", 0.0)
	await _wait(1.0)
	_verdict(absf(dummy.global_position.x - before) < 6.0, "a wall stops the whip (%.0f px)" % (before - dummy.global_position.x))
	wall.queue_free()
	await _wait(0.2)
	var flame := Hazard.place(_world, _player.center() + Vector2(120.0, 10.0), 80.0, 5.0)  # on the whip's line
	await _wait(0.1)  # (a flame is added a frame after it is placed)
	before = dummy.global_position.x
	_cast("Thorn Whip", "directional", 0.0)
	await _wait(1.0)
	_verdict(absf(dummy.global_position.x - before) < 6.0, "a flame burns it away on the line (%.0f px)" % (before - dummy.global_position.x))
	if is_instance_valid(flame):
		flame.queue_free()
	dummy.queue_free()
	# A giant is too heavy to move.
	var giant := _mob("giant", 280.0)
	await _wait(2.0)
	_cast("Thorn Whip", "directional", 0.0)
	var lash: ThornWhip = null
	for n in _world.get_children():
		if n is ThornWhip:
			lash = n
	await _wait(0.5)
	_verdict(lash != null and lash._held == null, "a giant is too heavy to drag: the whip takes no hold of it")
	giant.queue_free()
	# A rival wizard is dragged too.
	_rival.global_position = _spot + Vector2(260.0, 0.0)
	_rival.velocity = Vector2.ZERO
	await _wait(0.4)
	before = _rival.global_position.x
	_rival.set_physics_process(true)
	_cast("Thorn Whip", "directional", 0.0)
	await _wait(1.0)
	var dragged := before - _rival.global_position.x
	_verdict(dragged > 60.0, "a rival wizard is dragged toward the caster (%.0f px)" % dragged)
	_rival.set_physics_process(false)
	_rival.global_position = Vector2(-9000.0, -9000.0)  # out of the way of the next
	# A page is dragged along the ground too.
	var page := PagePickup.new()
	page.page = "Ignite"
	page.global_position = _spot + Vector2(260.0, -4.0)
	_world.add_child(page)
	await _wait(0.2)
	before = page.global_position.x
	_cast("Thorn Whip", "directional", 0.0)
	await _wait(1.5)
	_verdict(before - page.global_position.x > 100.0, "a page is dragged to the caster (%.0f px)" % (before - page.global_position.x))
	page.queue_free()


func _swarm() -> void:
	# The caster alone: it takes no notice of them at first, and then comes for them.
	var start_max := _player.max_stamina
	_cast("Insect Plague", "positional", 0.0, _player.center() + Vector2(120.0, 0.0))
	var swarm: InsectPlague = null
	for n in _world.get_children():
		if n is InsectPlague:
			swarm = n
	_verdict(swarm != null, "a swarm is raised")
	if swarm == null:
		return
	var first_gap := swarm.global_position.distance_to(_player.center())
	await _wait(3.0)
	_verdict(is_equal_approx(_player.max_stamina, start_max) and absf(swarm.global_position.distance_to(_player.center()) - first_gap) < 8.0, "for its first few seconds it takes no notice of its caster")
	await _wait(2.0)
	_verdict(swarm.global_position.distance_to(_player.center()) < first_gap - 40.0 or _player.max_stamina < start_max, "and then comes for them")
	await _wait(2.5)
	_verdict(_player.max_stamina < start_max, "and stings (%.0f lost)" % (start_max - _player.max_stamina))
	swarm.disperse()
	await _wait(1.0)
	# A rival wizard in sight: the swarm goes to the nearest and stings them.
	_player.max_stamina = 200.0
	_rival.global_position = _spot + Vector2(380.0, 0.0)
	_rival.velocity = Vector2.ZERO
	_rival.max_stamina = 200.0
	await _wait(0.3)
	_cast("Insect Plague", "positional", 0.0, _player.center() + Vector2(40.0, 0.0))
	swarm = _swarm_now()
	var gap_at_start := swarm.global_position.distance_to(_rival.center())
	await _wait(2.0)
	_verdict(swarm.global_position.distance_to(_rival.center()) < gap_at_start - 100.0, "the swarm flies at a rival, and not at its caster (%.0f to %.0f px)" % [gap_at_start, swarm.global_position.distance_to(_rival.center())])
	await _wait(3.0)
	_verdict(_rival.max_stamina < 200.0 and _player.max_stamina == 200.0, "and stings the rival (%.0f lost) not the caster" % (200.0 - _rival.max_stamina))
	# One hit and the whole swarm is gone.
	var bolt := Projectile.new()
	_world.add_child(bolt)
	bolt.setup("Ignite", swarm.global_position + Vector2(-30.0, 0.0), 0.0)
	await _wait(1.2)
	_verdict(_swarm_now() == null, "one hit and the whole swarm scatters")
	# Fire scatters it too.
	_rival.global_position = _spot + Vector2(380.0, 0.0)
	_cast("Insect Plague", "positional", 0.0, _player.center() + Vector2(40.0, 0.0))
	swarm = _swarm_now()
	var flame := Hazard.place(_world, swarm.global_position + Vector2(0.0, 30.0), 80.0, 6.0)
	await _wait(1.2)
	_verdict(_swarm_now() == null, "so does a flame")
	if is_instance_valid(flame):
		flame.queue_free()
	# Water (a Blizzard's snow in the air) and smoke too: anything that hangs in the air where it is.
	_cast("Insect Plague", "positional", 0.0, _player.center() + Vector2(40.0, 0.0))
	swarm = _swarm_now()
	var hail := Hailstorm.new()
	hail.line = PackedVector2Array([swarm.global_position + Vector2(-60.0, -40.0), swarm.global_position + Vector2(60.0, -40.0)])
	_world.add_child(hail)
	hail.setup("Hailstorm", swarm.global_position, 0.0)
	await _wait(1.2)
	_verdict(_swarm_now() == null, "and a cloud that hangs where it is")
	hail.dissipate()
	# Water drives it off, whether it meets the water or sits on someone who has jumped in.
	var pool := Pond.new()
	pool.width = 300.0
	pool.depth = 120.0
	_world.add_child(pool)
	pool.global_position = _player.global_position + Vector2(-150.0, -10.0)
	await _wait(0.3)
	_cast("Insect Plague", "positional", 0.0, _player.center() + Vector2(40.0, 0.0))
	await _wait(1.2)
	_verdict(_swarm_now() == null, "a swarm that meets water is driven off")
	pool.queue_free()
	await _wait(0.2)
	# With no one to follow it gives up.
	_rival.global_position = Vector2(-9000.0, -9000.0)
	_cast("Insect Plague", "positional", 0.0, _player.center() + Vector2(40.0, 0.0))
	swarm = _swarm_now()
	_player.global_position = _spot + Vector2(-900.0, 0.0)  # out of its sight
	await _wait(InsectPlague.IDLE_LIMIT + 1.5)
	_verdict(_swarm_now() == null, "with no one to follow it gives up")
	_player.global_position = _spot
	await _wait(0.3)
	# It does not last for ever.
	_player.global_position = _spot
	_cast("Insect Plague", "positional", 0.0, _player.center() + Vector2(300.0, 0.0))
	swarm = _swarm_now()
	swarm._age = InsectPlague.HARD_LIMIT - 0.2
	await _wait(0.6)
	_verdict(_swarm_now() == null, "and it does not last for ever")


## What a swarm cannot get past or find: a Barrier turns it away, a wizard faded from sight or behind smoke is not found, a stone wall stops it.
func _swarm_counters() -> void:
	_player.global_position = _spot + Vector2(-900.0, 0.0)  # out of its sight, so that only the rival is there to follow
	_player.velocity = Vector2.ZERO
	var at := _spot + Vector2(0.0, -40.0)
	_rival.global_position = _spot + Vector2(380.0, 0.0)
	_rival.velocity = Vector2.ZERO
	_rival.max_stamina = 200.0
	await _wait(0.3)
	_rival.raise_shield(30.0)
	_cast("Insect Plague", "positional", 0.0, at)
	await _wait(4.0)
	_verdict(_swarm_now() == null and _rival.max_stamina == 200.0, "a Barrier turns the swarm away, unhurt (%.0f lost)" % (200.0 - _rival.max_stamina))
	_rival._shield_time = 0.0
	_rival.fade_from_sight(30.0)
	_cast("Insect Plague", "positional", 0.0, at)
	var swarm := _swarm_now()
	var start := swarm.global_position
	await _wait(3.0)
	_verdict(swarm.global_position.distance_to(start) < 20.0 and _rival.max_stamina == 200.0, "it cannot find a wizard who has faded from sight (%.0f px moved)" % swarm.global_position.distance_to(start))
	swarm.disperse()
	await _wait(0.8)
	_rival.fade_time = 0.0
	var smoke := Node.new()  # a bank of smoke that no line of sight passes through
	var script := GDScript.new()
	script.source_code = "extends Node
func blocks(_a, _b):
	return true
"
	script.reload()
	smoke.set_script(script)
	smoke.add_to_group("sight_blockers")
	_world.add_child(smoke)
	_cast("Insect Plague", "positional", 0.0, at)
	swarm = _swarm_now()
	start = swarm.global_position
	await _wait(3.0)
	_verdict(swarm.global_position.distance_to(start) < 20.0 and _rival.max_stamina == 200.0, "nor one behind a bank of smoke (%.0f px moved)" % swarm.global_position.distance_to(start))
	swarm.disperse()
	smoke.queue_free()
	await _wait(0.8)
	var wall := _wall(200.0, 260.0)
	wall.add_to_group("walls")
	_cast("Insect Plague", "positional", 0.0, at)
	swarm = _swarm_now()
	await _wait(5.0)
	_verdict(swarm != null and not swarm.is_queued_for_deletion() and swarm.global_position.x < wall.global_position.x and _rival.max_stamina == 200.0, "a stone wall stops it in its path (it is at %.0f, the wall at %.0f)" % [swarm.global_position.x - _spot.x, wall.global_position.x - _spot.x])
	swarm.disperse()
	wall.queue_free()
	_rival.global_position = Vector2(-9000.0, -9000.0)
	_player.global_position = _spot


func _swarm_now() -> InsectPlague:
	for n in _world.get_children():
		if n is InsectPlague and not n.is_queued_for_deletion() and not n._dispersing:
			return n
	return null


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

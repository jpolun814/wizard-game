extends Check

## EVERY kind of creature (the files in data/mobs, so a new one is covered the day it is added) is summoned in a world and put through everything that can be done to a body:
## it arrives and stands, is soaked, lit, oiled, shocked, frozen, slowed, rooted, knocked back, pulled, struck by every school, fainted and killed. For each, nothing
## prints a script error (the runner fails on one), the laws hold for it as for a wizard (the same `Substances` states), and a killed creature is gone from the
## world a little later. Then every spell is cast at a creature, to see that none breaks on a target that is not a wizard.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/mob_sweep_check.tscn [-- only=giant] [-- nospells=1]

var _world: World
var _feet := Vector2.ZERO


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 8
	MatchState.hurry = 100.0
	_world = load("res://scenes/world.tscn").instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	for mob in get_tree().get_nodes_in_group("mobs").duplicate():
		mob.queue_free()
	for found: Wizard in get_tree().get_nodes_in_group("wizards"):
		if found != _world.player:
			found.set_physics_process(false)
			found.global_position = Vector2(-9000.0, -9000.0)
			found.remove_from_group("wizards")
	_feet = _world.player.global_position
	var args := _args()
	var kinds: Array = Mob.KINDS.keys()
	kinds.sort()
	for kind: String in kinds:
		if args.has("only") and args["only"] != kind:
			continue
		await _kind(kind)
	if not args.has("nospells") and not args.has("only"):
		await _spells()
	print("%d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			out[a.get_slice("=", 0)] = a.get_slice("=", 1)
	return out


func _frames(n: int) -> void:
	for k in n:
		await get_tree().physics_frame


func _spawn(kind: String, offset := Vector2(300.0, 0.0)) -> Node:
	var mob = _world.add_mob(kind, _feet + offset)
	await _frames(100)  # (it arrives through a summoning circle)
	return mob


func _alive(mob) -> bool:
	return is_instance_valid(mob) and not mob.is_queued_for_deletion() and not mob.is_dead()


func _kind(kind: String) -> void:
	var data: MobKind = Mob.KINDS[kind]
	var mob = await _spawn(kind)
	_verdict(is_instance_valid(mob), "%s: it can be summoned" % kind)
	if not is_instance_valid(mob):
		return
	if not mob is Mob:  # (a wizard of the world's own kind: it is a Wizard, tried by the wizard checks)
		mob.queue_free()
		return
	mob.set_physics_process(true)
	_verdict(_alive(mob) and mob.hp == data.hp and mob.max_hp == data.hp, "%s: it arrives alive with its health (%d)" % [kind, data.hp])
	var immune_fire: bool = mob.immune_to(Damage.HEAT)
	# The same laws as a wizard: soaked, then a flame cannot light it; lit, then water puts it out; oil makes the burn longer; lightning strikes the wet harder.
	Substances.soak(mob)
	_verdict(mob.is_wet(), "%s: water soaks it" % kind)
	Substances.ignite(mob)
	_verdict(mob.burning_time <= 0.0, "%s: a wet body cannot be lit" % kind)
	mob.wet_time = 0.0
	Substances.ignite(mob)
	_verdict(mob.burning_time > 0.0 or immune_fire, "%s: heat lights it unless it is proof against heat" % kind)
	Substances.soak(mob)
	_verdict(mob.burning_time <= 0.0, "%s: water puts a flame out" % kind)
	mob.wet_time = 0.0
	Substances.oil(mob)
	_verdict(mob.is_oiled(), "%s: oil clings to it" % kind)
	var plain := Substances.shocked(mob, 10)
	Substances.soak(mob)
	_verdict(Substances.shocked(mob, 10) > plain, "%s: lightning strikes the wet harder" % kind)
	mob.wet_time = 0.0
	mob.oiled_time = 0.0
	mob.burning_time = 0.0
	# Everything that can be done to it, one thing after another.
	var before: Vector2 = mob.global_position
	mob.apply_slow(1.0)
	mob.apply_root(0.5)
	mob.apply_no_jump(0.5)
	mob.knock_back(Vector2(300.0, -200.0))
	mob.pull(Vector2(-200.0, 0.0), 0.1)
	mob.freeze(1.0)
	await _frames(30)
	_verdict(is_instance_valid(mob) and not mob.global_position.is_equal_approx(Vector2(NAN, NAN)) and is_finite(mob.global_position.x) and is_finite(mob.global_position.y), "%s: its position stays a number after being slowed, rooted, shoved, pulled and frozen (%s from %s)" % [kind, mob.global_position, before])
	for school in SpellData.SCHOOL_NAMES:
		if _alive(mob):
			mob.take_damage(1, school, false)
	await _frames(5)
	_verdict(is_instance_valid(mob), "%s: it survives being struck by every school once" % kind)
	if not _alive(mob):
		return
	mob.faint()
	await _frames(10)
	mob.hp = mob.hp  # (a fainted creature is still the same creature)
	mob.take_damage(100000, "", false)
	await _frames(240)
	if data.effect == "dummy":  # (it never falls: that is what it is for)
		_verdict(_alive(mob), "%s: it never falls, however hard it is struck" % kind)
		mob.queue_free()
		return
	_verdict(not is_instance_valid(mob) or mob.is_queued_for_deletion() or not mob.is_in_group("mobs") or mob.is_dead(), "%s: struck hard enough it dies" % kind)
	await _frames(300)
	_verdict(not is_instance_valid(mob) or mob.is_queued_for_deletion(), "%s: and then it is gone from the world, not left lying about" % kind)


## Every spell cast at a creature (a skeleton, and the giant that nothing moves).
func _spells() -> void:
	var player: Wizard = _world.player
	player.grant_unlimited(1.0e9)
	var names: Array = SpellData.SPELLS.keys()
	names.sort()
	for target_kind in ["basic", "giant"]:
		if not Mob.KINDS.has(target_kind):
			continue
		for spell_name: String in names:
			var data: Spell = SpellData.SPELLS[spell_name]
			for mob in get_tree().get_nodes_in_group("mobs").duplicate():
				mob.queue_free()
			player.global_position = _feet
			player.velocity = Vector2.ZERO
			player.ledger.learn_all()
			var mob = await _spawn(target_kind, Vector2(140.0, 0.0))
			if not is_instance_valid(mob):
				continue
			mob.set_physics_process(false)  # (it stands where the spell is drawn)
			var shape := GestureTemplates.preview_points(data.gesture)
			var at: Vector2 = mob.center()
			if spell_name == "Stone Wall":
				at = _feet + Vector2(60.0, -40.0)
			player.stamina = player.max_stamina
			_world.caster.cast_stroke(data.buttons, BrainStrokes.offset(shape, at, 1.0))
			await _frames(40)
			if is_instance_valid(mob):
				mob.set_physics_process(true)
			await _frames(60)
			_verdict(true, "%s cast at a %s without a script error" % [spell_name, target_kind])
			if not is_instance_valid(player) or player.dead:
				player.dead = false
				player.stamina = player.max_stamina

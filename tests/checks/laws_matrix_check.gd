extends Check

## The laws of the world, tried between EVERY pair of spells that make the things they act on, and not just the pairs somebody thought of:
##   water  (a spell whose effect joins "waters", except snow, which does not soak)  puts out  every fire (a spell that joins "fires" or "flares")
##   wind   (a spell that joins "winds")  thins away  every cloud (a spell that joins "clouds") and puts out a flare
##   a Barrier turns away every shot (a spell that joins "shots")
## Which spell makes what is read from the sweep's own record of the groups, so a new spell with a water, fire, wind or shot joins the matrix by being cast.
## A pair that fails is a hole in a law, or a spell that is not what it says it is.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/laws_matrix_check.tscn

## What a spell can only be put out by if it is stronger than this: lava-like fires that water cannot quench (none yet).
const NOT_QUENCHED: Array = []
const WATERS := ["Geyser", "Tide Surf", "Water Jet"]
const FIRES := ["Fire Breath", "Firewall", "Flaming Sphere", "Flare"]  # (Ignite is a shot, tried with the shots)
const WINDS := ["Gust", "Push", "Tornado"]
const CLOUDS := ["Smoke Screen", "Spore Puff", "Hailstorm"]
const SHOTS := ["Barbs", "Frostbolt", "Ignite", "Pebble"]

var _lab: Lab
var _floor := 0.0
var _resolved := ""
var _baseline := {}  # what the room had before any spell: it is not cleared away
const GROUPS_OF_SPELLS := ["lasting", "walls", "rocks", "fires", "flares", "flora", "clouds", "shots", "projectiles", "oil_slicks", "winds", "waters", "danger", "lightning"]


func _ready() -> void:
	Library.use_file("user://laws_matrix_check.json")
	Library.clear()
	_lab = load("res://scenes/lab.tscn").instantiate()
	add_child(_lab)
	for k in 30:
		await get_tree().process_frame
	_lab.hold_partner = true
	_floor = _lab._partner.global_position.y
	for group in GROUPS_OF_SPELLS:
		for node in get_tree().get_nodes_in_group(group):
			_baseline[node] = true
	_lab.caster.cast_resolved.connect(func(spell: String, _t: String, _o: Vector2, _a: float, _i: Dictionary) -> void: _resolved = spell)
	if _repeat() > 1:
		for shot in ["Barbs"]:
			for again in _repeat():
				await _barrier_on_shot(shot)
		print("%d failures" % _failures)
		get_tree().quit(1 if _failures > 0 else 0)
		return
	for water in WATERS:
		for fire in FIRES:
			await _water_on_fire(water, fire)
	for wind in WINDS:
		for cloud in CLOUDS:
			await _wind_on_cloud(wind, cloud)
		await _wind_on_fire(wind, "Flare")
	for shot in SHOTS:
		for again in _repeat():
			await _barrier_on_shot(shot)
	Library.clear()
	print("%d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## How many times the shot checks are tried (more of them to hunt for a failure that comes once in a while: `-- repeat=40`).
func _repeat() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("repeat="):
			return int(a.get_slice("=", 1))
	return 1


func _reset() -> void:
	for group in GROUPS_OF_SPELLS:  # whatever a spell made and the room did not have to begin with
		for node in get_tree().get_nodes_in_group(group):
			if not node is Pond and not _baseline.has(node):
				node.queue_free()
	for k in 2:  # (what is being freed pushes once more: it is gone before anyone is put in place)
		await get_tree().physics_frame
	var player: Wizard = _lab.player
	player.stamina = player.max_stamina
	player.global_position = Vector2(ArenaGen.column_x(-16), _floor)
	player.velocity = Vector2.ZERO
	player.facing = 1.0
	player.wet_time = 0.0
	player.burning_time = 0.0
	if not is_instance_valid(_lab._partner) or _lab._partner.dead:
		_lab._spawn_partner()
		await get_tree().physics_frame
	_lab._partner.global_position = Vector2(ArenaGen.column_x(-8), _floor)
	_lab._partner.wet_time = 0.0
	_lab._partner.burning_time = 0.0
	_lab._partner.oiled_time = 0.0
	_lab._partner.max_stamina = Wizard.MAX_STAMINA
	_lab._partner.stamina = Wizard.MAX_STAMINA
	_lab._partner.brain.dormant = true  # (it must not cast, or spend, while the laws are tried)
	for k in 20:
		await get_tree().physics_frame


func _cast(spell_name: String, at: Vector2) -> void:
	var data: Spell = SpellData.SPELLS[spell_name]
	var shape := GestureTemplates.preview_points(data.gesture)
	_resolved = ""
	_lab.caster.cast_stroke(data.buttons, BrainStrokes.offset(shape, at, 1.0))
	for k in 6:
		await get_tree().physics_frame


func _alive(group: String) -> Array:
	return get_tree().get_nodes_in_group(group).filter(func(n) -> bool: return is_instance_valid(n) and not n.is_queued_for_deletion() and not n is Pond)


## The middle of a set of nodes.
func _middle(nodes: Array) -> Vector2:
	var sum := Vector2.ZERO
	for node: Node2D in nodes:
		var at := node.global_position
		if node.has_method("span"):  # (a cloud: its middle along its width; some keep their origin at the world's)
			var edges: Vector2 = node.span()
			at.x = (edges.x + edges.y) * 0.5
			if absf(at.y) < 1.0:
				at.y = _floor - 60.0
		sum += at
	return sum / maxf(1.0, nodes.size())


## Casts a spell over a place, and again a little above and below it: the picture of a spell is not centered on the place it acts at, and what matters here
## is what happens when it does meet the thing.
func _cast_around(spell_name: String, made: Array, beside := true) -> void:
	for dy in [0.0, -45.0, 45.0, -90.0]:
		var living := made.filter(func(n) -> bool: return is_instance_valid(n) and not n.is_queued_for_deletion())
		if living.is_empty():
			return
		var place := _middle(living)  # (read again each time: a flare follows its caster, a sphere rolls)
		if beside:
			await _stand_beside(place)
		for node in living:
			if is_instance_valid(node) and node.is_in_group("flares"):  # (a flare hangs where its caster is: a jet or a gust leaves the caster's mouth, so the flare is held in its way)
				node.global_position = _lab.player.center() + Vector2(70.0, -6.0 + dy * 0.0)
		await _cast(spell_name, place + Vector2(0.0, dy))
		await get_tree().physics_frame


## Stands the caster a little way to the left of a place, as a person would to put one thing on another, and lets what follows them settle.
func _stand_beside(place: Vector2) -> void:
	_lab.player.global_position = Vector2(place.x - 90.0, _floor)
	_lab.player.velocity = Vector2.ZERO
	for k in 12:
		await get_tree().physics_frame


func _water_on_fire(water: String, fire: String) -> void:
	await _reset()
	var at: Vector2 = _lab.player.center() + Vector2(150.0, -20.0)
	await _cast(fire, at)
	var made := _alive("fires") + _alive("flares")
	if made.is_empty():
		_verdict(false, "%s put out by %s: the fire was never lit (read as '%s')" % [fire, water, _resolved])
		return
	await _cast_around(water, made, fire != "Flaming Sphere")
	for k in 150:
		for node in made:  # (a flare follows its caster: it is held in the way of the stream, as a person would hold a candle out to it)
			if is_instance_valid(node) and node.is_in_group("flares"):
				node.global_position = _lab.player.tip() + Vector2(70.0, 0.0)
		await get_tree().physics_frame
	var left := 0
	for node in made:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			left += 1
	_verdict(left < made.size(), "%s puts out %s where they meet (%d of %d fires left)" % [water, fire, left, made.size()])


func _wind_on_cloud(wind: String, cloud: String) -> void:
	# The control first: left alone, the cloud must still be there after the same time, or the wind proves nothing.
	await _reset()
	var at: Vector2 = _lab.player.center() + Vector2(150.0, -20.0)
	await _cast(cloud, at)
	var control := _alive("clouds")
	for k in 150:
		await get_tree().physics_frame
	var survived := 0
	for node in control:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			survived += 1
	_verdict(control.size() > 0 and survived > 0, "%s left alone is still there after 2.5 seconds (the control for %s) (%d of %d)" % [cloud, wind, survived, control.size()])
	await _reset()
	await _cast(cloud, at)
	var made := _alive("clouds")
	if made.is_empty():
		_verdict(false, "%s thinned by %s: the cloud was never made (read as '%s')" % [cloud, wind, _resolved])
		return
	await _cast_around(wind, made)
	for k in 150:
		await get_tree().physics_frame
	var left := 0
	for node in made:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			left += 1
	_verdict(left < made.size(), "%s thins away %s where they meet (%d of %d clouds left)" % [wind, cloud, left, made.size()])


func _wind_on_fire(wind: String, flare: String) -> void:
	await _reset()
	var at: Vector2 = _lab.player.center() + Vector2(150.0, -20.0)
	await _cast(flare, at)
	var made := _alive("flares")
	if made.is_empty():
		_verdict(false, "%s put out by %s: it was never lit" % [flare, wind])
		return
	await _cast_around(wind, made)
	for k in 60:
		await get_tree().physics_frame
	var left := 0
	for node in made:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			left += 1
	_verdict(left == 0, "%s puts out a %s (%d left)" % [wind, flare, left])


func _barrier_on_shot(shot: String) -> void:
	await _reset()
	var partner: Wizard = _lab._partner
	partner.raise_shield(30.0)
	partner.global_position = Vector2(ArenaGen.column_x(-14), _floor)
	var before := partner.stamina + partner.max_stamina
	var data: Spell = SpellData.SPELLS[shot]
	var from: Vector2 = _lab.player.center()
	var to := partner.center()
	_resolved = ""
	_lab.caster.cast_stroke(data.buttons, BrainStrokes.line(from, from + from.direction_to(to) * 90.0))
	for k in 120:
		await get_tree().physics_frame
	_verdict(_resolved == shot, "%s was cast at a wizard under a Barrier (read as '%s')" % [shot, _resolved])
	if partner.stamina + partner.max_stamina < before - 0.5:
		print("  diag: burning %.1f wet %.1f oiled %.1f stamina %.1f max %.1f (was %.1f) at %s; player at %s" % [partner.burning_time, partner.wet_time, partner.oiled_time, partner.stamina, partner.max_stamina, before, partner.global_position, _lab.player.global_position])
		for group in ["fires", "danger", "shots", "clouds"]:
			for node in get_tree().get_nodes_in_group(group):
				print("  diag: %s %s at %s" % [group, node.name, node.global_position if node is Node2D else "-"])
	_verdict(partner.stamina + partner.max_stamina >= before - 0.5, "a Barrier turns away %s: nothing is lost under it (%.1f of %.1f; shield %s)" % [shot, partner.stamina + partner.max_stamina, before, partner.has_shield()])

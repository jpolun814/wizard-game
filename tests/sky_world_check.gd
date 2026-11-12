extends Node

## The sky world (chapter 19): no ground, wizards fly and drift down, pages rise and come round from below, clouds rise past, thunderclouds sting, warn and strike.
##
##     godot --headless --fixed-fps 60 --path . tests/sky_world_check.tscn

var failed := false
var _seen: Node


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failed = true


func _ready() -> void:
	var seed_value := 3
	for s in 400:
		MatchState.begin(s)
		if MatchState.biome_of(1) == "sky" or MatchState.biome_of(2) == "sky":
			seed_value = s
			break
	var at := 1 if MatchState.biome_of(1) == "sky" else 2
	_check(MatchState.biome_of(at) == "sky", "a match reaches the sky world (seed %d, world %d)" % [seed_value, at])
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = seed_value
	MatchState.begin(seed_value)
	MatchState.stage = at  # (the world is entered as a later one of the match, as it always is)
	MatchState.pending = true
	MatchState.ledgers = Pages.start_empty(World.WIZARDS)
	MatchState.vitals = []
	for k in World.WIZARDS:
		MatchState.vitals.append({"alive": true, "max": 200.0, "stamina": 200.0})
	call_deferred("_start")


func _start() -> void:
	reparent(get_tree().root)
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if not (scene is World) or scene == _seen or scene.player == null or scene.ledgers.size() == 0 or scene.nav == null:
		return
	_seen = scene
	set_process(false)
	_run(scene)


func _run(world: World) -> void:
	for k in 10:
		await get_tree().process_frame
	_check(world._flies(), "everyone flies")
	var box := world._fly_box()
	_check(box.size.y > 2000.0, "the sky is tall (%d px)" % int(box.size.y))
	var wizard: Wizard = world.player
	_check(wizard.flying and box.has_point(wizard.global_position), "the player starts in the air, inside the sky")
	var rivals := get_tree().get_nodes_in_group("wizards").filter(func(w: Wizard) -> bool: return w != wizard)
	_check(rivals.size() >= 1 and rivals.all(func(w: Wizard) -> bool: return w.flying and w.brain is SkyBrain and box.has_point(w.global_position)), "rivals fly, with the sky brain")
	# Drifting down.
	var y0 := wizard.global_position.y
	for k in 120:
		await get_tree().physics_frame
	_check(wizard.global_position.y > y0 + 20.0, "a wizard that does nothing drifts down (%d px in two seconds)" % int(wizard.global_position.y - y0))
	# Pages.
	var pages := get_tree().get_nodes_in_group("pages").filter(func(p: Node) -> bool: return p is FallingPage)
	_check(pages.size() >= 6, "pages hang in the air (%d)" % pages.size())
	var drifting := pages.filter(func(p: FallingPage) -> bool: return absf(p.rate) > 1.0)
	_check(not drifting.is_empty(), "and most drift")
	var one: FallingPage = drifting.front()
	var a := one.global_position
	one.seconds += 10.0
	await get_tree().physics_frame
	_check(absf(one.global_position.y - a.y) > 4.0, "a page's place follows the world's age")
	var top := one.box.position.y - FallingPage.ROOM
	var bottom := one.box.end.y + FallingPage.ROOM
	var kept := true
	var came_round := false
	var last := one._at().y
	for k in 600:  # ten minutes of the world, a second at a time
		one.seconds = float(k)
		var y := one._at().y
		kept = kept and y >= top - 1.0 and y <= bottom + 1.0
		came_round = came_round or y > last + 1000.0
		last = y
	_check(kept and came_round and is_instance_valid(one), "a page that rises out of the top of the sky comes back in at the bottom, and is never lost")
	_check(one.rate <= -60.0, "a page rises quickly among the falling wizards (%.0f px/s)" % one.rate)
	# Clouds.
	var clouds := get_tree().get_nodes_in_group("sight_blockers").filter(func(c: Node) -> bool: return c is SkyCloud)
	var storms := get_tree().get_nodes_in_group("thunderclouds")
	_check(clouds.size() >= 6 and storms.size() >= 2, "clouds and thunderclouds fill the sky (%d, %d)" % [clouds.size(), storms.size()])
	var cloud: SkyCloud = clouds.front()
	var p1 := cloud.global_position
	cloud.seconds += 5.0
	cloud._place()
	_check(cloud.global_position != p1, "a cloud moves with the world's age")
	var storm: SkyCloud = storms.front()
	storm.seconds = 3.0
	_check(storm.bolt_at(4) == storm.bolt_at(4) and storm.bolt_at(4) != storm.bolt_at(5), "a bolt's place comes from the seed and its number alone")
	_check(storm.danger_at(storm.global_position), "a thundercloud is a danger")
	# A wizard held inside a thundercloud is hurt by it, bolt after bolt.
	var hurt_before: float = wizard.max_stamina + wizard.stamina
	var inside_for := 0.0
	var blows: Array = []
	wizard.damaged.connect(func(amount: int) -> void: blows.append([snappedf(storm.seconds, 0.01), amount]))
	while inside_for < storm.period * 2.2:
		wizard.global_position = storm.global_position + Vector2(0.0, 40.0)
		wizard.velocity = Vector2.ZERO
		await get_tree().physics_frame
		inside_for += 1.0 / 60.0
	print("   in the storm for %.1f s (a bolt every %.1f s): stamina %.0f of %.0f, region %s, at %s, blows %s" % [inside_for, storm.period, wizard.stamina, wizard.max_stamina, str(storm.region()), str(wizard.center()), str(blows)])
	_check(wizard.max_stamina + wizard.stamina < hurt_before - 1.0, "a wizard who stays in a thundercloud is hurt")
	# Spells that need ground are refused.
	_check(SpellLimits.refusal(wizard, "Stone Wall") == "No ground", "a Stone Wall needs ground")
	_check(SpellLimits.refusal(wizard, "Ignite") == "", "a fireball does not")
	_check(SpellLimits.refusal(wizard, "Featherfall") != "", "and there is no need to fall slowly")
	print("RESULT  ", "FAILED" if failed else "ok")
	get_tree().quit(1 if failed else 0)

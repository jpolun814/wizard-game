extends Node

## The portal world: portals open on a rhythm, each a colour of its own, and walking into one brings you out of another.
##
##     godot --headless --fixed-fps 60 --path . tests/portal_world_check.tscn

var failed := false
var _seen: Node
var out_dir := ""


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failed = true


func _ready() -> void:
	var seed_value := -1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			out_dir = argument.substr(4)
	for s in 400:
		MatchState.begin(s)
		if MatchState.biome_of(0) == "portals":
			seed_value = s
			break
	_check(seed_value >= 0, "a match can begin in the portal world (seed %d)" % seed_value)
	World.random_start = false
	World.next_seed = seed_value
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
	for k in 6:
		await get_tree().process_frame
	var field: PortalField = world.get_children().filter(func(n: Node) -> bool: return n is PortalField).front()
	var first := field.schedule(0.0)
	_check(first.size() >= 2, "at least two open at the start (%d)" % first.size())
	var again := field.schedule(0.0)
	_check(first == again, "and the same ones open the second time you ask")
	var most := 0
	var shared := 0
	var lasts := true
	for step in 400:
		var age := step * 1.0
		var open := field.schedule(age)
		most = maxi(most, open.size())
		var seen := {}
		for portal in open:
			var tint := PortalField.tint_of(portal["id"]).to_html()
			if seen.has(tint):
				shared += 1
			seen[tint] = true
			if age - portal["born"] >= PortalField.LIFETIME or age < portal["born"]:
				lasts = false
	var reachable_always := true
	var some_in_the_air := false
	for step in 400:
		var open := field.schedule(step * 1.0)
		var grounded := false
		for portal in open:
			grounded = grounded or portal["lift"] <= PortalField.JUMPABLE
			some_in_the_air = some_in_the_air or portal["lift"] > 0.0
		reachable_always = reachable_always and (open.is_empty() or grounded)
	_check(reachable_always, "some portal that is open can always be reached from the ground, by walking or jumping")
	_check(some_in_the_air, "and some hang in the air")
	_check(shared == 0, "no two portals open together share a colour (most open at once: %d)" % most)
	_check(lasts, "each stays open for three intervals and no longer")
	var sizes := {}
	for wave in range(1, 60):
		sizes[field.wave_size(wave)] = true
	_check(sizes.has(0) and sizes.has(8) and not sizes.has(9), "later waves bring none to eight")
	var live := field.open_portals()
	_check(live.size() >= 2, "and the world has them standing (%d)" % live.size())
	if live.size() >= 2:
		var a: FieldPortal = live[0]
		var tints := {}
		for p in live:
			tints[p.tint.to_html()] = true
		_check(tints.size() == live.size(), "each in its own colour")
		world.player.global_position = a.global_position + Vector2(0.0, Portal.RY)
		for k in 8:
			await get_tree().physics_frame
		var landed := false
		for p in live:
			if p != a and world.player.global_position.distance_to(p.global_position + Vector2(0.0, Portal.RY)) < 60.0:
				landed = true
		_check(landed, "stepping into one brings the wizard out of another")
	var riders := {}
	var player := world.player
	field.carried.connect(func(body: Node2D) -> void: riders[body] = riders.get(body, 0) + 1)
	var rider: Wizard = null
	for w in get_tree().get_nodes_in_group("wizards"):
		if w != player and w.brain != null:
			rider = w
	for page in get_tree().get_nodes_in_group("pages"):
		rider.brain._skip[page.get_instance_id()] = 999.0  # with no page it can go for, it looks to the portals
	var grounded := field.open_portals().filter(func(p: FieldPortal) -> bool: return p.lift == 0.0)  # the AI walks to ones on the ground
	grounded.sort_custom(func(a: FieldPortal, b: FieldPortal) -> bool: return a.remaining() > b.remaining())
	var near: FieldPortal = grounded[0]  # the one with the most time left
	rider.global_position = near.global_position + Vector2(-220.0, 0.0)
	rider.brain._goal = ""
	rider.brain._goal_timer = 0.0
	Engine.time_scale = 3.0
	await get_tree().create_timer(12.0, true, false, true).timeout
	print("rider: ", rider.brain.status())
	Engine.time_scale = 1.0
	var ai_rides := 0
	for body in riders:
		if body != player:
			ai_rides += riders[body]
	_check(ai_rides > 0, "and the AI wizards use them too (%d rides by %d wizards)" % [ai_rides, riders.size()])
	if out_dir != "" and DisplayServer.get_name() != "headless" and not field.open_portals().is_empty() and is_instance_valid(world):
		world.player.global_position = field.open_portals()[0].global_position + Vector2(-120.0, 0.0)
		for k in 40:
			await get_tree().physics_frame
		DirAccess.make_dir_recursive_absolute(out_dir)
		get_viewport().get_texture().get_image().save_png(out_dir + "/portals.png")
	print("the portal world opens" if not failed else "portal world check FAILED")
	get_tree().quit(1 if failed else 0)

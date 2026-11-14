extends Node

## Pictures of the ocean world as the player sees it: at the surface over a wreck, by each wreck on the floor, and on the raft they start on.
##
##     godot --path . tests/looks/ocean_look.tscn -- out=DIR   (needs a window)

var failed := false
var _out := ""
var _seen: Node


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failed = true


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.substr(4)
	var seed_value := 3
	for s in 400:
		MatchState.begin(s)
		if MatchState.biome_of(1) == "ocean" or MatchState.biome_of(2) == "ocean":
			seed_value = s
			break
	var at := 1 if MatchState.biome_of(1) == "ocean" else 2
	_check(MatchState.biome_of(at) == "ocean", "a match reaches the ocean world (seed %d, world %d)" % [seed_value, at])
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


func _shot(name: String) -> void:
	for k in 8:
		await get_tree().process_frame
	var path := _out.path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote ", path)


func _run(world: World) -> void:
	for k in 20:
		await get_tree().process_frame
	var wizard: Wizard = world.player
	var wrecks := world.get_children().filter(func(n: Node) -> bool: return n is Wreck)
	_check(not wrecks.is_empty(), "wrecks lie on the floor (%d)" % wrecks.size())
	await _shot("raft")
	var sea_top: float = float(world.graph.surface["sea"]["row"]) * World.TILE
	for k in mini(wrecks.size(), 3):
		var wreck: Wreck = wrecks[k]
		for at in [Vector2(wreck.global_position.x, sea_top + 60.0), wreck.global_position + Vector2(-60.0, -140.0)]:
			wizard.set_physics_process(false)
			wizard.global_position = at
			wizard.reset_physics_interpolation()
			wizard.eyes.snap()
			await _shot("wreck%d_%s" % [k, "surface" if at.y < sea_top + 100.0 else "floor"])
	print("RESULT  " + ("FAILED" if failed else "ok"))
	get_tree().quit(1 if failed else 0)

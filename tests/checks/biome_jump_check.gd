extends Node

## The F1 panel can go to a world of any biome, whatever the match's seed deals: a world is built, then each biome is jumped to in turn.

var _failed := false


func _ready() -> void:
	MatchState.hurry = 1.0
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 3
	MatchState.begin(3)
	reparent(get_tree().root)
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/world.tscn")
	_run()


func _run() -> void:
	for biome: String in SurfaceGen.BIOMES:
		var world: World = await _ready_world()
		world.go_to_biome(biome)
		await _next_world(world)
		var got: String = MatchState.plan()["biome"]
		_check(got == biome, "the jump to %s builds %s" % [biome, got])
	get_tree().quit(1 if _failed else 0)


func _ready_world() -> World:
	while true:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene is World and scene.player != null and scene.nav != null:
			return scene
	return null


func _next_world(old: World) -> World:
	while true:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene is World and scene != old and scene.player != null and scene.nav != null:
			return scene
	return null


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	_failed = _failed or not ok

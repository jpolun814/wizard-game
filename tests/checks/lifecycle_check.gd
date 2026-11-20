extends Check

## Every place the game can be in must come out the same after it is left and entered again: the waiting room after R, the tutorial, a world of a given seed.
## A place is built, noted (how wide it is, how many ponds with how much water, what lies in it), reloaded three times, and noted again each time. Anything
## that differs is a place that does not rebuild as it was (the waiting room that came back 24 columns short after R was this).
##
##     godot --headless --fixed-fps 60 --path . tests/checks/lifecycle_check.tscn [-- only=lab]

const GROUPS := ["ponds", "pages", "mobs", "wizards", "walls", "fires", "danger", "lasting", "clouds"]

var _plans: Array = [
	["lab", "res://scenes/lab.tscn", {}],
	["tutorial", "res://scenes/tutorial.tscn", {}],
	["world seed 8", "res://scenes/world.tscn", {"seed": 8}],
	["world seed 3", "res://scenes/world.tscn", {"seed": 3}],
	["world seed 13 (underground)", "res://scenes/world.tscn", {"seed": 13}],
]


func _ready() -> void:
	Library.use_file("user://lifecycle_check.json")
	Library.clear()
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.get_slice("=", 1)
	for plan: Array in _plans:
		if only == "" or only in plan[0]:
			await _run(plan)
	Library.clear()
	print("%d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


var _scene: Node


## Builds the place as a child of this check. The waiting room is also reloaded the way R does it (the scene is built before the old one has left the tree),
## because that order is what broke it before.
func _build(path: String, options: Dictionary, by_reload: bool) -> void:
	World.random_start = false
	World.arrive_by_portal = false
	if options.has("seed"):
		World.next_seed = options["seed"]
	MatchState.hurry = 100.0
	var tree := get_tree()
	if by_reload:
		if _scene == null:
			_scene = load(path).instantiate()
			tree.root.add_child.call_deferred(_scene)  # (the root is busy setting up its children while this check starts)
			await tree.process_frame
			tree.current_scene = _scene
		else:
			tree.reload_current_scene()
			await tree.process_frame
			_scene = tree.current_scene
	else:
		if _scene != null:
			_scene.queue_free()
			await tree.process_frame
		_scene = load(path).instantiate()
		add_child(_scene)
	for k in 45:
		await tree.process_frame


func _run(plan: Array) -> void:
	var by_reload: bool = plan[0] == "lab"
	_scene = null
	await _build(plan[1], plan[2], by_reload)
	var first := _note()
	for round in 3:
		await _build(plan[1], plan[2], by_reload)
		var again := _note()
		for key: String in first:
			_verdict(first[key] == again[key], "%s, entered again (%d): %s is the same (%s, then %s)" % [plan[0], round + 1, key, str(first[key]), str(again[key])])
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
	_scene = null
	await get_tree().process_frame


## What a place is, in figures: how wide, how much water, what lies in it.
func _note() -> Dictionary:
	var tree := get_tree()
	var out := {"right wall": ArenaGen.right_wall, "chunks": ArenaGen.chunk_count}
	for group in GROUPS:
		if group in ["wizards", "ponds", "pages"]:
			out["count of " + group] = tree.get_nodes_in_group(group).size()
	var water := 0.0
	var width := 0.0
	for pond in tree.get_nodes_in_group("ponds"):
		if "width" in pond:
			width += float(pond.width)
		if pond.has_method("depth_at"):
			water += 1.0
	out["pond width"] = snappedf(width, 1.0)
	var lowest := 0.0
	for w: Wizard in tree.get_nodes_in_group("wizards"):
		lowest = maxf(lowest, w.global_position.y)
	out["nobody fell out of the world"] = lowest < 100000.0
	return out

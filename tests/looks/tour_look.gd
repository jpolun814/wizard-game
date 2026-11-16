extends Node

## A short film of each of the nine places, for the README: every biome is walked into for a moment, one after the other.
##
##     godot --fixed-fps 60 --path . tests/looks/tour_look.tscn -- out=DIR   (needs a window)
##
## Then `python tools/make_gif.py DIR tour.gif --fps 12 --width 440`.

const SECONDS := 1.8          # how long each place is filmed
const EVERY := 5              # a picture every this many physics frames
const ORDER := ["jungle", "graveyard", "mountains", "ashlands", "castle", "underground", "portals", "ocean", "sky"]

var _out := ""
var _seen: Node
var _frame := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	reparent(get_tree().root)
	get_tree().current_scene = null
	_next(0)


## Finds a match whose first three worlds hold this biome, and goes into it.
func _next(k: int) -> void:
	if k >= ORDER.size():
		print("RESULT  ok, %d pictures" % _frame)
		get_tree().quit(0)
		return
	var seed_value := 0
	var at := 0
	for s in 600:
		MatchState.begin(s)
		for stage in 3:
			if MatchState.biome_of(stage) == ORDER[k]:
				seed_value = s
				at = stage
				break
		if MatchState.biome_of(at) == ORDER[k]:
			break
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = seed_value
	MatchState.begin(seed_value)
	MatchState.stage = at
	MatchState.pending = true
	MatchState.ledgers = Pages.start_empty(World.WIZARDS)
	MatchState.vitals = []
	for j in World.WIZARDS:
		MatchState.vitals.append({"alive": true, "max": 200.0, "stamina": 200.0})
	print("place ", ORDER[k], " seed ", seed_value, " world ", at)
	get_tree().change_scene_to_file("res://scenes/world.tscn")
	_wait_for_world(k)


func _wait_for_world(k: int) -> void:
	var world: Node = null
	while true:
		await get_tree().process_frame
		world = get_tree().current_scene
		if world is World and world != _seen and world.player != null and world.ledgers.size() > 0 and world.nav != null:
			break
	_seen = world
	for j in 30:
		await get_tree().process_frame
	for page in get_tree().get_nodes_in_group("pages"):
		page.queue_free()  # (the fan of pages at the start hides the view)
	for group in ["grade", "gray_wash"]:
		for layer: Node in get_tree().get_nodes_in_group(group):
			layer.visible = false
	var walking: bool = ORDER[k] != "sky" and ORDER[k] != "ocean"
	var frames := int(SECONDS * 60.0)
	if walking:
		Input.action_press("move_right")
	for f in frames:
		await get_tree().physics_frame
		if f % EVERY == 0:
			get_viewport().get_texture().get_image().save_png("%s/f%05d.png" % [_out, _frame])
			_frame += 1
	Input.action_release("move_right")
	_next(k + 1)

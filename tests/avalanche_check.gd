extends Node

## An avalanche of the snowy peaks: the slope rumbles before the snow moves, then a wall of snow runs down it and hurts and shoves whoever it
## runs over, once, and not whoever stands elsewhere. The world's age is set, so the one under test comes when it is wanted.
##
##     godot --headless --fixed-fps 60 --path . tests/avalanche_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 4
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await _frames(3)
	var slides := world.get_children().filter(func(n: Node) -> bool: return n is Avalanche)
	_verdict(slides.size() == 1, "the peaks have an avalanche")
	if slides.is_empty():
		get_tree().quit(1)
		return
	var slide: Avalanche = slides[0]
	var tile := float(ArenaGen.TILE)
	var floors: PackedInt32Array = slide.floors
	var player: Wizard = world.player
	player.infinite_time = 0.0
	# Before its time, nothing is dangerous.
	_verdict(_danger_x(slide, floors).is_empty(), "before the first one the slope is quiet")
	# The slope rumbles first, then goes quiet over the start while the snow runs.
	world._stage_time = Avalanche.FIRST + 0.5
	await _frames(3)
	var rumble := _danger_x(slide, floors)
	_verdict(not rumble.is_empty(), "the slope rumbles before the snow moves")
	var start_x: float = rumble[rumble.size() / 2]
	player.global_position = Vector2(start_x, float(floors[int(start_x / tile)]) * tile - 40.0)
	await _frames(3)
	_verdict(player.max_stamina >= 200.0, "and the rumble itself does no harm")
	# Then the snow runs: find its front, and put one wizard in it and keep another out of it.
	world._stage_time = Avalanche.FIRST + Avalanche.WARNING + 1.0
	await _frames(2)
	var front := _danger_x(slide, floors)
	_verdict(not front.is_empty() and absf(float(front[front.size() / 2]) - start_x) > 100.0, "then the snow runs down the slope, away from where it began")
	var at: float = front[front.size() / 2]
	var far := Vector2(at + 1600.0, 0.0)
	far.y = float(floors[clampi(int(far.x / tile), 0, floors.size() - 1)]) * tile - 40.0
	player.global_position = far
	await _frames(4)
	_verdict(player.max_stamina >= 200.0, "a wizard far from the front is unharmed")
	var before := player.max_stamina
	for k in 90:  # the front moves on; keep the wizard in it until it has run them down
		var front_x := _danger_x(slide, floors)
		if front_x.is_empty():
			break
		var x: float = front_x[front_x.size() / 2]
		player.global_position = Vector2(x, float(floors[clampi(int(x / tile), 0, floors.size() - 1)]) * tile - 40.0)
		await get_tree().physics_frame
		if player.max_stamina < before:
			break
	_verdict(player.max_stamina < before, "a wizard in the front is hurt (%d to %d)" % [before, player.max_stamina])
	# Long after, it has gone.
	world._stage_time = Avalanche.FIRST + Avalanche.WARNING + 12.0
	await _frames(3)
	_verdict(_danger_x(slide, floors).is_empty(), "when the snow has run its course the slope is quiet again")
	print("the avalanche comes and goes" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## The x of every place along the world the avalanche says is dangerous right now, from west to east.
func _danger_x(slide: Avalanche, floors: PackedInt32Array) -> Array:
	var found := []
	var tile := float(ArenaGen.TILE)
	for column in range(0, floors.size(), 2):
		var x := (column + 0.5) * tile
		if slide.danger_at(Vector2(x, float(floors[column]) * tile)):
			found.append(x)
	return found


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

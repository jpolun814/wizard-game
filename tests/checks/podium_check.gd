extends Check
## The marble stairs under the spellbook can be walked up and down without jumping.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/podium_check.tscn

var _world: World
var _player: Wizard


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 3
	_world = load("res://scenes/world.tscn").instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_player = _world.player
	for rival in _world.rivals:
		rival.set_physics_process(false)
		rival.global_position = Vector2(-9000.0, -9000.0)
	_world.set_process(false)
	await _wait(0.6)
	var floor_y := _player.global_position.y
	var podium := Podium.new(_player.global_position.x + 260.0, floor_y, true)
	_world.add_child(podium)
	await _wait(0.2)
	var top := floor_y - Podium.HEIGHT
	var highest := floor_y
	for i in 240:  # walk right for four seconds, no jumping
		Input.action_press("move_right")
		await get_tree().physics_frame
		highest = minf(highest, _player.global_position.y)
	print("x moved: ", _player.global_position.x - podium.center_x, " movement_enabled ", _player.movement_enabled)
	Input.action_release("move_right")
	_verdict(highest <= top + 3.0, "a wizard walks up onto the landing without jumping (highest %.0f, landing %.0f)" % [highest, top])
	print("the stairs can be walked" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()

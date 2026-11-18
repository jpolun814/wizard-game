extends Check
## Takes a picture of the bubbles (needs a window): scratch look, not part of the checks.
## The status bubbles round a wizard (StatusBubbles): one for each state, in the order the states began, a clock ring that empties, and a held breath that turns
## into choking when its air is gone.
##
##     godot --headless --path . --fixed-fps 60 tests/checks/bubbles_check.tscn

var _wizard: Wizard


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 8
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var person: Wizard = world.player
	_wizard = person
	_wizard.brain = null
	for found: Wizard in get_tree().get_nodes_in_group("wizards"):
		if found != person:
			found.global_position = Vector2(-9000.0, -9000.0)
	await _frames(30)
	_wizard.coat.oil()
	_wizard.slow_time = 6.0
	_wizard.haste_time = 8.0
	_wizard.infinite_time = 5.0
	_wizard.adrenaline_time = 9.0
	_wizard.rage_time = 5.0
	_wizard.fear_time = 5.0
	_wizard.veil = 2
	_wizard.air_jump_time = 20.0
	_wizard.coat.soak()
	_wizard.feather_time = 9.0
	_wizard.lungs.smother(true)
	await _frames(70)
	var image := get_viewport().get_texture().get_image()
	image.save_png(OS.get_environment("SHOT"))
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

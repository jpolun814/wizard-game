extends Check
## The sounds the game asks for happen when the thing they stand for happens: footsteps only while a wizard walks on the ground under their own
## power (not standing, not riding a wave, not in the air), a landing only on meeting the ground after a fall, and a loop's file can be found.
##
##     godot --headless --path . --fixed-fps 60 tests/checks/sound_cues_check.tscn


class QuietBrain extends WizardBrain:
	func think(_delta: float) -> void:
		pass


var _wizard: Wizard
var _spot: Vector2


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
	_wizard = null
	for found: Wizard in get_tree().get_nodes_in_group("wizards"):
		if found == person:
			continue
		if _wizard == null:
			_wizard = found
		else:
			found.set_physics_process(false)
			found.global_position = Vector2(-9000.0, -9000.0)
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.set_physics_process(false)
		mob.global_position = Vector2(-9000.0, -9000.0)
	for page in get_tree().get_nodes_in_group("pages"):
		page.queue_free()
	_spot = person.global_position
	person.set_physics_process(false)
	person.global_position = Vector2(-9000.0, -9500.0)
	world.set_process(false)
	_wizard.brain = QuietBrain.new(_wizard)
	Sfx.recording = true

	await _on_ground_at_rest()
	await _frames(30)
	_verdict(_count("wizard__step") == 0, "standing still makes no footstep")

	_wizard.walk(Wizard.SPEED)
	await _frames(100)
	_verdict(_count("wizard__step") >= 3, "walking on the ground makes footsteps (%d in 100 frames)" % _count("wizard__step"))

	await _on_ground_at_rest()
	_wizard.surf_dir = 1.0
	_wizard.surf_time = 1.5
	_wizard.walk(Wizard.SPEED)
	Sfx.heard.clear()
	await _frames(60)
	_verdict(_count("wizard__step") == 0, "riding a wave makes no footstep, though the wizard moves and the keys are held")
	_wizard.surf_time = 0.0
	_wizard.walk(0.0)

	await _on_ground_at_rest()
	Sfx.heard.clear()
	_wizard.request_jump()
	await _frames(100)
	_verdict(_count("wizard__step") == 0, "a jump makes no footstep in the air")
	_verdict(_count("wizard__land") == 1, "a jump is heard landing once (%d)" % _count("wizard__land"))

	await _on_ground_at_rest()
	_wizard.global_position.y -= 4.0
	Sfx.heard.clear()
	await _frames(30)
	_verdict(_count("wizard__land") == 0, "settling a few pixels onto the ground is not a landing")

	var sea := Sfx.path_of("Tide Surf", "sea")
	_verdict(ResourceLoader.exists(sea) and load(sea) is AudioStream, "Tide Surf's sea loop can be loaded (%s)" % sea)
	Sfx.recording = false
	print("the cues are as they should be" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _count(prefix: String) -> int:
	var n := 0
	for sound in Sfx.heard:
		if sound.begins_with(prefix):
			n += 1
	return n


func _on_ground_at_rest() -> void:
	_wizard.global_position = _spot
	_wizard.velocity = Vector2.ZERO
	_wizard.stamina = 200.0
	_wizard.max_stamina = 200.0
	_wizard.walk(0.0)
	await _frames(20)
	Sfx.heard.clear()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

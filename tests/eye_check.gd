extends Node

## The Chant of the Scrying Eye. Said once, a round window opens in the bottom right showing another wizard; a little eye floats over that wizard; when they
## fall, another is watched; the ground round the watched wizard is made even when they are far from the player; a brain that has lost track of everyone
## sends out an eye. Add `-- out=DIR` for pictures (needs a window).
##
##     godot --headless --fixed-fps 60 --path . tests/eye_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0
var _world: World
var _player: Wizard
var _out := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.substr(4)
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 8
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):
			World.next_seed = int(arg.substr(5))  # (a graveyard's seed shows the window in grey)
	_world = load("res://scenes/world.tscn").instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_player = _world.player
	for rival in _world._rivals:
		rival.set_physics_process(false)
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.queue_free()
	_player.ledger.learn_all()
	await _wait(0.3)
	await _eye()
	print("biome ", _world.grade_biome, " greyed ", _world.greyed)
	print("the scrying eye sees" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _marks() -> Array:
	return get_tree().get_nodes_in_group("eye_marks").filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion())


func _eye() -> void:
	var window: ScryingEye = _world._eye
	_verdict(not window.visible, "before the chant there is no window")
	_world._on_ritual_finished("scrying_eye", 1.0, false)
	await _wait(0.6)
	_verdict(window.visible, "once the chant is said a window opens")
	_verdict(window.watched != null and window.watched != _player and not window.watched.dead, "it shows another wizard that is standing")
	_verdict(_marks().size() == 1 and _marks()[0].get_parent() == window.watched, "and a little eye floats over them")
	var anchor := window.get_global_rect()
	var view := get_viewport().get_visible_rect().size
	_verdict(anchor.end.x <= view.x and anchor.end.y <= view.y and anchor.position.x > view.x * 0.5 and anchor.position.y > view.y * 0.5, "the window is in the bottom right corner (%s of %s)" % [anchor, view])
	_verdict(_world._minimap.get_global_rect().intersects(anchor) == false or not _world._minimap.visible, "and the minimap is not in its way")
	await _shot("window")
	# The ground round whoever is watched is made, wherever they are.
	var watched: Wizard = window.watched
	watched.global_position = _player.global_position + Vector2(6000.0, 0.0)
	await _wait(1.0)
	var rock = _world._ground.get("_rock_world")
	if rock != null:
		var key := Vector2i(floori(watched.global_position.x / rock._px), floori(watched.global_position.y / rock._px))
		_verdict(rock._built.has(key), "the ground round the watched wizard is made though they are far from the player")
	else:
		print("PASS  (this world's ground is made all at once, so there is none to keep)")
	_verdict(window._camera.is_in_group("ground_watchers"), "the camera is one that keeps the ground made")
	await _shot("far")
	# They fall: another is watched, and the eye leaves them.
	watched.dead = true
	await _wait(1.2)
	var next: Wizard = window.watched
	_verdict(next != watched and (next == null or not next.dead), "when they fall, another wizard is watched")
	_verdict(watched.get_node_or_null("EyeMark") == null or watched.get_node("EyeMark").is_queued_for_deletion(), "and the eye leaves the fallen")
	watched.dead = false
	# A brain that has lost track of everyone sends out an eye.
	var seer: Wizard = null
	for other: Wizard in _world._rivals:
		if is_instance_valid(other) and other != watched and other != next and not other.dead:
			seer = other  # one that was not carried far off above (it would be falling where no ground is made)
	seer.global_position = _player.global_position + Vector2(60.0, -4.0)
	seer.velocity = Vector2.ZERO
	seer.set_physics_process(true)
	seer.ledger.learn("chant:scrying_eye")
	var brain: WizardBrain = seer.brain
	for other: Wizard in _world._rivals:
		if is_instance_valid(other) and other != seer:
			other.fade_time = 100.0  # out of sight
			other.set_physics_process(false)  # and still: they would come at the seer, who stands typing in plain sight of them
	_player.dead = true  # (out of the way: only the faded wizards are left to lose track of)
	for i in 24:  # it stops and types the words, as a person does
		await _wait(0.5)
		if brain._eye_time > 0.0:
			break
	_verdict(brain._eye_time > 0.0, "a brain that has lost track of everyone sends out an eye (%.1f s left)" % brain._eye_time)
	_player.dead = false


func _shot(label: String) -> void:
	if _out == "":
		return
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	get_viewport().get_texture().get_image().save_png("%s/eye_%s.png" % [_out, label])


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

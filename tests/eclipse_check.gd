extends Node

## An Eclipse darkens the screen of whoever watches from inside it, and not of anyone watching from outside; a flare cuts a lit patch out of the dark.
## The wizard's sight inside it is what the AI is held to (`SpellTargets.sight_blocked`), so that is checked here too.
##
##     godot --headless --path . --fixed-fps 60 tests/eclipse_check.tscn
## Add `-- out=DIR` (and no --headless) to save pictures of the screen: outside, inside, and inside with a flare. It prints PASS or FAIL and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	World.random_start = false
	World.next_seed = 8
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var tree := get_tree()
	var feet: Vector2 = world.player.global_position
	var eclipse := Eclipse.new()
	eclipse.position = feet + Vector2(600.0, 0.0)  # cast away from the watcher
	world.add_child(eclipse)
	await _wait(1.0)
	_verdict(_veil_strength(eclipse) == 0.0, "no darkness over the screen of one watching from outside it")
	_picture(out, "outside")
	eclipse.global_position = feet
	await _wait(1.0)
	_verdict(_veil_strength(eclipse) > 0.9, "the screen goes dark for one watching from inside it (%.2f)" % _veil_strength(eclipse))
	_verdict(SpellTargets.sight_blocked(tree, feet, feet + Vector2(300.0, 0.0)), "someone inside cannot see far")
	_verdict(not SpellTargets.sight_blocked(tree, feet, feet + Vector2(40.0, 0.0)), "someone inside sees what is close")
	_picture(out, "inside")
	var flare := Flare.new()
	flare.position = feet + Vector2(220.0, -20.0)
	world.add_child(flare)
	await _wait(0.5)
	_picture(out, "flare")
	flare.queue_free()
	await _wait(11.0)  # the eclipse runs out
	_verdict(not is_instance_valid(eclipse), "the eclipse ends")
	print("eclipse darkens the screen" if _failures == 0 else "%d FAILED" % _failures)
	tree.quit(1 if _failures > 0 else 0)


func _veil_strength(eclipse: Eclipse) -> float:
	return eclipse.veil_strength()


func _wait(seconds: float) -> void:
	for i in int(seconds * 60.0):
		if not is_instance_valid(self):
			return
		await get_tree().physics_frame


func _picture(out: String, name_: String) -> void:
	if out == "":
		return
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("%s/eclipse_%s.png" % [out, name_])


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

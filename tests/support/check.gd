class_name Check
extends Node
## The base of every check that runs as a scene: it keeps the count of what failed, and `_verdict` says whether one thing held. The script that runs
## the checks (tools/run_checks.py) reads "FAIL" and "FAILED" out of what a check prints.

var _failures := 0


## Puts away everyone and everything alive in a world but those kept, so that nothing they do reaches what is being checked: a blow, a push, a spell cast at someone else.
func _put_away_all_but(kept: Array) -> void:
	for body: Node2D in get_tree().get_nodes_in_group("wizards") + get_tree().get_nodes_in_group("mobs"):
		if not kept.has(body):
			body.set_physics_process(false)
			body.set_process(false)
			body.global_position = Vector2(-9000.0, -9000.0)


## Prints one line for one thing that was meant to hold, and counts it if it did not.
func _verdict(ok: bool, what: String) -> void:
	if what == "":
		return
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1

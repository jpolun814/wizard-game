extends Node

## The person who casts a Decoy is told, in words over it, to move it with the arrow keys; the words go once they have, and a decoy that is not theirs
## says nothing. Only the first few of a run say it.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/decoy_hint_check.tscn

var _failures := 0


func _ready() -> void:
	Decoy._hints_given = 0
	var stranger := _decoy(false)
	var mine := _decoy(true)
	for k in 6:
		await get_tree().physics_frame
	_verdict(_hint_of(stranger) == null, "a decoy that is not theirs carries no words")
	_verdict(_hint_of(mine) != null and "arrow" in _hint_of(mine).text, "their own decoy tells them about the arrow keys")
	Input.action_press("decoy_right")
	for k in 4:
		await get_tree().physics_frame
	Input.action_release("decoy_right")
	await get_tree().create_timer(0.7).timeout
	_verdict(_hint_of(mine) == null, "the words go once the decoy has been moved")
	var later := []
	for k in Decoy.HINT_TIMES + 1:
		var each := _decoy(true)
		await get_tree().physics_frame
		await get_tree().physics_frame
		later.append(each)
	_verdict(_hint_of(later[later.size() - 1]) == null, "only the first few decoys of a run say it")
	print("decoy hint check passed" if _failures == 0 else "decoy hint check FAILED")
	get_tree().quit(1 if _failures > 0 else 0)


func _decoy(owned: bool) -> Decoy:
	var decoy := Decoy.new()
	decoy.mine = owned
	add_child(decoy)
	return decoy


func _hint_of(decoy: Decoy) -> Label:
	for child in decoy.get_children():
		if child is Label and is_instance_valid(child) and not child.is_queued_for_deletion():
			return child
	return null


func _verdict(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL  " + what)

extends Node

## A trained network run in the game (PolicyNet): a small one written out by hand gives the numbers worked out on paper, and a network picks the likeliest choice of each group.
##
##     godot --headless --path . tests/policy_net_check.tscn

var _failures := 0


func _ready() -> void:
	var path := "user://policy_net_check.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	# 2 inputs -> 2 hidden (tanh) -> 5 outputs: three for a move, two for a jump.
	file.store_string(JSON.stringify({
		"activation": "tanh",
		"layers": [
			{"w": [[1.0, 0.0], [0.0, -1.0]], "b": [0.0, 0.5]},
			{"w": [[1.0, 0.0], [0.0, 0.0], [0.0, 2.0], [0.0, 0.0], [1.0, 1.0]], "b": [0.0, 0.1, 0.0, 0.3, 0.0]},
		],
		"outputs": {"move": [0, 3], "jump": [3, 5]},
	}))
	file.close()
	var net := PolicyNet.load_file(path)
	_verdict(net != null and net.inputs() == 2, "a network is read from its file")
	var out := net.forward(PackedFloat32Array([0.5, 1.0]))
	var h0 := tanh(0.5)
	var h1 := tanh(-1.0 + 0.5)
	_verdict(absf(out[0] - h0) < 1e-5 and absf(out[2] - 2.0 * h1) < 1e-5 and absf(out[4] - (h0 + h1)) < 1e-5, "and gives the numbers worked out by hand")
	_verdict(net.choose(out, "move") == 0 and net.choose(out, "jump") == 0, "and chooses the likeliest of each group (%d, %d)" % [net.choose(out, "move"), net.choose(out, "jump")])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("the network holds" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _verdict(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1

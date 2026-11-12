extends SceneTree

## An entity network (training/entity_net.py) run in GDScript (PolicyNet, kind "entity") gives the logits the trainer's own network gives, for senses
## with every list empty, full and part full (tests/fixtures/entity_net_fixture.json, written by training/make_entity_fixture.py).
##
##     godot --headless -s tests/entity_net_check.gd

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/entity_net_fixture.json"))
	var net := PolicyNet.from_dict(data["net"])
	var worst := 0.0
	for sample: Dictionary in data["samples"]:
		var got := net.forward(PackedFloat32Array(sample["obs"]))
		var want: Array = sample["logits"]
		for k in want.size():
			worst = maxf(worst, absf(got[k] - float(want[k])))
	var ok := worst < 1e-4 and net.inputs() == int(data["net"]["inputs"])
	print("  %s  the network gives the trainer's logits (%d senses; largest difference %s)" % ["ok    " if ok else "FAILED", data["samples"].size(), str(worst)])
	print("ENTITY NET %s" % ("PASS" if ok else "FAILED"))
	quit(0 if ok else 1)

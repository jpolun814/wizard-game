class_name PolicyNet
extends RefCounted

## A small trained network run in the game: layers of weights read from a JSON file written by training/export_policy.py (or clone_human.py), a tanh (or ReLU)
## between the layers. It turns what a wizard senses into the logits of its choices; `choose` picks the likeliest of each group.

var _layers: Array = []   # each {"w": PackedFloat32Array (rows of outputs), "b": PackedFloat32Array, "in": int, "out": int}
var _relu := false
var _sample := false      # pick among the choices at random, weighted by how likely each is, as the network was trained to (a person does not always do the likeliest thing; a network that always does never jumps)
var _groups := {}          # name -> [from, to) among the outputs


static func load_file(path: String) -> PolicyNet:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return null
	var net := PolicyNet.new()
	net._relu = data.get("activation", "relu") == "relu"
	net._sample = bool(data.get("sample", false))
	for layer: Dictionary in data["layers"]:
		var rows: Array = layer["w"]
		var flat := PackedFloat32Array()
		for row: Array in rows:
			flat.append_array(PackedFloat32Array(row))
		net._layers.append({"w": flat, "b": PackedFloat32Array(layer["b"]), "in": (rows[0] as Array).size(), "out": rows.size()})
	for key: String in data["outputs"]:
		net._groups[key] = data["outputs"][key]
	return net


func inputs() -> int:
	return _layers[0]["in"] if not _layers.is_empty() else 0


func forward(obs: PackedFloat32Array) -> PackedFloat32Array:
	var x := obs
	for i in _layers.size():
		var layer: Dictionary = _layers[i]
		var n: int = layer["in"]
		var w: PackedFloat32Array = layer["w"]
		var b: PackedFloat32Array = layer["b"]
		var y := PackedFloat32Array()
		y.resize(layer["out"])
		for o: int in range(layer["out"]):
			var sum := b[o]
			var base: int = o * n
			for k in n:
				sum += w[base + k] * x[k]
			y[o] = sum
		if i < _layers.size() - 1:
			for o in y.size():
				y[o] = maxf(y[o], 0.0) if _relu else tanh(y[o])
		x = y
	return x


## The index chosen within one named group of outputs: the likeliest, or (for a network trained to act at random) one drawn by weight.
func choose(logits: PackedFloat32Array, group: String, at_random := false) -> int:
	var span: Array = _groups[group]
	var from: int = int(span[0])
	var count: int = int(span[1]) - from
	var best := 0
	for k in range(1, count):
		if logits[from + k] > logits[from + best]:
			best = k
	if not (_sample and at_random):
		return best
	var weights := PackedFloat32Array()
	var total := 0.0
	for k in count:
		weights.append(exp(logits[from + k] - logits[from + best]))
		total += weights[k]
	var roll := randf() * total
	for k in count:
		roll -= weights[k]
		if roll <= 0.0:
			return k
	return best

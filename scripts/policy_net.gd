class_name PolicyNet
extends RefCounted

## A small trained network run in the game: layers of weights read from a JSON file written by training/export_policy.py (or clone_human.py), a tanh (or ReLU)
## between the layers. It turns what a wizard senses into the logits of its choices; `choose` picks the likeliest of each group.
##
## A network of kind "entity" (training/entity_net.py, for HandBrain) reads its senses in parts: each list of like things (the things on the screen,
## the other wizards) through a small encoder of its own, the same for every slot that holds something, pooled into the most and the mean of each
## feature; the rest through a layer of its own; then the head. tests/entity_net_check.tscn checks it computes what the trainer does.

var _layers: Array = []   # each {"w": PackedFloat32Array (rows of outputs), "b": PackedFloat32Array, "in": int, "out": int}
var _relu := false
var _sample := false      # pick among the choices at random, weighted by how likely each is, as the network was trained to (a person does not always do the likeliest thing; a network that always does never jumps)
var _groups := {}          # name -> [from, to) among the outputs
var _entity := false
var _inputs := 0
var _flat_ranges: Array = []  # [from, to) pairs of the senses that are not in a list
var _flat_layer := {}
var _lists: Array = []        # {"name", "from", "slots", "width", "present", "layers": [two layers]}


static func load_file(path: String) -> PolicyNet:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return null
	return from_dict(data)


## A network from what its JSON file holds.
static func from_dict(data: Dictionary) -> PolicyNet:
	var net := PolicyNet.new()
	net._relu = data.get("activation", "relu") == "relu"
	net._sample = bool(data.get("sample", false))
	if data.get("kind", "") == "entity":
		net._entity = true
		net._inputs = int(data["inputs"])
		for span: Array in data["flat"]["ranges"]:
			net._flat_ranges.append([int(span[0]), int(span[1])])
		net._flat_layer = _layer_of(data["flat"]["layer"])
		for list: Dictionary in data["lists"]:
			net._lists.append({"name": list["name"], "from": int(list["from"]), "slots": int(list["slots"]), "width": int(list["width"]),
				"present": int(list["present"]), "layers": [_layer_of(list["layers"][0]), _layer_of(list["layers"][1])]})
		for layer: Dictionary in data["head"]:
			net._layers.append(_layer_of(layer))
	else:
		for layer: Dictionary in data["layers"]:
			net._layers.append(_layer_of(layer))
	for key: String in data["outputs"]:
		net._groups[key] = data["outputs"][key]
	return net


static func _layer_of(layer: Dictionary) -> Dictionary:
	var rows: Array = layer["w"]
	var flat := PackedFloat32Array()
	for row: Array in rows:
		flat.append_array(PackedFloat32Array(row))
	return {"w": flat, "b": PackedFloat32Array(layer["b"]), "in": (rows[0] as Array).size(), "out": rows.size()}


func inputs() -> int:
	if _entity:
		return _inputs
	return _layers[0]["in"] if not _layers.is_empty() else 0


## The lists an entity network reads, each as (first number, slots, numbers a slot, the place that says a slot holds something); none for a plain one.
func list_spans() -> Dictionary:
	var out := {}
	for list: Dictionary in _lists:
		out[list["name"]] = Vector4i(list["from"], list["slots"], list["width"], list["present"])
	return out


func forward(obs: PackedFloat32Array) -> PackedFloat32Array:
	var x := _features(obs) if _entity else obs
	for i in _layers.size():
		x = _apply(_layers[i], x, i < _layers.size() - 1)
	return x


## One layer: the weights times the inputs that are not zero (most of a screen of tiles is empty, so only these are multiplied), plus the bias,
## then the activation unless it is the last.
func _apply(layer: Dictionary, x: PackedFloat32Array, activate: bool) -> PackedFloat32Array:
	var n: int = layer["in"]
	var w: PackedFloat32Array = layer["w"]
	var y: PackedFloat32Array = (layer["b"] as PackedFloat32Array).duplicate()
	var outs: int = layer["out"]
	var lit := PackedInt32Array()
	for k in n:
		if x[k] != 0.0:
			lit.append(k)
	for o: int in range(outs):
		var sum := y[o]
		var base: int = o * n
		for k in lit:
			sum += w[base + k] * x[k]
		y[o] = sum
	if activate:
		for o in y.size():
			y[o] = maxf(y[o], 0.0) if _relu else tanh(y[o])
	return y


## An entity network's reading of the senses (training/entity_net.py EntityExtractor): the rest through its layer, then for each list the most
## and the mean of what its encoder makes of each slot that holds something (zeros when none does).
func _features(obs: PackedFloat32Array) -> PackedFloat32Array:
	var rest := PackedFloat32Array()
	for span: Array in _flat_ranges:
		rest.append_array(obs.slice(span[0], span[1]))
	var out := _apply(_flat_layer, rest, true)
	for list: Dictionary in _lists:
		var width: int = list["width"]
		var layers: Array = list["layers"]
		var size: int = (layers[1] as Dictionary)["out"]
		var most := PackedFloat32Array()
		most.resize(size)
		most.fill(-2.0)
		var mean := PackedFloat32Array()
		mean.resize(size)
		var held := 0
		for s in int(list["slots"]):
			var at: int = int(list["from"]) + s * width
			if obs[at + int(list["present"])] <= 0.5:
				continue
			held += 1
			var enc := _apply(layers[1], _apply(layers[0], obs.slice(at, at + width), true), true)
			for k in size:
				most[k] = maxf(most[k], enc[k])
				mean[k] += enc[k]
		if held == 0:
			most.fill(0.0)
		else:
			for k in size:
				mean[k] /= float(held)
		out.append_array(most)
		out.append_array(mean)
	return out


## The index chosen within one named group of outputs: the likeliest, or (for a network trained to act at random) one drawn by weight. With `allowed`,
## only those indices can be chosen (a choice that cannot be made now, such as a spell not in the book, is masked out, as it was in training).
func choose(logits: PackedFloat32Array, group: String, at_random := false, allowed := PackedInt32Array()) -> int:
	var span: Array = _groups[group]
	var from: int = int(span[0])
	var count: int = int(span[1]) - from
	var can := PackedByteArray()
	can.resize(count)
	can.fill(1 if allowed.is_empty() else 0)
	for k in allowed:
		if k >= 0 and k < count:
			can[k] = 1
	var best := -1
	for k in count:
		if can[k] == 1 and (best < 0 or logits[from + k] > logits[from + best]):
			best = k
	if best < 0:
		return 0
	if not (_sample and at_random):
		return best
	var weights := PackedFloat32Array()
	var total := 0.0
	for k in count:
		weights.append(exp(logits[from + k] - logits[from + best]) if can[k] == 1 else 0.0)
		total += weights[k]
	var roll := randf() * total
	for k in count:
		roll -= weights[k]
		if roll <= 0.0:
			return k
	return best

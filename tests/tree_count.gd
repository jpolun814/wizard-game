extends SceneTree
func _init() -> void:
	for s in 6:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var surf := SurfaceGen.build(1000, "jungle", rng)
		var big := 0
		for t: Dictionary in surf["trees"]:
			if t["size"] >= 2: big += 1
		print("seed ", s, ": ", surf["trees"].size(), " trees, ", big, " climbable, ", surf["mud"].size(), " mud pits")
	quit()

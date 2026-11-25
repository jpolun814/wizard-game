extends GdUnitTestSuite
## The AI's picture of how a body moves (MoveBody), set against how real ones moved (tests/reference/movement_paths.json, recorded from real casts by movement_paths_check): where
## each spell takes a wizard on open level ground. If this fails, the AI plans leaps it will miss.

const NEAR := 26.0   # pixels, at any moment of it
const FLOOR_ROW := 40
const START := 14


func _level_ground() -> MoveMap:
	var cells := TileGrid.new(Vector2i(200, FLOOR_ROW + 4))
	for c in 200:
		for r in range(FLOOR_ROW, FLOOR_ROW + 4):
			cells.put(Vector2i(c, r), ArenaGen.STONE)
	return MoveMap.new(cells, FLOOR_ROW + 4)


func _body(map: MoveMap) -> MoveBody:
	var body := MoveBody.new()
	body.map = map
	body.at = MoveMap.feet(Vector2i(START + 20, FLOOR_ROW - 1))
	body.grounded = true
	return body


## The farthest the pictured body is from the recorded one, over the first seconds.
func _worst(key: String, begin: Callable, seconds := 2.4) -> float:
	var kept: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/reference/movement_paths.json"))
	var path: Array = kept[key]
	var map := _level_ground()
	var body := _body(map)
	var from := body.at
	var dir := 0.0 if key.ends_with("still") else 1.0
	if key.ends_with("jump"):  # (it jumped and went on for 12 frames before the cast)
		body.jump()
		body.air_x = Wizard.SPEED
		for k in 12:
			body.tick(dir)
	begin.call(body)
	var worst := 0.0
	var began := body.time
	while body.time - began < seconds:
		body.tick(dir)
		var frame := (body.time - began) * 60.0  # (frames since the cast; the record is every fourth, the first being one frame after it)
		var k := int((frame - 1.0) / 4.0)
		var part := (frame - 1.0) / 4.0 - k
		if 2 * k + 3 >= path.size():
			break
		var real := Vector2(path[2 * k], path[2 * k + 1]).lerp(Vector2(path[2 * k + 2], path[2 * k + 3]), part)
		if from.x + real.x > ArenaGen.right_edge() + 2000.0 or real.x > 1000.0:
			break  # (the room's wall)
		worst = maxf(worst, (body.at - from).distance_to(real))
	return worst


func _same(key: String, begin: Callable, seconds := 2.4, near := NEAR) -> void:
	var worst := _worst(key, begin, seconds)
	assert_float(worst).override_failure_message("%s: the AI's picture of it is %.0f px off" % [key, worst]).is_less(near)


func test_a_walk_and_a_jump() -> void:
	_same("nothing 0 right", func(_b: MoveBody) -> void: pass)
	_same("nothing 0 jump", func(_b: MoveBody) -> void: pass)


func test_a_drive_up() -> void:
	for hold in ["still", "right", "jump"]:
		_same("Rocket Jump 0 " + hold, func(b: MoveBody) -> void: b.driven(Motion.of("Rocket Jump", "drive")), 2.6, 40.0)


func test_a_lift() -> void:
	for hold in ["still", "right"]:
		_same("Updraft 0 " + hold, func(b: MoveBody) -> void: b.lifts.append({"at": b.at, "lift": Motion.of("Updraft", "lift")}), 1.2, 40.0)


func test_a_throw() -> void:
	var push := Motion.of("Push", "throw")
	for angle in [-90.0, -45.0]:
		_same("Push %d still" % angle, func(b: MoveBody) -> void: b.jets.append({"at": b.at, "throw": push, "way": Vector2.from_angle(deg_to_rad(angle)), "from": b.time + float(push["after"]), "to": INF, "next": 0.0}), 1.6, 60.0)
	var geyser := Motion.of("Geyser", "throw")
	_same("Geyser 0 still", func(b: MoveBody) -> void: b.jets.append({"at": b.at, "throw": geyser, "way": Vector2.UP, "from": b.time + float(geyser["after"]), "to": b.time + float(geyser["after"]) + float(geyser["for"]), "next": 0.0}), 2.2, 70.0)  # (the real one throws twice as it bursts, and so a little higher)


func test_a_carry() -> void:
	for angle in [0.0, -30.0, -55.0]:
		for hold in ["still", "right", "jump"]:
			_same("Shadow Step %d %s" % [angle, hold], func(b: MoveBody) -> void: b.carried(Vector2.from_angle(deg_to_rad(angle)), 300.0), 0.8)  # (later an AI wizard may hop at a seam of the ground, which is no law)


func test_a_slow_fall() -> void:
	_same("Featherfall 0 jump", func(b: MoveBody) -> void: b.fall_most = BodyStates.fall("featherlight"), 2.0, 40.0)

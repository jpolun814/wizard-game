extends GdUnitTestSuite
## Everything left to chance comes from the world's seed (Dice). No script throws dice of its own.

const THEIRS := ["res://scripts/core/dice.gd", "res://scripts/core/steady_run.gd"]


func _scripts(folder: String, out: Array[String]) -> Array[String]:
	for name in DirAccess.get_files_at(folder):
		if name.ends_with(".gd"):
			out.append(folder + "/" + name)
	for name in DirAccess.get_directories_at(folder):
		_scripts(folder + "/" + name, out)
	return out


func _rolls() -> RegEx:
	var rolls := RegEx.new()
	rolls.compile("(?<![\\w.])(randf|randi|randf_range|randi_range|randfn|randomize|seed)\\(|\\.(pick_random|shuffle|randomize)\\(")
	return rolls


func test_no_script_throws_dice_of_its_own() -> void:
	var rolls := _rolls()
	var found := PackedStringArray()
	for path in _scripts("res://scripts", []):
		if path in THEIRS:
			continue
		var at := 0
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			at += 1
			if not line.strip_edges().begins_with("#") and rolls.search(line.split("  #")[0]) != null:
				found.append("%s:%d %s" % [path, at, line.strip_edges()])
	assert_array(found).override_failure_message("these throw dice that do not come from the world's seed (see Dice):\n" + "\n".join(found)).is_empty()


func test_the_search_knows_a_roll() -> void:
	assert_object(_rolls().search("var a := randf()")).is_not_null()
	assert_object(_rolls().search("list.shuffle()")).is_not_null()
	assert_object(_rolls().search("var a := Dice.looks.randf()")).is_null()


func test_the_same_seed_throws_the_same() -> void:
	var was := Dice.seed_value
	Dice.begin(41)
	var first := Dice.of(["mob", 3]).randi()
	Dice.looks.randf()
	assert_int(Dice.of(["mob", 3]).randi()).is_equal(first)
	assert_int(Dice.of(["mob", 4]).randi()).is_not_equal(first)
	Dice.begin(42)
	assert_int(Dice.of(["mob", 3]).randi()).is_not_equal(first)
	Dice.begin(41)
	assert_int(Dice.of(["mob", 3]).randi()).is_equal(first)
	Dice.begin(was)


func test_a_cast_throws_by_who_cast_it_and_when() -> void:
	var luck := Dice.luck_of("Rival1", 4)
	assert_int(Dice.luck_of("Rival1", 4)).is_equal(luck)
	assert_int(Dice.luck_of("Rival1", 5)).is_not_equal(luck)
	assert_int(Dice.luck_of("Rival2", 4)).is_not_equal(luck)
	Dice.cast(luck)
	var first := Dice.branch().randi()
	Dice.looks.randf()
	Dice.cast(luck)
	assert_int(Dice.branch().randi()).is_equal(first)
	assert_int(Dice.branch().randi()).is_not_equal(first)

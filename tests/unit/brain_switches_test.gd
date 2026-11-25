extends GdUnitTestSuite
## The AI's switches (`BrainProfile.off("name")`) are matched as pieces of text: a switch whose name is part of another's would turn that one off too.
## This reads every name the scripts ask for and fails if one is inside another, so a new switch cannot quietly break an old one.

const FOLDERS := ["res://scripts/brain", "res://scripts/spells", "res://scripts/wizard"]


func _switch_names() -> Array[String]:
	var names: Array[String] = []
	var matcher := RegEx.new()
	matcher.compile("BrainProfile\\.off\\(\"([a-z_]+)\"\\)")
	for folder: String in FOLDERS:
		for file_name: String in DirAccess.get_files_at(folder):
			if not file_name.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(folder + "/" + file_name)
			for found in matcher.search_all(text):
				var name := found.get_string(1)
				if not names.has(name):
					names.append(name)
	return names


func test_the_switches_the_brain_asks_for_are_found() -> void:
	var names := _switch_names()
	assert_bool(names.size() > 30).is_true()
	for wanted in ["facts", "wolf", "nb_attack", "nb_control", "nb_heal", "nb_defense", "nb_ways"]:
		assert_bool(names.has(wanted)).is_true()


func test_no_switch_name_is_part_of_another() -> void:
	var names := _switch_names()
	for a in names:
		for b in names:
			if a != b:
				assert_bool(b.contains(a)).is_false()  # (a is inside b: turning a off would turn b off as well)


func test_a_seat_with_one_switch_off_has_only_that_one_off() -> void:
	var saved := BrainProfile.seat_off
	BrainProfile.seat_off = "nb_heal"
	assert_bool(BrainProfile.off("nb_heal")).is_true()
	for other in ["nb_attack", "nb_control", "nb_defense", "nb_ways", "facts"]:
		assert_bool(BrainProfile.off(other)).is_false()
	BrainProfile.seat_off = saved

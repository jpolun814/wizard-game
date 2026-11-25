extends GdUnitTestSuite
## The AI is to learn a spell from the spell's data, not from lines written about it by name (the owner, 2026-11-25; docs/handoff/23_movement_planning.md, section 8). This counts
## the spell names quoted in scripts/brain. The count may only go down: when you take some out, lower MOST to what the test says. Never raise it: a new spell, or a new
## trick, is put in the spell's data and a rule that reads it.

const MOST := 643


## Every quoted spell name in the code of one script (what follows a # is not code).
func _named_in(text: String, quoted: RegEx) -> int:
	var count := 0
	for line: String in text.split("\n"):
		var code := line
		var at := line.find("#")
		while at >= 0:
			if at == 0 or line[at - 1] == " " or line[at - 1] == "\t":  # (a # inside a string, as in a color, follows its quote)
				code = line.substr(0, at)
				break
			at = line.find("#", at + 1)
		for found in quoted.search_all(code):
			if SpellData.SPELLS.has(found.get_string(1)):
				count += 1
	return count


func test_the_brain_names_no_more_spells_than_it_did() -> void:
	var quoted := RegEx.new()
	quoted.compile("\"([^\"]+)\"")
	var total := 0
	for file_name: String in DirAccess.get_files_at("res://scripts/brain"):
		if file_name.ends_with(".gd"):
			total += _named_in(FileAccess.get_file_as_string("res://scripts/brain/" + file_name), quoted)
	assert_int(total).override_failure_message("scripts/brain quotes %d spell names and may quote at most %d: say what is new in the spell's data instead" % [total, MOST]).is_less_equal(MOST)
	assert_int(total).override_failure_message("scripts/brain quotes only %d spell names now: lower MOST in this test from %d to %d" % [total, MOST, total]).is_equal(MOST)


func test_the_count_finds_names_and_leaves_out_comments() -> void:
	var quoted := RegEx.new()
	quoted.compile("\"([^\"]+)\"")
	assert_int(_named_in("var a := [\"Ignite\", \"Push\"]  # \"Spark\"\n## \"Hex\"\nvar b := \"nothing\"", quoted)).is_equal(2)
	assert_int(_named_in("f(Color(\"#ff0000\"), \"Ignite\")", quoted)).is_equal(1)

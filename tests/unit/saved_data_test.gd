extends GdUnitTestSuite
## What this machine keeps between sessions (the Library's record, the options) must survive being damaged: an empty file, half a file, the wrong kind of value, a
## file from a game that did not have a field yet. The game must start with plain defaults rather than stop. Each test points the Library at a file of its own.

const FILE := "user://saved_data_test.json"
const OPTIONS := "user://saved_data_test.cfg"


func before_test() -> void:
	Library.use_file(FILE)
	GameSettings.path = OPTIONS


func after_test() -> void:
	for f in [FILE, OPTIONS]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	Library.use_file("user://saved_data_test_after.json")
	Library.clear()
	if FileAccess.file_exists("user://saved_data_test_after.json"):
		DirAccess.remove_absolute("user://saved_data_test_after.json")
	GameSettings.path = "user://options.cfg"


func _write(text: String) -> void:
	var file := FileAccess.open(FILE, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	Library.use_file(FILE)


func _still_works() -> void:
	var stats := Library.stats()
	assert_bool(stats is Dictionary).is_true()
	assert_int(int(stats.get("matches", -1))).is_greater_equal(0)
	assert_str(Library.title()).is_not_empty()
	assert_float(Library.rating()).is_greater(0.0)
	Library.record_cast("Ignite", 0.9)  # (and it can be written to again)


func test_a_missing_file_gives_a_blank_record() -> void:
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(FILE)
	Library.use_file(FILE)
	_still_works()


func test_an_empty_file() -> void:
	_write("")
	_still_works()


func test_half_a_file() -> void:
	_write('{"matches": 12, "wins": 3, "pages": {"Ignite": 4}, "casts": {"Ign')
	_still_works()


func test_something_that_is_not_json() -> void:
	_write("this is not a save file" + char(10) + char(0) + char(1))
	_still_works()


func test_json_of_the_wrong_shape() -> void:
	for text in ["[]", "42", '"text"', "null", "true", "[1, 2, {}]"]:
		_write(text)
		_still_works()


func test_fields_of_the_wrong_kind_are_left_out() -> void:
	_write('{"matches": "many", "wins": [], "pages": 7, "casts": null, "history": {}, "rating": "high", "rated": {}}')
	_still_works()
	assert_int(int(Library.stats()["matches"])).is_equal(0)


func test_a_file_from_an_older_game_with_fewer_fields_keeps_what_it_has() -> void:
	_write('{"matches": 9, "wins": 4}')
	assert_int(int(Library.stats()["matches"])).is_equal(9)
	assert_int(int(Library.stats()["wins"])).is_equal(4)
	_still_works()


func test_unknown_extra_fields_do_no_harm() -> void:
	_write('{"matches": 2, "from_the_future": {"a": [1, 2, 3]}}')
	assert_int(int(Library.stats()["matches"])).is_equal(2)
	_still_works()


func test_a_huge_history_is_cut_down() -> void:
	var history := []
	for k in Library.MAX_HISTORY + 500:
		history.append({"place": 1, "field": 8, "when": k})
	_write(JSON.stringify({"matches": 1, "history": history}))
	_still_works()
	Library.record_match_end({"place": 2, "field": 8})
	assert_int(Library.history().size()).is_less_equal(Library.MAX_HISTORY)


func test_the_rating_always_has_a_rank() -> void:
	for rating in [-5.0, 0.0, 0.99, 1.0, 5.5, 9.0, 9.001, 1000.0]:
		assert_str(Library.rank_of(rating)).override_failure_message("no rank for a rating of %s" % rating).is_not_empty()


func test_a_damaged_options_file_gives_the_defaults() -> void:
	var file := FileAccess.open(OPTIONS, FileAccess.WRITE)
	file.store_string("[options]\nmaster = \"loud\"\nskip_opening = [1, 2]\nfullscreen = {}\n??? not a line\n")
	file.close()
	GameSettings.load_saved(true)
	for key: String in GameSettings.DEFAULTS:
		assert_bool(typeof(GameSettings.get_value(key)) == typeof(GameSettings.DEFAULTS[key])).override_failure_message("option %s is not a %s after a damaged file" % [key, type_string(typeof(GameSettings.DEFAULTS[key]))]).is_true()


func test_an_empty_options_file_gives_the_defaults() -> void:
	var file := FileAccess.open(OPTIONS, FileAccess.WRITE)
	file.close()
	GameSettings.load_saved(true)
	for key: String in GameSettings.DEFAULTS:
		assert_bool(GameSettings.get_value(key) == GameSettings.DEFAULTS[key]).override_failure_message("option %s is not its default" % key).is_true()

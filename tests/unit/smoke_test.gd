extends GdUnitTestSuite
## The harness itself: tests that must always pass, so a broken runner is seen at once.


func test_the_runner_runs() -> void:
	assert_int(1 + 1).is_equal(2)


func test_the_game_is_visible_to_a_unit_test() -> void:
	assert_bool(SpellData.SPELLS.size() > 40).is_true()
	assert_bool(Engine.get_main_loop().root.has_node("Sfx")).is_true()

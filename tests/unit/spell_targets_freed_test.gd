extends GdUnitTestSuite
## A spell that was following someone asks whether they can still be hurt after they have been freed from the world: the answer is no, and it is not an error
## (a typed argument refused a freed body before the check could answer, and a lingering spell printed an error every frame).


func test_a_body_that_has_been_freed_cannot_be_hurt_and_is_not_an_error() -> void:
	var body := Node2D.new()
	body.free()
	assert_bool(SpellTargets.affects(body)).is_false()


func test_nothing_cannot_be_hurt() -> void:
	assert_bool(SpellTargets.affects(null)).is_false()

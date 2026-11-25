extends GdUnitTestSuite
## What a spell does, as its data says it (`Spell.parts`, docs/handoff/24_spell_terms.md), is written in the shared terms, and the laws that read it (`Motion`) do what they say.

const WHERE := ["self", "with", "ray", "shot", "spray", "target", "place", "world", "creature"]
const NEEDS := ["ground", "water", "footing", "roof"]
const WAYS := ["up", "level", "stroke", "back"]
## Each effect, and the numbers it cannot do without.
const DOES := {
	"carry": ["most"], "drive": ["speed", "for", "way"], "lift": ["pull", "speed", "wide", "high"], "throw": ["speed", "way"], "turn": ["way"], "climb": ["least", "most", "grab"],
	"floor": [], "slick": [], "solid": ["least", "most", "thick"], "pit": ["half_least", "half_most", "deep_least", "deep_most"], "state": ["state"], "body": ["pace", "jump"],
}


func _why(spell: Spell, what: String) -> String:
	return "%s: %s" % [spell.spell_name, what]


func test_every_part_is_written_in_the_shared_terms() -> void:
	var written := 0
	for spell: Spell in SpellData.SPELLS.values():
		for part in spell.parts:
			written += 1
			assert_bool(part.get("where", "") in WHERE).override_failure_message(_why(spell, "acts nowhere we know of: %s" % [part.get("where", "")])).is_true()
			assert_bool(not part.has("needs") or part["needs"] in NEEDS).override_failure_message(_why(spell, "needs an unknown thing: %s" % [part.get("needs", "")])).is_true()
			assert_bool(part.get("does", []).size() > 0).override_failure_message(_why(spell, "a part that does nothing")).is_true()
			for one: Dictionary in part.get("does", []):
				var term: String = one.get("do", "")
				assert_bool(DOES.has(term)).override_failure_message(_why(spell, "does an unknown thing: '%s'" % term)).is_true()
				assert_bool(not one.has("way") or one["way"] in WAYS).override_failure_message(_why(spell, "goes an unknown way: %s" % [one.get("way", "")])).is_true()
				for key: String in DOES.get(term, []):
					assert_bool(one.has(key) or part.has(key)).override_failure_message(_why(spell, "its %s does not say '%s'" % [term, key])).is_true()
				if term == "state":
					assert_bool(BodyStates.TABLE.has(one["state"])).override_failure_message(_why(spell, "puts on an unknown state: %s" % [one["state"]])).is_true()
	assert_int(written).is_greater(15)


func test_the_chants_that_move_are_written_in_the_shared_terms() -> void:
	for id: String in ["double_jump", "haste"]:
		var state := RitualInput.effect_of(id, "state")
		assert_bool(BodyStates.TABLE.has(state.get("state", ""))).override_failure_message(id + " puts on no state we know").is_true()
		assert_float(state.get("for", 0.0)).is_greater(0.0)


func test_an_upright_flick_is_moonbeams_and_a_slanted_one_is_not() -> void:
	var umbramancy: Dictionary = SpellData.bindings()[SpellData.SPELLS["Shadow Step"].buttons]
	var up := func(degrees: float) -> String: return StrokeReader.straight_means(umbramancy, Vector2.from_angle(deg_to_rad(-degrees)), Vector2.ZERO, Vector2.ZERO)
	assert_str(up.call(72.0)).is_equal("wall")
	assert_str(up.call(55.0)).is_equal("flick")
	assert_str(up.call(0.0)).is_equal("flick")
	var pyromancy: Dictionary = SpellData.bindings()[SpellData.SPELLS["Ignite"].buttons]
	assert_str(StrokeReader.straight_means(pyromancy, Vector2.UP, Vector2.ZERO, Vector2.ZERO)).is_equal("flick")


func test_an_effect_comes_with_where_and_when_its_part_acts() -> void:
	var drive := Motion.of("Rocket Jump", "drive")
	assert_str(drive["where"]).is_equal("self")
	assert_float(drive["for"]).is_greater(0.0)
	assert_bool(drive.has("does")).is_false()
	assert_bool(Motion.of("Rocket Jump", "climb").is_empty()).is_true()


func test_a_drive_is_steady_or_grows_to_its_speed() -> void:
	var steady := {"for": 2.0, "speed": 100.0}
	assert_float(Motion.drive_speed(steady, 0.0)).is_equal_approx(100.0, 0.01)
	assert_float(Motion.drive_speed(steady, 1.0)).is_equal_approx(100.0, 0.01)
	var grows := {"for": 2.0, "speed": 100.0, "grows": 2.0}
	assert_float(Motion.drive_speed(grows, 0.0)).is_equal_approx(0.0, 0.01)
	assert_float(Motion.drive_speed(grows, 1.0)).is_equal_approx(25.0, 0.01)
	assert_float(Motion.drive_speed(grows, 2.0)).is_equal_approx(100.0, 0.01)


func test_a_lift_goes_no_faster_than_it_says() -> void:
	var lift := {"pull": 1000.0, "speed": 300.0}
	assert_float(Motion.lifted(lift, 0.0, 0.1)).is_equal_approx(-100.0, 0.01)
	assert_float(Motion.lifted(lift, -290.0, 0.1)).is_equal_approx(-300.0, 0.01)


func test_a_carry_is_as_long_as_the_stroke_up_to_its_most() -> void:
	assert_float(Motion.carried({"most": 300.0}, 120.0)).is_equal_approx(120.0, 0.01)
	assert_float(Motion.carried({"most": 300.0}, 900.0)).is_equal_approx(300.0, 0.01)


func test_a_throw_may_be_harder_on_some_bodies() -> void:
	var throw := {"speed": 400.0, "creatures": 200.0}
	assert_float(Motion.thrown(throw, Vector2.UP).y).is_equal_approx(-400.0, 0.01)
	assert_float(Motion.thrown(throw, Vector2.UP, "creatures").y).is_equal_approx(-200.0, 0.01)
	assert_float(Motion.thrown(throw, Vector2.RIGHT, "things").x).is_equal_approx(400.0, 0.01)

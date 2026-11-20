extends GdUnitTestSuite
## The laws of the world (Damage, Substances) on a stand-in body that is no wizard and no creature.


class Body extends Node2D:
	var wet_time := 0.0
	var burning_time := 0.0
	var oiled_time := 0.0
	var fireproof := false

	func is_wet() -> bool:
		return wet_time > 0.0

	func center() -> Vector2:
		return global_position

	func immune_to(kind: String) -> bool:
		return fireproof and kind == Damage.HEAT


func _body() -> Body:
	var body: Body = auto_free(Body.new())
	add_child(body)  # (a flame going out makes smoke beside it)
	return body


func test_each_school_has_a_kind_of_blow() -> void:
	for school in SpellData.SCHOOL_NAMES:
		assert_str(Damage.kind_of(school)).override_failure_message(school + " has no damage kind").is_not_empty()


func test_fire_is_heat_water_is_cold_and_nonsense_is_nothing() -> void:
	assert_str(Damage.kind_of("Fire")).is_equal(Damage.HEAT)
	assert_str(Damage.kind_of("Water")).is_equal(Damage.COLD)
	assert_str(Damage.kind_of("Nonsense")).is_equal("")


func test_only_force_shatters_ice() -> void:
	assert_bool(Damage.shatters(Damage.FORCE)).is_true()
	for kind in [Damage.HEAT, Damage.COLD, Damage.LIGHTNING, Damage.PIERCING, Damage.DARK, Damage.BLOOD]:
		assert_bool(Damage.shatters(kind)).is_false()


func test_lightning_strikes_a_wet_body_harder_and_a_dry_one_not() -> void:
	var body := _body()
	assert_int(Substances.shocked(body, 10)).is_equal(10)
	body.wet_time = 3.0
	assert_int(Substances.shocked(body, 10)).is_greater(10)


func test_a_wet_body_cannot_be_lit() -> void:
	var body := _body()
	body.wet_time = 2.0
	Substances.ignite(body)
	assert_float(body.burning_time).is_equal(0.0)


func test_an_oiled_body_burns_longer_and_the_oil_burns_away() -> void:
	var plain := _body()
	var oily := _body()
	oily.oiled_time = 5.0
	Substances.ignite(plain)
	Substances.ignite(oily)
	assert_float(oily.burning_time).is_greater(plain.burning_time)
	assert_float(oily.oiled_time).is_equal(0.0)


func test_a_body_proof_against_heat_is_not_lit() -> void:
	var body := _body()
	body.fireproof = true
	Substances.ignite(body)
	assert_float(body.burning_time).is_equal(0.0)


func test_water_on_a_burning_body_puts_it_out_and_wets_it() -> void:
	var body := _body()
	body.burning_time = 4.0
	Substances.soak(body)
	assert_float(body.burning_time).is_equal(0.0)
	assert_bool(body.is_wet()).is_true()


func test_heat_ignites_through_the_damage_law_and_cold_does_not() -> void:
	var hot := _body()
	var cold := _body()
	Damage.laws(hot, 5, Damage.HEAT)
	Damage.laws(cold, 5, Damage.COLD)
	assert_float(hot.burning_time).is_greater(0.0)
	assert_float(cold.burning_time).is_equal(0.0)


func test_a_soak_never_shortens_a_longer_wetness() -> void:
	var body := _body()
	body.wet_time = 20.0
	Substances.soak(body, 3.0)
	assert_float(body.wet_time).is_equal(20.0)


func test_ice_holds_a_wet_body_longer() -> void:
	var dry := _body()
	var wet := _body()
	wet.wet_time = 5.0
	assert_float(Substances.frozen_for(wet, 4.0)).is_greater(Substances.frozen_for(dry, 4.0))

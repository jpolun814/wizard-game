extends Check
## Dancing Lights: colorful lights come up round the caster one after another and go, in a set that follows them, that a second cast replaces, that nothing puts
## out and that ends with the caster.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/lights_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.


func _ready() -> void:
	var arena: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(arena)
	for k in 4:
		await get_tree().physics_frame
	var player: Wizard = arena.player
	var spell: Spell = SpellData.SPELLS["Dancing Lights"]
	_verdict(spell.school == "Air" and Pages.every().has("Dancing Lights"), "Dancing Lights is a page of Air")
	Sfx.recording = true
	Sfx.heard.clear()
	arena.spawn_spell("Dancing Lights", spell.targeting, player.center(), 0.0, {}, player)
	for k in 3:
		await get_tree().physics_frame
	var sets := get_tree().get_nodes_in_group("dancing_lights")
	_verdict(sets.size() == 1, "casting it makes one set of lights (%d)" % sets.size())
	var before := get_tree().get_nodes_in_group("flares").size()
	var sprites_before := _sprites(arena)
	await get_tree().create_timer(1.0).timeout
	_verdict(_sprites(arena) > sprites_before, "lights come up round the wizard as it goes on")
	var twinkles := Sfx.heard.filter(func(n: String) -> bool: return n.begins_with("dancing_lights__twinkle")).size()
	_verdict(twinkles >= 4, "and every light that pops up twinkles (%d in about a second)" % twinkles)
	Sfx.recording = false
	player.global_position += Vector2(300.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_verdict(sets.size() == 1 and sets[0].global_position.distance_to(player.center()) < 30.0, "and the set keeps to the caster")
	arena.spawn_spell("Dancing Lights", spell.targeting, player.center(), 0.0, {}, player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var live := get_tree().get_nodes_in_group("dancing_lights").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	_verdict(live.size() == 1, "a second cast replaces the first (%d)" % live.size())
	_verdict(get_tree().get_nodes_in_group("flares").size() == before, "and no flame is made")
	_verdict(not live[0].is_in_group("fires") and not live[0].is_in_group("flares"), "it is no fire, so nothing puts it out")
	await get_tree().create_timer(1.8).timeout  # (the lights from before have gone by now)
	var motes := get_tree().get_nodes_in_group("lights").filter(func(n: Node) -> bool: return n is DancingLights.Mote)
	_verdict(not motes.is_empty() and motes.all(func(m: Node2D) -> bool: return m.global_position.distance_to(player.center()) < DancingLights.FAR + 20.0), "each light shines close to the wizard (%d)" % motes.size())
	_verdict(not motes.is_empty() and SpellTargets.lit_near(get_tree(), motes[0].global_position, 0.0), "and each is a light for sight in the dark")
	_verdict(not live[0].is_in_group("lights"), "the set itself is no light: the lights are")
	player.dead = true
	for k in 6:
		await get_tree().physics_frame
	_verdict(get_tree().get_nodes_in_group("dancing_lights").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).is_empty(), "it goes when the caster falls")
	print("the lights dance" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## How many of the little lights' sprites are in the world.
func _sprites(_arena: Node) -> int:
	return get_tree().get_nodes_in_group("lights").size()

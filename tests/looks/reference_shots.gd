extends Node

## Takes the pictures that tools/look_compare.py compares with the reference pictures: the waiting room (start, beside the pond, beside the lava),
## each biome at a fixed seed, the tutorial's start, and some spells at work. Needs a window; pass --audio-driver Dummy.
##
##     godot --path . --audio-driver Dummy --fixed-fps 60 tests/looks/reference_shots.tscn -- out=DIR

class QuietBrain extends WizardBrain:
	func think(_delta: float) -> void:
		wizard.walk(0.0)

## The biomes, by the seed of a world that begins in each (see CLAUDE.md, "Living scenery").
const WORLDS := {"jungle": 0, "graveyard": 1, "peaks": 4, "ashlands": 5, "underground": 13}

var _out := ""
var _scene: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	Library.use_file("user://reference_shots.json")
	Library.clear()
	await _screens()
	await _stats()
	await _tutorial()
	for biome: String in WORLDS:
		await _world(biome, WORLDS[biome])
	await _in_the_room()
	await _lab()  # (last: the room widens the world's static width, which the places before it must not see)
	Library.clear()
	get_tree().quit()


func _shot(name: String) -> void:
	for k in 20:
		await get_tree().physics_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])


func _swap(scene: Node) -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
		await get_tree().process_frame
	_scene = scene
	Dice.reset(7)  # (before the scene is built: it scatters its props with the global dice)
	add_child(scene)
	for k in 60:
		await get_tree().physics_frame


func _lab() -> void:
	Lab.plain_room = false
	await _swap(load("res://scenes/lab.tscn").instantiate())
	var lab: Lab = _scene
	lab.hold_partner = true
	await _shot("lab_start")
	lab.player.global_position = Vector2(ArenaGen.column_x(Lab.POND.x + Lab.SHIFT) - 150.0, ArenaGen.GROUND_Y - 120.0)
	await _shot("lab_pond")
	lab.player.global_position = Vector2(ArenaGen.column_x(Lab.LAVA.x + Lab.SHIFT) - 150.0, ArenaGen.GROUND_Y - 120.0)
	await _shot("lab_lava")
	lab.player.global_position = Vector2(ArenaGen.column_x(-16), ArenaGen.GROUND_Y - 100.0)
	for spell_name in ["Firewall", "Blizzard", "Geyser", "Oil Slick"]:
		for group in ["lasting", "fires", "clouds", "oil_slicks"]:
			for node in get_tree().get_nodes_in_group(group):
				if node.has_method("setup"):
					node.queue_free()
		await get_tree().physics_frame
		var data: Spell = SpellData.SPELLS[spell_name]
		var shape := GestureTemplates.preview_points(data.gesture)
		lab.caster.cast_stroke(data.buttons, BrainStrokes.offset(shape, lab.player.center() + Vector2(150.0, -20.0), 1.0))
		for k in 50:
			await get_tree().physics_frame
		await _shot("spell_" + spell_name.to_lower().replace(" ", "_"))


## The screens a person reads: the first menu, the Library, and (in the waiting room) an open spellbook page, the pause screen and the line-up of every creature.
func _screens() -> void:
	await _swap(load("res://scenes/menu.tscn").instantiate())
	await _shot("screen_menu")
	await _swap(load("res://scenes/library.tscn").instantiate())
	await _shot("screen_library")


func _in_the_room() -> void:
	Lab.plain_room = false
	await _swap(load("res://scenes/lab.tscn").instantiate())
	var lab: Lab = _scene
	lab.hold_partner = true
	lab.spellbook.show_page("Ignite")
	for k in 90:  # (the book falls open, and its writing shows once it has)
		await get_tree().physics_frame
	await _shot("screen_spellbook_ignite")
	lab.spellbook.show_page("Hex")
	for k in 20:
		await get_tree().physics_frame
	await _shot("screen_spellbook_hex")
	lab.spellbook.show_page("chant:rift")
	for k in 20:
		await get_tree().physics_frame
	await _shot("screen_spellbook_chant")
	lab.spellbook._toggle()
	for k in 40:
		await get_tree().physics_frame
	lab.hud.toggle_pause()
	for k in 20:
		await get_tree().physics_frame
	await _shot("screen_pause")
	lab.hud.toggle_pause()
	var mine: String = GameSettings.get_value("look")  # (the wizard maker is shown with the starting wizard, whatever this machine has chosen)
	GameSettings.set_value("look", PartsLook.DEFAULT_LOOK)
	lab.ritual.likeness_spoken.emit()
	for k in 40:
		await get_tree().physics_frame
	await _shot("screen_wizard_maker")
	for panel in lab.find_children("*", "LikenessPanel", true, false):
		(panel as LikenessPanel).close()
	GameSettings.set_value("look", mine)


## The stats screen the person sees when they fall, with a match's worth of made-up figures (the same each time): its first page and a chart.
func _stats() -> void:
	await _swap(Control.new())
	MatchStats.series.clear()
	for k in 8:
		MatchStats.series.append({"t": k * 20.0, "dealt": k * 25.0, "taken": k * 10.0, "known": 6 + k, "casts": k * 3, "misses": k, "kills": k / 3})
	MatchStats.seconds = 140.0
	var layer := CanvasLayer.new()
	_scene.add_child(layer)
	var screen := StatsScreen.new()
	layer.add_child(screen)
	screen.show_stats(3, 8, true)
	for k in 60:
		await get_tree().physics_frame
	await _shot("screen_stats")
	screen._turn(1)
	for k in 20:
		await get_tree().physics_frame
	await _shot("screen_stats_chart")
	MatchStats.series.clear()


func _tutorial() -> void:
	await _swap(load("res://scenes/tutorial.tscn").instantiate())
	for k in 240:  # (the first prompts fade in, and the page glows and sways: let them settle)
		await get_tree().physics_frame
	await _shot("tutorial_start")


func _world(biome: String, world_seed: int) -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = world_seed
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	await _swap(world)
	for found: Wizard in get_tree().get_nodes_in_group("wizards"):
		if found != world.player:
			found.brain = QuietBrain.new(found)
	await _shot("world_" + biome)
	if biome == "jungle":  # the minimap, shown (it comes with a revealing spell or chant)
		world.revealed["minimap"] = true
		await _shot("world_minimap")

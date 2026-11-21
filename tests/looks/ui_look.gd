extends Node

## Pictures of the interface under a theme, to see a skin on every kind of screen: the home screen, the Library, the waiting room with the stamina bar, the chant box,
## the pause screen and its settings, the tutorial's key hints, and a world's stamina bar. Needs a window; pass --audio-driver Dummy.
##
##     godot --path . --audio-driver Dummy --fixed-fps 60 tests/looks/ui_look.tscn -- theme=project.tres out=DIR

var _out := ""
var _scene: Node


func _ready() -> void:
	var theme_file := "res://ui/theme.tres"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.substr(4)
		elif arg.begins_with("theme="):
			theme_file = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	if theme_file != "project":
		ThemeDB.get_project_theme().merge_with(load(theme_file))  # (what setting gui/theme/custom to this file does; "theme=project" leaves the project's own setting alone)
	Library.use_file("user://ui_look.json")
	Library.clear()
	await _swap(load("res://scenes/menu.tscn").instantiate())
	await _shot("1_menu")
	await _swap(load("res://scenes/library.tscn").instantiate())
	await _shot("2_library")
	await _swap(load("res://scenes/tutorial.tscn").instantiate())
	for k in 240:
		await get_tree().physics_frame
	await _shot("3_tutorial")
	Lab.plain_room = false
	await _swap(load("res://scenes/lab.tscn").instantiate())
	var lab: Lab = _scene
	lab.hold_partner = true
	for k in 30:
		await get_tree().physics_frame
	lab.ritual.open()
	for k in 30:
		await get_tree().physics_frame
	await _shot("4_chant_box")
	lab.ritual.cancel()
	lab.hud.toggle_pause()
	for k in 20:
		await get_tree().physics_frame
	await _shot("5_pause")
	(lab.hud.get_node("Pause/Box/Settings") as Button).pressed.emit()
	for k in 20:
		await get_tree().physics_frame
	await _shot("6_settings")
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
	seed(7)
	add_child(scene)
	for k in 60:
		await get_tree().physics_frame

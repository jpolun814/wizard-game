class_name GameSettings
extends RefCounted

## What this machine's player has chosen about sound, the window and the cut-scenes, kept in `user://options.cfg` so it is there next time.
## Everything here is about the one machine: in a network game each person plays by their own choices. Nothing reads the file until `load_saved`
## is called (the sound autoload does it at start-up), so the tests, which never call it, always see the plain defaults.

static var path := "user://options.cfg"  # (a test points it somewhere else)
const WINDOWED := 0
const FULLSCREEN := 1
const BORDERLESS := 2
const FRAME_CAPS := [0, 60, 120, 144]  # frames a second the game may draw at most; 0 is no limit
const DEFAULTS := {
	"master": 1.0, "effects": 1.0,
	"window": WINDOWED, "vsync": true, "frame_cap": 0,
	"skip_opening": false, "skip_ending": false,
}

static var values: Dictionary = DEFAULTS.duplicate()


static func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS[key])


static func set_value(key: String, value: Variant) -> void:
	values[key] = value
	apply()
	save()


static func skip_opening() -> bool:
	return get_value("skip_opening")


static func skip_ending() -> bool:
	return get_value("skip_ending")


static func load_saved() -> void:
	var file := ConfigFile.new()
	if file.load(path) == OK:
		for key: String in DEFAULTS:
			values[key] = file.get_value("options", key, DEFAULTS[key])
	apply()


static func save() -> void:
	var file := ConfigFile.new()
	for key: String in values:
		file.set_value("options", key, values[key])
	file.save(path)


## Puts the choices to work: the volumes on the sound buses, the window's mode, and whether frames wait for the screen.
static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(get_value("master")), 0.0001)))
	var effects := AudioServer.get_bus_index("SFX")
	if effects >= 0:
		AudioServer.set_bus_volume_db(effects, linear_to_db(maxf(float(get_value("effects")), 0.0001)))
	var mode := DisplayServer.WINDOW_MODE_WINDOWED
	if get_value("window") == FULLSCREEN:
		mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	elif get_value("window") == BORDERLESS:
		mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	Engine.max_fps = int(FRAME_CAPS[clampi(int(get_value("frame_cap")), 0, FRAME_CAPS.size() - 1)])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value("vsync") else DisplayServer.VSYNC_DISABLED)

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
	"look": "", "palette": 0,  # the wizard this person plays (see WizardLook); no look chosen yet is ""
}

static var values: Dictionary = DEFAULTS.duplicate()
static var _window_applied := -1  # the screen choice last put to work; -1 before any


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


static func load_saved(force := false) -> void:
	if not force and _under_test():
		apply()  # a test sees the plain defaults, not what the person at this machine has chosen
		return
	var file := ConfigFile.new()
	if file.load(path) == OK:
		for key: String in DEFAULTS:
			values[key] = file.get_value("options", key, DEFAULTS[key])
	apply()


static func _under_test() -> bool:
	for arg in OS.get_cmdline_args():
		if arg.contains("tests/"):
			return true
	return false


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
	var wanted := int(get_value("window"))
	if wanted != _window_applied:  # only a change to the screen choice touches the window: a window the player maximised stays as it is
		var mode := DisplayServer.WINDOW_MODE_WINDOWED
		if wanted == FULLSCREEN:
			mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		elif wanted == BORDERLESS:
			mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		if _window_applied != -1 or wanted != WINDOWED:
			DisplayServer.window_set_mode(mode)
		_window_applied = wanted
	Engine.max_fps = int(FRAME_CAPS[clampi(int(get_value("frame_cap")), 0, FRAME_CAPS.size() - 1)])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value("vsync") else DisplayServer.VSYNC_DISABLED)

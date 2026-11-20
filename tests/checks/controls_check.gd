extends Check

## The controls table in CLAUDE.md, tried: every action is bound to the key or button the table gives, no two actions share a key by accident, and each one does what it says
## in the waiting room: A and D walk, W and Space jump, Tab opens the spellbook, Enter the chant box, Esc the pause, M mutes. Keys are sent the way the engine sends them (an
## InputEventKey / an action), so a binding that was lost or a handler that stopped listening fails here.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/controls_check.tscn

## action -> the physical keys (or "mouse N" buttons) the table gives it. A key in the list must be bound; a key not in it must not be.
const BINDINGS := {
	"move_left": [KEY_A], "move_right": [KEY_D], "jump": [KEY_W, KEY_SPACE], "move_up": [KEY_W], "move_down": [KEY_S],
	"school_left": ["mouse 1"], "school_right": ["mouse 2"], "school_middle": ["mouse 3"],
	"start_ritual": [KEY_ENTER, KEY_KP_ENTER], "book": [KEY_TAB], "pause": [KEY_ESCAPE], "mute": [KEY_M], "debug_menu": [KEY_F1],
	"restart": [KEY_R], "night_toggle": [KEY_N],
}
## Keys two actions may share on purpose (W jumps, and climbs a vine).
const SHARED := [KEY_W]

var _lab: Lab


func _ready() -> void:
	Library.use_file("user://controls_check.json")
	Library.clear()
	_bindings()
	Lab.plain_room = false
	_lab = load("res://scenes/lab.tscn").instantiate()
	add_child(_lab)
	for k in 40:
		await get_tree().physics_frame
	await _walking()
	await _jumping()
	await _book()
	await _chant_box()
	await _pause()
	_mute()
	Library.clear()
	print("%d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _keys_of(action: String) -> Array:
	var out := []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			out.append(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode)
		elif event is InputEventMouseButton:
			out.append("mouse %d" % event.button_index)
	return out


func _bindings() -> void:
	var owner_of := {}
	for action: String in BINDINGS:
		_verdict(InputMap.has_action(action), "%s: the action exists" % action)
		if not InputMap.has_action(action):
			continue
		var have := _keys_of(action)
		var want: Array = BINDINGS[action]
		for key in want:
			_verdict(key in have, "%s: it is bound to %s" % [action, key if key is String else OS.get_keycode_string(key)])
		for key in have:
			_verdict(key in want, "%s: it is not also bound to something the controls table does not give (%s)" % [action, key if key is String else OS.get_keycode_string(key)])
			if not owner_of.has(key):
				owner_of[key] = []
			owner_of[key].append(action)
	for key in owner_of:
		if owner_of[key].size() > 1 and not key in SHARED:
			_verdict(false, "two actions share the key %s: %s" % [key if key is String else OS.get_keycode_string(key), ", ".join(owner_of[key])])


func _walking() -> void:
	var player: Wizard = _lab.player
	_lab.hold_partner = true
	var start := player.global_position.x
	Input.action_press("move_right")
	for k in 40:
		await get_tree().physics_frame
	Input.action_release("move_right")
	var right := player.global_position.x
	_verdict(right > start + 20.0, "D walks to the right (%.0f px)" % (right - start))
	Input.action_press("move_left")
	var fastest := 0.0
	for k in 60:
		await get_tree().physics_frame
		fastest = minf(fastest, player.velocity.x)
	Input.action_release("move_left")
	_verdict(fastest < -100.0, "A walks to the left (up to %.0f px/s: it first slides on, as it does in the air control)" % -fastest)
	for k in 30:
		await get_tree().physics_frame
	var rest := player.global_position.x
	for k in 20:
		await get_tree().physics_frame
	_verdict(absf(player.global_position.x - rest) < 6.0, "and the wizard stops when the key is let go")


func _jumping() -> void:
	var player: Wizard = _lab.player
	for k in 30:
		await get_tree().physics_frame
	var ground := player.global_position.y
	var peak := ground
	Input.action_press("jump")
	for k in 25:
		await get_tree().physics_frame
		peak = minf(peak, player.global_position.y)
	Input.action_release("jump")
	_verdict(ground - peak > 40.0, "W or Space jumps (%.0f px up)" % (ground - peak))
	for k in 90:
		await get_tree().physics_frame


func _key_of(action: String) -> int:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	return 0


func _key_event(action: String, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = _key_of(action)
	event.physical_keycode = event.keycode
	event.pressed = pressed
	Input.parse_input_event(event)


## Sends the key the way the keyboard does: a press, a frame, a release.
func _send(action: String) -> void:
	_key_event(action, true)
	await get_tree().physics_frame
	_key_event(action, false)
	await get_tree().physics_frame


func _book() -> void:
	var book: Spellbook = _lab.spellbook
	_verdict(not book.visible, "the spellbook starts shut")
	await _send("book")
	for k in 10:
		await get_tree().physics_frame
	_verdict(book.visible, "Tab opens the spellbook")
	await _send("book")
	for k in 40:
		await get_tree().physics_frame
	_verdict(not book.visible, "and Tab shuts it again")


func _chant_box() -> void:
	_verdict(not _lab.ritual.visible, "the chant box starts shut")
	_key_event("start_ritual", true)
	for k in 3:
		await get_tree().physics_frame
	_verdict(_lab.ritual.visible, "Enter opens the chant box")
	_key_event("start_ritual", false)
	for k in 5:
		await get_tree().physics_frame
	_key_event("pause", true)  # (Esc closes it, as the box itself reads the key)
	for k in 3:
		await get_tree().physics_frame
	_key_event("pause", false)
	for k in 5:
		await get_tree().physics_frame
	_verdict(not _lab.ritual.visible, "and Esc closes it")
	_lab.ritual.cancel()


func _pause() -> void:
	_verdict(not _lab.hud.is_paused(), "the game starts unpaused")
	await _send("pause")
	for k in 5:
		await get_tree().physics_frame
	_verdict(_lab.hud.is_paused(), "Esc pauses")
	await _send("pause")
	for k in 5:
		await get_tree().physics_frame
	_verdict(not _lab.hud.is_paused(), "and Esc resumes")


func _mute() -> void:
	var before: bool = Sfx.muted
	var press := InputEventAction.new()
	press.action = "mute"
	press.pressed = true
	Sfx._unhandled_input(press)
	_verdict(Sfx.muted != before, "M mutes")
	Sfx._unhandled_input(press)
	_verdict(Sfx.muted == before, "and M unmutes")
	AudioServer.set_bus_mute(0, false)
	Sfx.muted = false

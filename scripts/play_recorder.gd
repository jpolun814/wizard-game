class_name PlayRecorder
extends Node

## Records how a person plays, for comparing with the AI wizards: F9 starts it and stops it. It writes a file in the game's user folder
## (user://play_logs/) with a line for every key and mouse press, and ten times a second where the wizard is and what it is doing.
## Lines: K (a key or button went down or up), M (the mouse, in the world), S (the wizard), C (a spell or chant said), D (hurt), R (the words typed).

const STATE_GAP := 0.1
const MOUSE_GAP := 0.1

var wizard: Wizard
var ritual: RitualInput
var _file: FileAccess
var _clock := 0.0
var _state_in := 0.0
var _mouse_in := 0.0
var _spell := ""
var _typed := ""


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		_toggle()
		return
	if _file == null:
		return
	if event is InputEventKey and not event.echo:
		_line("K key %s %s" % [OS.get_keycode_string(event.physical_keycode), "down" if event.pressed else "up"])
	elif event is InputEventMouseButton:
		_line("K mouse %d %s %d,%d" % [event.button_index, "down" if event.pressed else "up", _world_mouse().x, _world_mouse().y])


func _process(delta: float) -> void:
	if _file == null or not is_instance_valid(wizard):
		return
	_clock += delta
	_state_in -= delta
	_mouse_in -= delta
	if _mouse_in <= 0.0:
		_mouse_in = MOUSE_GAP
		_line("M %d %d" % [_world_mouse().x, _world_mouse().y])
	if ritual != null and ritual.typed() != _typed:
		_typed = ritual.typed()
		_line("R %s" % _typed)
	if wizard.last_spell != _spell:
		_spell = wizard.last_spell
		_line("C %s" % _spell)
	if _state_in <= 0.0:
		_state_in = STATE_GAP
		_line("S %d %d %d %d %s %d %d %d %d" % [wizard.global_position.x, wizard.global_position.y, wizard.velocity.x, wizard.velocity.y,
			"floor" if wizard.is_on_floor() else "air", wizard.stamina, wizard.max_stamina, 1 if wizard.is_drawing() else 0, wizard.ledger.count()])


func _world_mouse() -> Vector2:
	return wizard.get_global_mouse_position() if is_instance_valid(wizard) else Vector2.ZERO


func _toggle() -> void:
	if _file != null:
		_line("END")
		_file.close()
		_file = null
		print("play recording stopped")
		return
	DirAccess.make_dir_recursive_absolute("user://play_logs")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	_file = FileAccess.open("user://play_logs/play_%s.log" % stamp, FileAccess.WRITE)
	_clock = 0.0
	_spell = ""
	_typed = ""
	if is_instance_valid(wizard) and not wizard.damaged.is_connected(_on_hurt):
		wizard.damaged.connect(_on_hurt)
	_line("START %s" % ProjectSettings.globalize_path("user://play_logs"))
	print("play recording started: ", ProjectSettings.globalize_path("user://play_logs"))


func _on_hurt(amount: int) -> void:
	_line("D %d" % amount)


func _line(text: String) -> void:
	if _file != null:
		_file.store_line("%.2f %s" % [_clock, text])

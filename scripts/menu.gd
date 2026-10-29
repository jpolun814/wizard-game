extends Control

## The first screen: play alone, host a game for friends, or join a friend's game by its address. Hosting and joining both lead to
## the waiting room, which everyone in the game then shares (see Net).

const WAITING_ROOM := "res://scenes/lab.tscn"
const SETTINGS := "user://settings.cfg"  # remembers the last address typed, so a friend's game is one click away next time

@onready var _alone: Button = $Box/Alone
@onready var _host: Button = $Box/Host
@onready var _address: LineEdit = $Box/JoinRow/Address
@onready var _join: Button = $Box/JoinRow/Join
@onready var _status: Label = $Box/Status


func _ready() -> void:
	if Net.online():
		Net.leave()  # back here from a game: this machine plays alone again until it hosts or joins
	_status.text = Net.farewell
	Net.farewell = ""
	var settings := ConfigFile.new()
	if settings.load(SETTINGS) == OK:
		_address.text = settings.get_value("network", "address", "")
	_alone.pressed.connect(_on_alone)
	_host.pressed.connect(_on_host)
	_join.pressed.connect(_on_join)
	_address.text_submitted.connect(func(_text: String) -> void: _on_join())
	Net.roster_changed.connect(_on_roster_changed)
	Net.disconnected.connect(_on_disconnected)
	_alone.grab_focus.call_deferred()


func _on_alone() -> void:
	Sfx.play("ui_click")
	get_tree().change_scene_to_file(WAITING_ROOM)


func _on_host() -> void:
	Sfx.play("ui_click")
	if Net.host() != OK:
		_status.text = "Close the other copy of the game that is hosting, then try again."  # the port is taken
		return
	get_tree().change_scene_to_file(WAITING_ROOM)


func _on_join() -> void:
	Sfx.play("ui_click")
	var address := _address.text.strip_edges()
	if address == "":
		_status.text = "Type the address your friend sees in their waiting room."
		return
	var settings := ConfigFile.new()
	settings.set_value("network", "address", address)
	settings.save(SETTINGS)
	if Net.join(address) != OK:
		_status.text = "Check the address and try again."
		return
	_status.text = ""
	_set_waiting(true)


## While joining, the buttons wait for the answer.
func _set_waiting(waiting: bool) -> void:
	for button: Button in [_alone, _host, _join]:
		button.disabled = waiting
	_address.editable = not waiting
	_join.text = "Joining..." if waiting else "Join"


## The host has given this machine a seat: into the waiting room. (Hosting goes there from _on_host: the roster it makes is not an answer.)
func _on_roster_changed() -> void:
	if Net.online() and not Net.is_host() and Net.seat_of(Net.my_id()) >= 0:
		get_tree().change_scene_to_file(WAITING_ROOM)


func _on_disconnected(reason: String) -> void:
	_set_waiting(false)
	_status.text = reason
	Net.farewell = ""  # said here already

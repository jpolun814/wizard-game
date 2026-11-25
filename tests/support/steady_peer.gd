class_name SteadyPeer
extends MultiplayerPeerExtension

## The line between the copies of the game in a network check, in place of ENet's: what is sent in one frame arrives in the next, on every copy at the
## same frame and in the order it was sent, whatever the machine is doing. It is used only in a run the tests' runner starts (see SteadyRun, which carries
## the messages, and the Hub in tools/steady.py). To Godot's own multiplayer it is a line like any other: a server, clients, refusals, a machine that leaves.

enum {ASK, WELCOME, REFUSE, DATA, GONE}

const SERVER := 1
const GIVE_UP := 480  # frames a client waits for a server to answer (eight seconds of the game)

var _server := false
var _id := 0
var _status := CONNECTION_DISCONNECTED
var _refusing := false
var _target := 0
var _mode := TRANSFER_MODE_RELIABLE
var _channel := 0
var _waited := 0
var _most := 0
var _copy_of := {}   # peer id -> the copy of the game it is
var _peer_of := {}   # the other way about
var _packets: Array = []   # [from, channel, mode, bytes], the oldest first


static func serve(most: int) -> SteadyPeer:
	var peer := SteadyPeer.new()
	peer._server = true
	peer._id = SERVER
	peer._most = most
	peer._status = CONNECTION_CONNECTED
	SteadyRun.lines.append(peer)
	return peer


static func call_up() -> SteadyPeer:
	var peer := SteadyPeer.new()
	peer._id = 1000 + SteadyRun.copy * 100 + SteadyRun.calls
	SteadyRun.calls += 1  # (someone who leaves and comes back is a new peer, as on a real line)
	peer._status = CONNECTION_CONNECTING
	SteadyRun.lines.append(peer)
	SteadyRun.say(-1, [ASK, peer._id])
	return peer


## What another copy said (SteadyRun hands it on when the frame it belongs to comes).
func hear(from: int, said: Array) -> void:
	match said[0]:
		ASK:
			if not _server:
				return
			if _refusing or _copy_of.size() >= _most:
				SteadyRun.say(from, [REFUSE, said[1]])
				return
			_meet(said[1], from)
			SteadyRun.say(from, [WELCOME, said[1]])
			peer_connected.emit(said[1])
		WELCOME:
			if _status == CONNECTION_CONNECTING and said[1] == _id:
				_meet(SERVER, from)
				_status = CONNECTION_CONNECTED
				peer_connected.emit(SERVER)
		REFUSE:
			if _status == CONNECTION_CONNECTING and said[1] == _id:
				_end()
		DATA:
			if said[1] == _id and _peer_of.get(from, 0) == said[2]:
				_packets.append([said[2], said[3], said[4], said[5]])
		GONE:
			if said[2] == _id and _peer_of.get(from, 0) == said[1]:
				_lose(said[1])


## A whole copy of the game has ended.
func copy_gone(from: int) -> void:
	if _peer_of.has(from):
		_lose(_peer_of[from])


func _meet(peer: int, at: int) -> void:
	_copy_of[peer] = at
	_peer_of[at] = peer


func _lose(peer: int) -> void:
	_peer_of.erase(_copy_of.get(peer, -1))
	_copy_of.erase(peer)
	peer_disconnected.emit(peer)
	if peer == SERVER:
		_end()


func _end() -> void:
	_status = CONNECTION_DISCONNECTED
	SteadyRun.lines.erase(self)


func _poll() -> void:
	if _status == CONNECTION_CONNECTING:
		_waited += 1
		if _waited > GIVE_UP:
			_end()


func _put_packet_script(buffer: PackedByteArray) -> Error:
	for peer: int in _copy_of:
		if _target == 0 or _target == peer or (_target < 0 and peer != -_target):
			SteadyRun.say(_copy_of[peer], [DATA, peer, _id, _channel, _mode, buffer])
	return OK


func _get_packet_script() -> PackedByteArray:
	return _packets.pop_front()[3] if not _packets.is_empty() else PackedByteArray()


func _close() -> void:
	for peer: int in _copy_of:
		SteadyRun.say(_copy_of[peer], [GONE, _id, peer])
	_copy_of.clear()
	_peer_of.clear()
	_packets.clear()
	_end()


func _disconnect_peer(peer: int, _force: bool) -> void:
	if _copy_of.has(peer):
		SteadyRun.say(_copy_of[peer], [GONE, _id, peer])
		_lose(peer)


func _get_available_packet_count() -> int:
	return _packets.size()


func _get_packet_peer() -> int:
	return _packets[0][0] if not _packets.is_empty() else 0


func _get_packet_channel() -> int:
	return _packets[0][1] if not _packets.is_empty() else 0


func _get_packet_mode() -> TransferMode:
	return _packets[0][2] if not _packets.is_empty() else TRANSFER_MODE_RELIABLE


func _get_max_packet_size() -> int:
	return 1 << 24


func _get_connection_status() -> ConnectionStatus:
	return _status


func _get_unique_id() -> int:
	return _id


func _is_server() -> bool:
	return _server


func _is_server_relay_supported() -> bool:
	return true


func _is_refusing_new_connections() -> bool:
	return _refusing


func _set_refuse_new_connections(enable: bool) -> void:
	_refusing = enable


func _set_target_peer(peer: int) -> void:
	_target = peer


func _set_transfer_mode(mode: TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> TransferMode:
	return _mode


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel

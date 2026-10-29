extends Node

## The network game, available everywhere as Net. One player hosts and the others join them by address; Godot's own multiplayer
## (an ENetMultiplayerPeer on the SceneTree's MultiplayerAPI) carries everything. With nobody hosting or joining, the tree keeps
## Godot's OfflineMultiplayerPeer: this machine is peer 1 and the authority over every node, so the game plays alone exactly as it
## always has.
##
## How a game is shared (see arena.gd and wizard.gd for the rest):
## - Every wizard is driven by the machine that owns it (its multiplayer authority): a person's by their own game, a brain's by the
##   host's. That machine decides what happens to it (damage, stamina, death) and a MultiplayerSynchronizer shows it to the others.
## - A spell is cast where its wizard is driven and then set off on every machine by one call, so each world sees the same spells.
## - A world is built from its seed on every machine; only the seed and the seats are sent.
## - Each machine says which scene it is in, and nothing about a scene is sent to a machine that is not in it yet.

signal roster_changed
signal scenes_changed
signal disconnected(reason: String)  # the game we joined is gone, or could not be reached

const PORT := 24565
const MENU := "res://scenes/menu.tscn"
const GIVE_UP_MS := 8000  # a host that has not answered for this long is taken to be gone
const VIRTUAL_CARDS := ["vethernet", "virtual", "vmware", "vbox", "hyper-v", "wsl", "loopback", "docker", "tailscale", "zerotier"]
const SEATS := 4  # wizards in a match; the seats nobody takes are played by brains
const LOOKS := ["wizard", "dark_wizard", "pyre_wizard", "bone_wizard"]  # the look of each seat, in order

## The people in the game, by peer id, in the order they came: the host first. A person's seat is their place in this list. Someone who
## leaves during a match leaves a 0 in their seat, so nobody else's seat changes; the waiting room closes the gaps.
var roster: Array[int] = []
## The scene this machine is in now ("" while none is shared): the waiting room, the cut-scene or a world of the match.
var scene := ""
var _scenes := {}  # peer id -> the scene that peer last said it is in
var farewell := ""  # why the last game ended, for the first screen to say


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the menu pauses nothing in a shared game, but a lone game's pause must not drop the line
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


## True while this machine hosts a game or is in one.
func online() -> bool:
	return not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


## True on the machine that hosts (and when playing alone): it plays the brains and keeps the match.
func is_host() -> bool:
	return multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


## Opens a game for others to join. OK, or the error when the port is taken.
func host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, SEATS - 1)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	multiplayer.refuse_new_connections = false
	roster = [1]
	_scenes = {}
	roster_changed.emit()
	return OK


## Starts joining the game at an address ("192.168.1.20", or with its port: "203.0.113.5:24565"). The answer comes later, as
## connected_to_server on the MultiplayerAPI or as disconnected here.
func join(address: String) -> Error:
	var host_name := address.strip_edges()
	var port := PORT
	if host_name.count(":") == 1:  # an address with a port; an IPv6 address has more than one colon and no port here
		port = host_name.get_slice(":", 1).to_int()
		host_name = host_name.get_slice(":", 0)
	if host_name == "":
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host_name, port)
	if error != OK:
		return error
	peer.get_peer(1).set_timeout(0, GIVE_UP_MS / 2, GIVE_UP_MS)  # a wrong address, or a host that is gone, is known in seconds, not half a minute
	multiplayer.multiplayer_peer = peer
	roster = []
	_scenes = {}
	return OK


## Leaves the game, or closes it for everyone when this machine hosts it. Back to playing alone.
func leave() -> void:
	if online():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	roster = []
	_scenes = {}
	scene = ""


## The addresses others on this network can reach the host at: the IPv4 ones of its real network cards, leaving out the loopback and
## the virtual adapters that programs such as WSL, Hyper-V or VirtualBox add, which nobody else can reach.
func local_addresses() -> Array[String]:
	var found: Array[String] = []
	for card: Dictionary in IP.get_local_interfaces():
		var card_name: String = (card["friendly"] + " " + card["name"]).to_lower()
		if VIRTUAL_CARDS.any(func(word: String) -> bool: return card_name.contains(word)):
			continue
		for address: String in card["addresses"]:
			if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."):
				found.append(address)
	return found


## A person's seat: their place in the roster, or -1 for someone not in it.
func seat_of(peer: int) -> int:
	return roster.find(peer)


## The look a person's wizard wears: their seat's.
func look_of(peer: int) -> String:
	return LOOKS[maxi(seat_of(peer), 0)]


## The host keeps new people out once a match has begun, and lets them in again in the waiting room, where the seats of any who left
## are given up.
func set_open(open: bool) -> void:
	if not (online() and is_host()):
		return
	multiplayer.refuse_new_connections = not open
	if open and roster.has(0):
		roster = roster.filter(func(peer: int) -> bool: return peer != 0)
		_set_roster.rpc(roster)
		roster_changed.emit()


# --- Which scene each machine is in -----------------------------------------------------------------------------------


## This machine is now in a scene: everyone else is told, and only now are things about that scene sent here.
func enter_scene(name: String) -> void:
	scene = name
	if online():
		_said_scene.rpc(name)
	scenes_changed.emit()


## The other machines in the same scene as this one.
func peers_here() -> Array[int]:
	var out: Array[int] = []
	for peer: int in _scenes:
		if _scenes[peer] == scene and scene != "" and peer != my_id():
			out.append(peer)
	return out


## True when a peer is in the same scene as this machine.
func is_here(peer: int) -> bool:
	return scene != "" and _scenes.get(peer, "") == scene


## Calls a method of a node on every other machine in this scene. The node must be at the same path on each of them, as every node
## of a shared scene is.
func send(node: Node, method: StringName, args: Array = []) -> void:
	if not online():
		return
	for peer in peers_here():
		node.callv(&"rpc_id", [peer, method] + args)


@rpc("any_peer", "call_remote", "reliable")
func _said_scene(name: String) -> void:
	_scenes[multiplayer.get_remote_sender_id()] = name
	scenes_changed.emit()


# --- Joining and leaving ----------------------------------------------------------------------------------------------


func _on_peer_connected(peer: int) -> void:
	if scene != "":
		_said_scene.rpc_id(peer, scene)  # the newcomer learns where this machine is
	if is_host() and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(peer).set_timeout(0, GIVE_UP_MS / 2, GIVE_UP_MS)  # a friend whose game is gone is known in seconds
	if is_host() and not roster.has(peer):
		roster.append(peer)
		_set_roster.rpc(roster)
		roster_changed.emit()


func _on_peer_disconnected(peer: int) -> void:
	_scenes.erase(peer)
	scenes_changed.emit()
	if is_host() and roster.has(peer):
		if multiplayer.refuse_new_connections:
			roster[roster.find(peer)] = 0  # a match is under way: the seat stays, empty
		else:
			roster.erase(peer)
		_set_roster.rpc(roster)
		roster_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _set_roster(ids: Array) -> void:
	roster.assign(ids)
	roster_changed.emit()


func _on_connected() -> void:
	pass  # the host sends the roster as soon as it sees us; the menu waits for that


func _on_failed() -> void:
	_drop("Check the address and try again.")


func _on_server_gone() -> void:
	_drop("The host has left the game.")


## The game is gone: back to the first screen, which says why.
func _drop(reason: String) -> void:
	leave()
	farewell = reason
	disconnected.emit(reason)
	var here := get_tree().current_scene
	if here == null or here.scene_file_path != MENU:
		get_tree().paused = false
		get_tree().change_scene_to_file(MENU)

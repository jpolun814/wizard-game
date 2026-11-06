extends Node

## Loads, on other cores while the menu is up, the pictures, spell scripts and sounds that spells would otherwise load the first time anyone casts
## them. Without this the first cast of a spell in a match stalls the game for a frame or several (a measured 10-30 ms for Raise Dead, Burst, Barbs
## and Thorn Whip): the stall was the loading, not the spell. Loaded things are kept here, so they stay in memory and `load()` finds them at once.

const FOLDERS := ["res://scripts/spells", "res://art/fx", "res://art/particles", "res://art/props", "res://art/mobs", "res://audio"]
const KINDS := ["gd", "png", "ogg", "wav"]

var _waiting: Array[String] = []
var _kept: Array = []


func _ready() -> void:
	for folder in FOLDERS:
		_queue(folder)
	set_process(not _waiting.is_empty())


func _queue(folder: String) -> void:
	for file in DirAccess.get_files_at(folder):
		var name := file.trim_suffix(".import").trim_suffix(".remap")  # (a built game lists the pictures and scripts under these names)
		var path := folder.path_join(name)
		if path.get_extension() in KINDS and not _waiting.has(path) and ResourceLoader.load_threaded_request(path) == OK:
			_waiting.append(path)
	for sub in DirAccess.get_directories_at(folder):
		_queue(folder.path_join(sub))


func _process(_delta: float) -> void:
	# A few a frame, so that taking in the answers never stalls the menu.
	for k in mini(8, _waiting.size()):
		var path: String = _waiting[_waiting.size() - 1]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_kept.append(ResourceLoader.load_threaded_get(path))
		_waiting.pop_back()
	if _waiting.is_empty():
		set_process(false)

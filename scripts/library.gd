class_name Library
extends RefCounted

## What this machine remembers about the matches played on it, kept between sessions in a file of its own: how many matches were played
## and won, and for each page how often it was found, how often its spell was cast, and how often the match was won with it in the book.
## Only the person at this machine is counted, and only in matches: the waiting room and the tutorial are for trying things.

const PATH := "user://compendium.json"  # (the file kept the name it began with, so what was recorded before is not lost)
static var path := PATH  # a test points this at a file of its own, so it never touches the real one
const SAVE_EVERY := 4000  # milliseconds: casts come thick and fast, so they are written out in batches

static var force := false  # a test of this class turns it on, so its records are kept (with `path` set to a file of its own)
static var _data: Dictionary = {}
static var _loaded := false
static var _dirty := false
static var _saved_at := 0


## What has been recorded, as {"matches": n, "wins": n, "pages": {page: n}, "casts": {spell: n}, "won_with": {page: n}}.
static func stats() -> Dictionary:
	_load()
	return _data


## True when a real game is being played, and not one of the tests that run worlds to see how they behave.
static func _counts() -> bool:
	if force:
		return true
	var scene := (Engine.get_main_loop() as SceneTree).current_scene
	return scene != null and not scene.scene_file_path.begins_with("res://tests/")


static func record_match_begun() -> void:
	if not _counts():
		return
	_load()
	_data["matches"] = int(_data["matches"]) + 1
	_save()


## The person at this machine was the last wizard standing, with these pages in their book.
static func record_win(held_pages: Array) -> void:
	if not _counts():
		return
	_load()
	_data["wins"] = int(_data["wins"]) + 1
	for page: String in held_pages:
		_bump("won_with", page)
	_save()


static func record_page(page: String) -> void:
	if not _counts():
		return
	_load()
	_bump("pages", page)
	_save()


static func record_cast(spell: String) -> void:
	if not _counts():
		return
	_load()
	_bump("casts", spell)
	_dirty = true
	if Time.get_ticks_msec() - _saved_at > SAVE_EVERY:
		_save()


## Writes out anything not written yet. Called when a match ends or the player leaves a world.
static func flush() -> void:
	if _dirty:
		_save()


## Reads from another file than the real one, or the real one again (used by tests).
static func use_file(file_path: String) -> void:
	path = file_path
	_loaded = false


## Forgets everything (used by tests; there is no button for it).
static func clear() -> void:
	_data = _blank()
	_loaded = true
	_save()


static func _bump(table: String, key: String) -> void:
	var entries: Dictionary = _data[table]
	entries[key] = int(entries.get(key, 0)) + 1


static func _blank() -> Dictionary:
	return {"matches": 0, "wins": 0, "pages": {}, "casts": {}, "won_with": {}}


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_data = _blank()
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		for key: String in _data:
			if parsed.has(key) and typeof(parsed[key]) == typeof(_data[key]):
				_data[key] = parsed[key]


static func _save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_data))
	_dirty = false
	_saved_at = Time.get_ticks_msec()

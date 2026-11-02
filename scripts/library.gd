class_name Library
extends RefCounted

## What this machine remembers about the matches played on it, kept between sessions in a file of its own: how many matches were played
## and won, and for each page how often it was found, how often its spell was cast, and how often the match was won with it in the book. The same counts
## are kept for each kind of world (the graveyard, the jungle and so on), so they can be looked at one world at a time; what was recorded before that was
## only counted overall.
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


## A world was entered, of this kind.
static func record_world_entered(biome: String) -> void:
	if not _counts():
		return
	_load()
	_here(biome)["worlds"] = int(_here(biome)["worlds"]) + 1
	_save()


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
	if _world_now() != "":
		var here := _here(_world_now())
		here["wins"] = int(here["wins"]) + 1
	for page: String in held_pages:
		_bump("won_with", page)
		_bump_here("won_with", page)
	_save()


static func record_page(page: String) -> void:
	if not _counts():
		return
	_load()
	_bump("pages", page)
	_bump_here("pages", page)
	_save()


static func record_cast(spell: String) -> void:
	if not _counts():
		return
	_load()
	_bump("casts", spell)
	_bump_here("casts", spell)
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


## The counts for one kind of world, or for all of them when none is named.
static func stats_for(biome: String) -> Dictionary:
	_load()
	if biome == "":
		return _data
	return _here(biome)


## The kind of world being played now, or "" when that cannot be told.
static func _world_now() -> String:
	return MatchState.biome_of(MatchState.stage)


static func _here(biome: String) -> Dictionary:
	var all: Dictionary = _data["in"]
	if not all.has(biome):
		all[biome] = {"worlds": 0, "wins": 0, "pages": {}, "casts": {}, "won_with": {}}
	return all[biome]


static func _bump_here(table: String, key: String) -> void:
	if _world_now() == "":
		return  # no world to count it under: it is counted overall only
	var entries: Dictionary = _here(_world_now())[table]
	entries[key] = int(entries.get(key, 0)) + 1


static func _bump(table: String, key: String) -> void:
	var entries: Dictionary = _data[table]
	entries[key] = int(entries.get(key, 0)) + 1


static func _blank() -> Dictionary:
	return {"matches": 0, "wins": 0, "pages": {}, "casts": {}, "won_with": {}, "in": {}}


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

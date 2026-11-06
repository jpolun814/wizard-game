class_name Library
extends RefCounted

## What this machine remembers about the matches played on it, kept between sessions in a file of its own: how many matches were played
## and won, and for each page how often it was found, how often its spell was cast, and how often the match was won with it in the book. The same counts
## are kept for each kind of world (the graveyard, the jungle and so on), so they can be looked at one world at a time; what was recorded before that was
## only counted overall.
## Only the person at this machine is counted, and only in matches: the waiting room and the tutorial are for trying things.

const PATH := "user://compendium.json"  # (the file kept the name it began with, so what was recorded before is not lost)
static var path := PATH  # a test points this at a file of its own, so it never touches the real one
const TITLE_AFTER := 100       # casts before a wizard earns a school's title; fewer and they are a Novice
const TITLE_SHARE := 0.30      # the share of casts a school needs to give its title
const TITLE_LEAD := 0.05       # a school must lead the next by more than this share, or the spread is even
const MAX_HISTORY := 5000      # matches kept in the Chronicle; each takes about half a kilobyte, so the file never grows past about 2.5 MB
const SAVE_EVERY := 4000  # milliseconds: casts come thick and fast, so they are written out in batches

static var dedicated := false  # a dedicated server (see Net.dedicated) plays no match of its own: nothing it sees is recorded
static var force := false  # a test of this class turns it on, so its records are kept (with `path` set to a file of its own)
static var _data: Dictionary = {}
static var _loaded := false
static var _dirty := false
static var _saved_at := 0


## What has been recorded, as {"matches": n, "wins": n, "pages": {page: n}, "casts": {spell: n}, "won_with": {page: n}, "accuracy_sum": {spell: sum},
## "accuracy_n": {spell: casts judged}, "history": [one summary for each match played to its end, oldest first]}.
static func stats() -> Dictionary:
	_load()
	return _data


## True when a real game is being played, and not one of the tests that run worlds to see how they behave.
static func _counts() -> bool:
	if force:
		return true
	if dedicated:
		return false
	var scene := (Engine.get_main_loop() as SceneTree).current_scene
	return scene != null and not scene.scene_file_path.begins_with("res://tests/")


## Whether this is a match someone is playing, and not one of the tests.
static func real_match() -> bool:
	return _counts()


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


## A match is over for the person at this machine (they won or fell): its summary (see `MatchStats.summary`) goes into the Chronicle. Only the
## newest MAX_HISTORY are kept.
static func record_match_end(summary: Dictionary) -> void:
	if not _counts():
		return
	_load()
	var history: Array = _data["history"]
	history.append(summary)
	while history.size() > MAX_HISTORY:
		history.pop_front()
	_save()


## The matches in the Chronicle, newest first. With a kind of world named, only the matches that went through it.
static func history(biome := "") -> Array:
	_load()
	var out: Array = []
	var all: Array = _data["history"]
	for k in range(all.size() - 1, -1, -1):
		if biome == "" or (all[k].get("worlds", []) as Array).has(biome):
			out.append(all[k])
	return out


static func record_page(page: String) -> void:
	if not _counts():
		return
	_load()
	_bump("pages", page)
	_bump_here("pages", page)
	_save()


## `accuracy` is how closely the stroke matched the spell's shape, from 0 to 1. A cast whose shape could not be judged reports 0 and does not
## count towards the average.
static func record_cast(spell: String, accuracy := 0.0) -> void:
	if not _counts():
		return
	_load()
	_bump("casts", spell)
	_bump_here("casts", spell)
	if accuracy > 0.0:
		var sums: Dictionary = _data["accuracy_sum"]
		sums[spell] = float(sums.get(spell, 0.0)) + clampf(accuracy, 0.0, 1.0)
		_bump("accuracy_n", spell)
	_dirty = true
	if Time.get_ticks_msec() - _saved_at > SAVE_EVERY:
		_save()


## How closely this spell has been drawn on average, from 0 to 1, or -1 when no cast of it has been judged yet.
static func average_accuracy(spell: String) -> float:
	_load()
	var n := int(_data["accuracy_n"].get(spell, 0))
	if n <= 0:
		return -1.0
	return float(_data["accuracy_sum"].get(spell, 0.0)) / n


## The title earned by these casts ({spell: count}): Novice before enough casts, then the school with the biggest share if it has enough of
## them and leads clearly, and Sorcerer for an even spread. Rituals are not spells and are not counted.
static func title_of(casts: Dictionary) -> String:
	var per_school := {}
	var total := 0
	for spell: String in casts:
		if not SpellData.SPELLS.has(spell):
			continue
		var school: String = SpellData.SPELLS[spell].school
		per_school[school] = int(per_school.get(school, 0)) + int(casts[spell])
		total += int(casts[spell])
	if total < TITLE_AFTER:
		return "Novice"
	var best := ""
	var best_share := 0.0
	var second_share := 0.0
	for school: String in per_school:
		var share: float = float(per_school[school]) / total
		if share > best_share:
			second_share = best_share
			best_share = share
			best = school
		elif share > second_share:
			second_share = share
	if best_share < TITLE_SHARE or best_share - second_share <= TITLE_LEAD + 0.0001:  # (a tiny allowance, so an exact lead of 5 points is not lost to rounding)
		return "Sorcerer"
	return SpellData.SCHOOL_TITLES[best]


## This machine's title, from every cast it has recorded.
static func title() -> String:
	_load()
	return title_of(_data["casts"])


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
	return {"matches": 0, "wins": 0, "pages": {}, "casts": {}, "won_with": {}, "accuracy_sum": {}, "accuracy_n": {}, "in": {}, "history": []}


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
	_carry_over("chant:scrying", "chant:dowsing")


## A page that was renamed keeps what was counted under its old name: the Chant of Scrying became the Chant of Dowsing, and a new chant took the old
## word, so the old counts must never be read as the new one's.
static func _carry_over(old: String, fresh: String) -> void:
	var tables: Array = []
	for key in ["pages", "casts", "won_with", "accuracy_sum", "accuracy_n"]:
		tables.append(_data[key])
	for biome: Dictionary in _data["in"].values():
		for key in ["pages", "casts", "won_with"]:
			if biome.get(key) is Dictionary:
				tables.append(biome[key])
	for table: Dictionary in tables:
		if table.has(old):
			table[fresh] = table.get(fresh, 0) + table[old]
			table.erase(old)


static func _save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_data))
	_dirty = false
	_saved_at = Time.get_ticks_msec()

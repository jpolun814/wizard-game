class_name Library
extends RefCounted

## What this machine remembers about the matches played on it, kept between sessions in a file of its own: how many matches were played
## and won, and for each page how often it was found, how often its spell was cast, and how often the match was won with it in the book. The same counts
## are kept for each kind of world (the graveyard, the jungle and so on), so they can be looked at one world at a time; what was recorded before that was
## only counted overall.
## Only the person at this machine is counted, and only in matches: the waiting room and the tutorial are for trying things.

const PATH := "user://compendium.json"  # (the file kept the name it began with, so what was recorded before is not lost)
static var path := PATH  # a test points this at a file of its own, so it never touches the real one
## The ranks, lowest first: a rating from 1 to 9 is the number of the rank (a wizard of rating 6.4 is a Master).
const RANKS := ["Novice", "Apprentice", "Initiate", "Adept", "Magus", "Master", "Grandmaster", "Archmage", "Champion"]
const RATING_START := 1.0
const RATING_STEP_FIRST := 1.0   # how far a first match can move the rating; later ones move it less (see `_rating_step`)
const RATING_STEP_LEAST := 0.25
const RATING_SETTLE := 0.85      # each match leaves this share of the step before it
const AI_LEVEL_NOW := 7          # the level of the wizards in a match until the levels are built (see docs/ai_progress.md)
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
	return scene != null and not scene.scene_file_path.begins_with("res://tests/") and not scene.scene_file_path.ends_with("tutorial.tscn")  # the tutorial is not a match


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
	_data["rating"] = rating_after(float(_data["rating"]), int(_data["rated"]), int(summary.get("place", 0)), int(summary.get("field", 0)), int(summary.get("level", AI_LEVEL_NOW)))
	_data["rated"] = int(_data["rated"]) + 1
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


## A rank is the whole number of a rating (1 to 9), as a name.
static func rank_of(rating: float) -> String:
	return RANKS[clampi(roundi(rating), 1, RANKS.size()) - 1]


## How far one match can move the rating: a new wizard is moved a long way by their first matches and a little by their later ones.
static func _rating_step(matches_rated: int) -> float:
	return maxf(RATING_STEP_FIRST * pow(RATING_SETTLE, matches_rated), RATING_STEP_LEAST)


## The rating after a match: a finish above the middle of the field raises it and one below lowers it, by a step that grows smaller with every match
## rated. A good finish never carries it more than a level past the level of the wizards it beat.
static func rating_after(rating: float, matches_rated: int, place: int, field: int, level: int) -> float:
	if field < 2:
		return rating
	var middle := (field + 1) / 2.0
	var score := clampf((middle - place) / ((field - 1) / 2.0), -1.0, 1.0)
	var moved := rating + _rating_step(matches_rated) * score
	if score > 0.0:
		moved = minf(moved, maxf(rating, float(level + 1)))
	return clampf(moved, 1.0, float(RANKS.size()))


## This machine's rank, from how its matches have gone.
static func title() -> String:
	_load()
	return rank_of(float(_data["rating"]))


## This machine's rating, 1 to 9.
static func rating() -> float:
	_load()
	return float(_data["rating"])


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
	return {"matches": 0, "wins": 0, "pages": {}, "casts": {}, "won_with": {}, "accuracy_sum": {}, "accuracy_n": {}, "in": {}, "history": [], "rating": RATING_START, "rated": 0}


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
			if not parsed.has(key):
				continue
			var saved: Variant = parsed[key]
			if typeof(saved) == typeof(_data[key]):
				_data[key] = saved
			elif typeof(_data[key]) == TYPE_INT and typeof(saved) == TYPE_FLOAT:
				_data[key] = int(saved)  # (JSON has one kind of number, and it comes back as a float: a count saved as 9 is read as 9.0, and used to be thrown out)
	_carry_over("chant:scrying", "chant:dowsing")
	if _data["history"].size() > MAX_HISTORY:
		_data["history"] = _data["history"].slice(_data["history"].size() - MAX_HISTORY)  # (the oldest go: a file from outside, or an older game, may hold more than is kept)


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

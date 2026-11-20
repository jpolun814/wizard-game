extends Check
## Every sound has one owner and nobody shares: each (owner, event) names a sound of its own, that sound has files, no sound name is
## named by two owners, and every Sfx.cue in the scripts asks for a sound that exists. Nothing plays a sound by a bare name.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/sound_ownership_check.tscn


func _ready() -> void:
	await get_tree().process_frame
	var owners := {}  # sound name -> the owner that names it
	var every_has_files := true
	var every_is_its_owners := true
	var shared := ""
	var tables := {}
	for spell: Spell in SpellData.SPELLS.values():
		tables[spell.spell_name] = spell.sounds
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Sfx.REGISTRY))
	for owner: String in registry:
		tables[owner] = registry[owner]
	for owner: String in tables:
		for event: String in tables[owner]:
			var sound: String = tables[owner][event]
			if not Sfx.has_sound(sound):
				every_has_files = false
				print("  no files for ", owner, " / ", event, ": ", sound)
			if owners.has(sound) and owners[sound] != owner:
				shared = "%s is named by %s and %s" % [sound, owners[sound], owner]
			owners[sound] = owner
			if not sound.begins_with(owner.to_lower().replace("'", "_").replace(" ", "_") + "__") and not sound.begins_with(owner.to_lower() + "__"):
				every_is_its_owners = false
				print("  ", sound, " is not named for ", owner)
	_verdict(every_has_files, "every sound an owner names has a file")
	_verdict(shared == "", "no sound is named by two owners " + shared)
	_verdict(every_is_its_owners, "every sound is named for its owner")
	var asked := _scan("res://scripts")
	_verdict(asked["bare"].is_empty(), "nothing plays a sound by a bare name: " + str(asked["bare"]))
	var unresolved := []
	for pair: Array in asked["cues"]:
		if Sfx.sound_of(pair[0], pair[1]) == "":
			unresolved.append("%s / %s" % pair)
	_verdict(unresolved.is_empty(), "every cue in the scripts names an owner and event that have a sound: " + str(unresolved))
	var mobs_ok := true
	for kind: String in Mob.KINDS:
		for event in asked["mob_events"]:
			if Sfx.sound_of("mob_" + kind, event) == "":
				mobs_ok = false
				print("  mob_", kind, " has no ", event)
	_verdict(mobs_ok, "every kind of creature has a sound for every event a creature makes")
	print("sounds are owned" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _scan(folder: String) -> Dictionary:
	var out := {"bare": [], "cues": [], "mob_events": []}
	var literal := RegEx.create_from_string(r'Sfx\.cue\("([^"]+)", "([a-z_]+)"')
	var mob := RegEx.create_from_string(r'Sfx\.cue\("mob_" \+ kind, "([a-z_]+)"')
	var mob_rocks := RegEx.create_from_string(r'"mob_" \+ kind, "rocks" if')
	var bare := RegEx.create_from_string(r'Sfx\.play\("')
	for path in _scripts(folder):
		if path.ends_with("core/sfx.gd"):
			continue
		var text := FileAccess.get_file_as_string(path)
		for hit in literal.search_all(text):
			out["cues"].append([hit.get_string(1), hit.get_string(2)])
		for hit in mob.search_all(text):
			if not out["mob_events"].has(hit.get_string(1)):
				out["mob_events"].append(hit.get_string(1))
		if mob_rocks.search(text) != null:
			out["mob_events"].append_array(["rocks", "whoosh"])
		if bare.search(text) != null:
			out["bare"].append(path)
	return out


func _scripts(folder: String) -> Array:
	var found := []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder + "/" + file)
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder + "/" + sub))
	return found

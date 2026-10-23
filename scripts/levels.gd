class_name Levels
extends RefCounted

## The levels a run goes through, in order. Each level is a list of waves, and each wave maps an enemy
## kind to how many of it arrive. The run plays every wave one at a time, each in a fresh map, with a
## portal between them. Level 1 starts with plain enemies, then brings in each school one at a time.
## Every level ends with a duel against the dark wizard, and each level has its own land.

const LEVELS := [
	{"biome": "cemetery", "waves": [
		{},  # wave 1 is blank for now, so the first portal opens straight away
		{"force_melee": 2},
		{"fire_melee": 2},
		{"ice_ranged": 2},
		{"storm_melee": 2},
		{"earth_melee": 2},
		{"fire_flyer": 2},
		{"storm_flyer": 2},
		{"giant": 1},
		{"ninja": 12},
		{"dark_wizard": 1},
	]},
	{"biome": "swamp", "waves": [
		{"force_ranged": 2, "ice_melee": 2},
		{"earth_ranged": 2},
		{"storm_ranged": 2, "fire_ranged": 2},
		{"ice_flyer": 2},
		{"earth_flyer": 2, "force_flyer": 2},
		{"dark_wizard": 1, "force_flyer": 2},
	]},
	{"biome": "church", "waves": [
		{"fire_melee": 3, "ice_ranged": 2, "storm_flyer": 2},
		{"earth_melee": 3, "storm_ranged": 2, "fire_flyer": 2},
		{"ice_melee": 3, "earth_ranged": 2, "force_flyer": 2, "force_ranged": 2},
		{"dark_wizard": 2, "storm_melee": 2},
	]},
]

## Which wave of the run is next. It survives reloading the scene, and a death resets it.
static var wave_index := 0
## The focus the player carries from map to map during a run.
static var held_focus := "wand"


## Every wave in order, across all the levels.
static func all_waves() -> Array:
	var waves := []
	for level in LEVELS:
		waves.append_array(level["waves"])
	return waves


## Where a wave of the run sits: {"level": 1-based level, "wave": 1-based wave in that level, "count": waves in
## that level, "biome": the level's land}.
static func place_of(index: int) -> Dictionary:
	var remaining := index
	for i in LEVELS.size():
		var waves: Array = LEVELS[i]["waves"]
		if remaining < waves.size():
			return {"level": i + 1, "wave": remaining + 1, "count": waves.size(), "biome": LEVELS[i]["biome"]}
		remaining -= waves.size()
	return {"level": LEVELS.size(), "wave": 1, "count": 1, "biome": LEVELS[LEVELS.size() - 1]["biome"]}

class_name Levels
extends RefCounted

## The levels a run goes through, in order. Each level is a list of waves, and each wave maps an enemy
## kind to how many of it arrive. The run plays every wave one at a time, each in a fresh map, with a
## portal between them. Level 1 starts with plain enemies, then brings in each school one at a time.

const LEVELS := [
	{"waves": [
		{},  # wave 1 is blank for now, so the first portal opens straight away
		{"force_melee": 2},
		{"fire_melee": 2},
		{"ice_ranged": 2},
		{"storm_melee": 2},
		{"earth_melee": 2},
		{"fire_flyer": 2},
		{"storm_flyer": 2},
	]},
	{"waves": [
		{"force_ranged": 2, "ice_melee": 2},
		{"earth_ranged": 2},
		{"storm_ranged": 2, "fire_ranged": 2},
		{"ice_flyer": 2},
		{"earth_flyer": 2, "force_flyer": 2},
	]},
	{"waves": [
		{"fire_melee": 3, "ice_ranged": 2, "storm_flyer": 2},
		{"earth_melee": 3, "storm_ranged": 2, "fire_flyer": 2},
		{"ice_melee": 3, "earth_ranged": 2, "force_flyer": 2, "force_ranged": 2},
	]},
]

## Which wave of the run is next. It survives reloading the scene, and a death resets it.
static var wave_index := 0


## Every wave in order, across all the levels.
static func all_waves() -> Array:
	var waves := []
	for level in LEVELS:
		waves.append_array(level["waves"])
	return waves

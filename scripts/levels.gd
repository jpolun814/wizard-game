class_name Levels
extends RefCounted

## The levels a run goes through, in order. Each level is a list of waves, and each wave maps an enemy
## kind to how many of it arrive. The run plays every wave one at a time, each in a fresh map, with a
## portal between them. Level 1 brings the enemies in one kind at a time, with no text.

const LEVELS := [
	{"waves": [
		{"grunt": 2},
		{"spitter": 2},
		{"blinder": 2},
		{"muter": 2},
		{"rooter": 3},
		{"grunt": 2, "muter": 2, "rooter": 2, "blinder": 2, "spitter": 2},
	]},
	{"waves": [
		{"grunt": 4, "spitter": 2},
		{"muter": 3, "rooter": 3},
		{"blinder": 3, "spitter": 3, "grunt": 2},
	]},
	{"waves": [
		{"rooter": 5, "blinder": 3},
		{"grunt": 3, "muter": 3, "spitter": 3},
		{"grunt": 4, "muter": 3, "rooter": 3, "blinder": 3, "spitter": 3},
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

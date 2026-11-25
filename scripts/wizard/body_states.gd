class_name BodyStates
extends RefCounted

## What each state does to the body that is in it, said once, whatever put it there (docs/handoff/24_spell_terms.md). So far how it moves:
##   pace   the share of its walking speed it keeps (more than 1 is faster)
##   fall   the fastest it falls, in pixels a second
##   jump   false where it cannot jump

const TABLE := {
	"slowed": {"pace": 0.5},
	"mired": {"pace": 0.4, "jump": false},
	"tangled": {"pace": 0.3, "jump": false},
	"hasted": {"pace": 1.6},
	"heavy": {"pace": 0.75},
	"drained": {"pace": 0.7},
	"featherlight": {"fall": 70.0},
}


## How much of its pace a body in this state keeps.
static func pace(state: String) -> float:
	return TABLE[state].get("pace", 1.0)


## The fastest a body in this state falls (as fast as it likes, when the state says nothing of it).
static func fall(state: String) -> float:
	return TABLE[state].get("fall", INF)

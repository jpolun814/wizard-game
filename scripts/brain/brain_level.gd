class_name BrainLevel
extends RefCounted

## The nine levels of the AI wizards, from 1 (slowest and most forgetful) to 9 (a person better than any recorded, but doing nothing a person cannot do).
## A level is a row of knobs. `skill` drives how quick the reactions are, how true the aim and the hand are, how soon it draws and how much it thinks of
## (see WizardBrain.skill); `memory` scales how long it keeps a rival's place and a rival's spells in mind (BrainSight.REMEMBER, BrainProfile.FORGET).
## `slow` and `clumsy` make the low levels worse than the usual wizard (a slower start to a reaction, wider aim and a shakier hand: nothing is botched on purpose) and, below 1,
## make the top two better than the best people recorded (owner, 2026-11-15: the recorded people are a sample, not a ceiling, and no expert has had the practice yet): quicker to
## react, to draw and to type, truer of aim and a steadier hand, and a longer memory. What it may KNOW and DO stays a person's (docs/handoff/18_human_limits.md): only the numbers stretch.
## Level 7 is about the wizard the game has had until now (skill 0.65; the first ladder showed that above skill 0.5 a level's skill barely changes who wins,
## so the levels below are spread over the part of the scale where it does).

const LEVELS := 9
const DEFAULT := 7
const SKILL := [0.05, 0.14, 0.23, 0.32, 0.41, 0.50, 0.62, 0.80, 1.0]
const MEMORY := [0.3, 0.4, 0.55, 0.7, 0.85, 1.0, 1.15, 1.6, 2.2]
const SLOW := [2.6, 2.1, 1.7, 1.4, 1.2, 1.1, 1.0, 0.75, 0.6]
## How readily a wizard goes looking for a fight and stays close in it, 0 to 1 (owner, 2026-11-20: the wizards were passive enough that a person only had to keep attacking, and never needed to defend or run).
const AGGRESSION := [0.0, 0.0, 0.05, 0.15, 0.25, 0.35, 0.5, 0.75, 1.0]
const CLUMSY := [4.0, 3.2, 2.5, 1.9, 1.5, 1.2, 1.0, 0.7, 0.5]


## The level of the wizards in the match about to begin, set by the waiting room's wall (or, in a network match, from the players' ratings). 0 until something sets it.
static var match_level := 0


## The level the wizards of a match play at: the one set in the waiting room, or the usual one.
static func current() -> int:
	return match_level if match_level > 0 else DEFAULT


static func skill_of(level: int) -> float:
	return SKILL[clampi(level, 1, LEVELS) - 1]


static func memory_of(level: int) -> float:
	return MEMORY[clampi(level, 1, LEVELS) - 1]


static func slow_of(level: int) -> float:
	return SLOW[clampi(level, 1, LEVELS) - 1]


static func aggression_of(level: int) -> float:
	return AGGRESSION[clampi(level, 1, LEVELS) - 1]


static func clumsy_of(level: int) -> float:
	return CLUMSY[clampi(level, 1, LEVELS) - 1]

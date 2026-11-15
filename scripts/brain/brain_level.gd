class_name BrainLevel
extends RefCounted

## The nine levels of the AI wizards, from 1 (slowest and most forgetful) to 9 (a very good person at the limit of what a person can do: never past it).
## A level is a row of knobs. `skill` drives how quick the reactions are, how true the aim and the hand are, how soon it draws and how much it thinks of
## (see WizardBrain.skill); `memory` scales how long it keeps a rival's place and a rival's spells in mind (BrainSight.REMEMBER, BrainProfile.FORGET).
## Level 6 is the wizard the game has had until now (skill 0.65, memory as it was).

const LEVELS := 9
const DEFAULT := 6
const SKILL := [0.05, 0.17, 0.29, 0.41, 0.53, 0.65, 0.78, 0.90, 1.0]
const MEMORY := [0.3, 0.4, 0.55, 0.7, 0.85, 1.0, 1.15, 1.3, 1.5]


static func skill_of(level: int) -> float:
	return SKILL[clampi(level, 1, LEVELS) - 1]


static func memory_of(level: int) -> float:
	return MEMORY[clampi(level, 1, LEVELS) - 1]

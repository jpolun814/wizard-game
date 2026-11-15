class_name BrainLevel
extends RefCounted

## The nine levels of the AI wizards, from 1 (slowest and most forgetful) to 9 (a very good person at the limit of what a person can do: never past it).
## A level is a row of knobs. `skill` drives how quick the reactions are, how true the aim and the hand are, how soon it draws and how much it thinks of
## (see WizardBrain.skill); `memory` scales how long it keeps a rival's place and a rival's spells in mind (BrainSight.REMEMBER, BrainProfile.FORGET).
## `slow` and `clumsy` only ever make the low levels worse than the usual wizard (a slower start to a reaction, wider aim and a shakier hand: nothing is botched on purpose).
## Level 7 is about the wizard the game has had until now (skill 0.65; the first ladder showed that above skill 0.5 a level's skill barely changes who wins,
## so the levels below are spread over the part of the scale where it does).

const LEVELS := 9
const DEFAULT := 7
const SKILL := [0.05, 0.14, 0.23, 0.32, 0.41, 0.50, 0.62, 0.80, 1.0]
const MEMORY := [0.3, 0.4, 0.55, 0.7, 0.85, 1.0, 1.15, 1.3, 1.5]
const SLOW := [2.6, 2.1, 1.7, 1.4, 1.2, 1.1, 1.0, 1.0, 1.0]
const CLUMSY := [4.0, 3.2, 2.5, 1.9, 1.5, 1.2, 1.0, 1.0, 1.0]


static func skill_of(level: int) -> float:
	return SKILL[clampi(level, 1, LEVELS) - 1]


static func memory_of(level: int) -> float:
	return MEMORY[clampi(level, 1, LEVELS) - 1]


static func slow_of(level: int) -> float:
	return SLOW[clampi(level, 1, LEVELS) - 1]


static func clumsy_of(level: int) -> float:
	return CLUMSY[clampi(level, 1, LEVELS) - 1]

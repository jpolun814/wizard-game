class_name Mending
extends RefCounted

## How a wizard heals, other than by a Glowcap: the quick chants, the heals that go on over time, sleep, the wound that is bought back, the stitch that pays
## for each blow struck, the gamble, and the second chance. Reached as `wizard.mending`. Healing is always maximum stamina (`Wizard.heal`), never more than the
## wizard started with.
##
## The laws of it, written here once and meant for every source (owner, 2026-11-22):
##  - only one heal over time is on a wizard at a time: a new one takes the place of the old (`begin`);
##  - every heal over time draws on one allowance of `CAP` maximum stamina a second, whatever its source, so two together never mend faster than that (`pour`);
##    sleep is the one exception, since a sleeper can do nothing else (`SLEEP_RATE`);
##  - a hit ends a Breathe and wakes a sleeper; moving or casting ends a Rest; nothing ends a Mud Mask.

const CAP := 6.0                  # the most maximum stamina a second that heals over time can give together
const SLEEP_RATE := 12.0          # what a sleeper mends a second: the heal that has the whole of a wizard's attention
const MENDING_GIVES := 5.0        # the quick chant
const RECOVERY_WINDOW := 10.0     # seconds back that a Recovery looks for what was lost
const RECOVERY_MOST := 40.0       # and the most it gives back
const STITCH_PER_HIT := 3.0
const STITCH_SECONDS := 30.0
const GAMBLE_STAKE := 30.0        # won three times in four, lost one in four (and a loss can kill)
const GAMBLE_ODDS := 0.75
const RESTORATION_GIVES := 120.0  # the long chant, said perfectly
const SECOND_CHANCE_SHARE := 0.3  # a wizard brought back has this share of the most it could have
const SECOND_CHANCE_GRACE := 1.5  # seconds no blow lands after it
const STILL_GRACE := 0.4          # seconds a Rest gives the body to come to rest before moving ends it
const SAFE_EVERY := 0.4           # how often a safe place to stand is noted down, for a second chance
const TINT := Color("#9be28a")

## What each heal over time gives: the rate (a second), the seconds it goes on (0: until something ends it) and what ends it.
const OVER_TIME := {
	"rest": {"rate": 3.0, "seconds": 0.0},
	"breathe": {"rate": 3.0, "seconds": 10.0},
	"mud_mask": {"rate": 2.0, "seconds": 20.0},
	"stitch": {"rate": 0.0, "seconds": STITCH_SECONDS},
	"long_rest": {"rate": 0.0, "seconds": 0.0},
}

var wizard: Wizard
var kind := ""            # the heal over time that is on the wizard, or "" when none is
var _left := 0.0
var _still := 0.0
var _casts_at_start := 0
var _room := CAP          # what is left of this second's allowance
var _poured_at := -10.0   # when something last mended the wizard over time (`_clock`)
var _carry := 0.0         # the part of a point that has been given and not yet added
var _clock := 0.0
var _losses: Array = []   # [when, how much] for each wound in the last RECOVERY_WINDOW seconds
var _safe_at := Vector2.ZERO
var _safe_known := false
var _safe_wait := 0.0


func _init(owner_wizard: Wizard) -> void:
	wizard = owner_wizard


## True when this heal over time is the one on the wizard.
func is_on(which: String) -> bool:
	return kind == which


## True while anything is mending the wizard over time: a heal of their own or a spring they stand in (for the status bubble).
func flowing() -> bool:
	return kind != "" or _clock - _poured_at < 0.3


## The seconds a heal over time has left, or -1 when it has no clock (it goes on until something ends it, or is not a heal of the wizard's own).
func left() -> float:
	if kind != "" and float(OVER_TIME[kind]["seconds"]) > 0.0:
		return _left
	return -1.0


## Once a frame, from the wizard.
func tick(delta: float) -> void:
	_clock += delta
	_room = minf(_room + CAP * delta, CAP)
	_note_safe_place(delta)
	if kind == "":
		return
	var spec: Dictionary = OVER_TIME[kind]
	match kind:
		"rest":
			_still += delta
			if _still > STILL_GRACE and _disturbed():
				end()
				return
			pour(float(spec["rate"]) * delta)
		"breathe", "mud_mask":
			_left -= delta
			pour(float(spec["rate"]) * delta)
			if _left <= 0.0:
				end()
				return
		"stitch":
			_left -= delta
			if _left <= 0.0:
				end()
				return
		"long_rest":
			if not wizard.asleep:  # woken by a blow, or by anything else that stood them up
				end()
				return
			wizard.heal(SLEEP_RATE * delta)
			if wizard.max_stamina >= Wizard.MAX_STAMINA:
				wizard.wake()
				end()
				return
	if kind in ["rest", "breathe", "mud_mask"] and wizard.max_stamina >= Wizard.MAX_STAMINA:
		end()  # nothing is left to mend


## A heal over time begins and takes the place of any other. Sleep puts the wizard down.
func begin(which: String) -> void:
	if wizard.dead or wizard.is_likeness():
		return
	if kind != "":
		end()
	kind = which
	_left = float(OVER_TIME[which]["seconds"])
	_still = 0.0
	_casts_at_start = wizard.casts_made
	if which == "long_rest":
		Substances.relieve(wizard)
		wizard.fall_asleep()
	_show(Vector2(0.0, -20.0), 6)


## The heal over time on the wizard stops.
func end() -> void:
	if kind == "long_rest" and wizard.asleep:
		wizard.wake()
	kind = ""
	_left = 0.0


## Pours some of a heal over time into the wizard, as much as this second's allowance has left (the law of `CAP`). Returns how much was taken.
func pour(amount: float) -> float:
	var take := minf(amount, _room)
	if take <= 0.0:
		return 0.0
	_room -= take
	_poured_at = _clock
	_carry += take
	var whole := floorf(_carry)
	if whole >= 1.0:
		_carry -= whole
		wizard.heal(whole)
	return take


## The wizard casts or says something: it ends a Rest, which is stillness itself.
func act() -> void:
	if kind == "rest":
		end()


## A blow lands on the wizard (after what a veil or a grace turned away): it ends a Breathe and wakes a sleeper.
func struck() -> void:
	if kind == "breathe" or kind == "long_rest":
		end()


## Maximum stamina has been taken from the wizard by a blow or by drowning: noted, for a Recovery to bring back.
func lost(amount: float) -> void:
	if amount <= 0.0:
		return
	_losses.append([_clock, amount])


## The wizard has struck something (a blow landed that was theirs): a Stitch pays for it.
func landed() -> void:
	if kind == "stitch":
		pour(STITCH_PER_HIT)
		_show(Vector2(0.0, -30.0), 3)


## What a Recovery brings back: the maximum stamina lost in the last RECOVERY_WINDOW seconds, but never more than RECOVERY_MOST.
func recent_loss() -> float:
	var total := 0.0
	for entry: Array in _losses:
		if _clock - float(entry[0]) <= RECOVERY_WINDOW:
			total += float(entry[1])
	return minf(total, RECOVERY_MOST)


# --- The chants ----------------------------------------------------------------------------------------------------------

## The ids of the chants that heal, which `say` handles.
const CHANTS := ["mending", "rest", "recovery", "stitch", "gamble", "long_rest", "second_chance", "restoration"]


## What the spellbook says a healing chant mends, where a spell's damage is written: a plus sign and the figure, a rate where it goes on over time, "up to" where
## it may give less than that. Nothing for a chant that does not heal.
static func line_of(id: String) -> String:
	match id:
		"mending":
			return "+%d max stamina" % roundi(MENDING_GIVES)
		"rest":
			return "+%d max stamina/sec" % roundi(float(OVER_TIME["rest"]["rate"]))
		"recovery":
			return "up to +%d max stamina" % roundi(RECOVERY_MOST)
		"stitch":
			return "+%d max stamina/hit" % roundi(STITCH_PER_HIT)
		"gamble":
			return "+%d max stamina or -%d max stamina" % [roundi(GAMBLE_STAKE), roundi(GAMBLE_STAKE)]
		"long_rest":
			return "+%d max stamina/sec" % roundi(SLEEP_RATE)
		"second_chance":
			return "+%d max stamina" % roundi(Wizard.MAX_STAMINA * SECOND_CHANCE_SHARE)
		"restoration":
			return "up to +%d max stamina" % roundi(RESTORATION_GIVES)
	return ""


## A healing chant is said, as well as it was said (power, 0 to 1). The ones that begin something over time take the place of any other that is on.
func say(id: String, power := 1.0) -> void:
	if wizard.dead or wizard.is_likeness():
		return
	Sfx.cue("rituals", "mend", wizard.center(), -6.0)
	match id:
		"mending":
			give_at_once(MENDING_GIVES)
		"restoration":
			give_at_once(roundf(RESTORATION_GIVES * power))
		"recovery":
			var back := recent_loss()
			_losses.clear()
			if back > 0.0:
				give_at_once(back)
			else:
				FloatText.spawn(wizard.get_parent(), wizard.center() + Vector2(0, -44), "Nothing lost", Color.GRAY, 0.9)
		"rest":
			begin("rest")
		"stitch":
			begin("stitch")
		"long_rest":
			begin("long_rest")
		"gamble":
			_gamble()
		"second_chance":
			arm()


## Mends at once: the maximum and the stamina both rise by it (a Cauterize, a Mending, a Restoration).
func give_at_once(amount: float) -> void:
	if amount <= 0.0:
		return
	var before := wizard.max_stamina
	wizard.heal(amount)
	var got := wizard.max_stamina - before
	_show(Vector2(0.0, -20.0), 10)
	FloatText.spawn(wizard.get_parent(), wizard.center() + Vector2(0, -44), "+%d" % roundi(maxf(got, 0.0)), TINT, 1.1)


## Three in four it mends 30 maximum stamina, one in four it takes 30, and that can kill.
func _gamble() -> void:
	if wizard.dice().randf() < GAMBLE_ODDS:
		give_at_once(GAMBLE_STAKE)
		return
	Fx.burst(wizard.get_parent(), wizard.center(), Color("#ff5a5a"), 14, 140.0, 0.4, true)
	wizard.take_damage(roundi(GAMBLE_STAKE), false)


# --- The second chance ---------------------------------------------------------------------------------------------------

## True while a second chance is armed on the wizard (it is kept in their book, so it goes with them from world to world).
func is_armed() -> bool:
	return wizard.ledger.armed


## Arms a second chance. One at a time: another does nothing while one is waiting.
func arm() -> bool:
	if wizard.ledger.armed:
		FloatText.spawn(wizard.get_parent(), wizard.center() + Vector2(0, -44), "Already armed", Color.GRAY, 0.9)
		return false
	wizard.ledger.armed = true
	_show(Vector2(0.0, -20.0), 14)
	return true


## Death is at the door: a wizard with a second chance armed is brought back, at a share of what they could have, to the last safe place they stood, and
## no blow lands for a moment. True when they were saved. Works against every way of dying, since every way ends in this question.
func rescue() -> bool:
	if not wizard.ledger.armed or wizard.dead or wizard.is_likeness():
		return false
	wizard.ledger.armed = false
	end()
	Substances.relieve(wizard)
	wizard.lungs.smother(false)
	wizard.lungs.air = Lungs.BREATH
	wizard.max_stamina = roundf(Wizard.MAX_STAMINA * SECOND_CHANCE_SHARE)
	wizard.stamina = wizard.max_stamina
	if _safe_known:
		wizard.global_position = _safe_at
		wizard.reset_physics_interpolation()
	wizard.velocity = Vector2.ZERO
	wizard.give_grace(SECOND_CHANCE_GRACE)
	var at := wizard.center()
	Fx.pop(wizard.get_parent(), at, "magic_02", Color("#fff2b0"), 90.0, 0.8, 1.6, 2.0)
	Fx.burst(wizard.get_parent(), at, Color("#fff2b0"), 24, 200.0, 0.6, true)
	FloatText.spawn(wizard.get_parent(), at + Vector2(0, -50), "Second chance", Color("#fff2b0"), 1.2, 1.6)
	return true


## Where the wizard last stood safely (on the ground, out of the water), noted a little at a time, for a second chance to bring them back to.
func _note_safe_place(delta: float) -> void:
	_safe_wait -= delta
	if _safe_wait > 0.0 or wizard.dead:
		return
	_safe_wait = SAFE_EVERY
	var standing := wizard.is_on_floor() or wizard.flying
	if standing and not wizard.lungs.submerged() and wizard.burning_time <= 0.0 and wizard.max_stamina > 0.0:
		_safe_at = wizard.global_position
		_safe_known = true


## True when the wizard has moved or cast since a Rest began.
func _disturbed() -> bool:
	if wizard.casting or wizard.pen.active() or wizard.casts_made != _casts_at_start or wizard.fainted:
		return true
	if wizard.flying:
		return wizard.velocity.length() > 60.0
	return absf(wizard.velocity.x) > 8.0 or not wizard.is_on_floor()


## A small show of the mending: a soft glow and a few motes rising off the wizard.
func _show(at: Vector2, motes: int) -> void:
	var parent := wizard.get_parent()
	if parent == null or not wizard.is_inside_tree():
		return
	Fx.burst(parent, wizard.center() + at, TINT, motes, 60.0, 0.6, true)

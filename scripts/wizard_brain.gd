class_name WizardBrain
extends RefCounted

## A rival wizard's mind. It plays the way a player would: it walks the world looking for pages, and when it comes near another wizard (you,
## or another of its own kind: spells have no teams) it keeps its distance, reacts to what is thrown at it, and picks spells that suit the
## moment. It casts only the spells whose pages it has found. Every spell it casts is drawn in front of it as a real gesture and read by the
## same recognizer as yours, so you can watch it form, learn the shapes from it, and break the spell by hitting the wizard before it finishes.
##
## Four layers, checked in order each frame:
##   Travel: with no wizard in reach it walks to the nearest page it has not read, and when there are none, to the nearest wizard.
##   Reactions: a shot coming at it, standing in something dangerous, or you right on top of it. After a short
##     reaction time (shorter the more skilled it is) it jumps, reflects the shot with a Gust, raises a
##     Barrier, steps away, or pushes you off.
##   Footwork: it holds a dueling range, strafes, jumps to get a clear line at you, and won't walk into fire.
##   Attacks: each spell is scored for the situation (are you moving, behind cover, rooted, close, far?) and one is
##     picked by weight. Projectiles are aimed where you are going, not where you are.

const WALK_SPEED := 170.0
const ENGAGE := 620.0         # a wizard this close, and in sight, is a fight; farther off, it is a journey
const PAGE_REACH := 4          # tiles: a page further than this from any place to stand is not one it can get
const GOAL_EVERY := 4.0       # seconds between looking for a nearer page
const GIVE_UP := 45.0         # seconds a page it could not reach stays off its list
const NEAR := 190.0           # closer than this it backs away
const FAR := 330.0            # farther than this it closes in
const TOO_CLOSE := 95.0       # this close it acts to get you off it
const INTERRUPT_DAMAGE := 6   # a hit this big while it draws breaks the spell
const QUICK_DRAW := 0.35      # defensive signs are drawn quickly
const ATTACK_DRAW := 0.8      # attacks take longer, which is your chance to interrupt them
const ATTACK_RANGE := 460.0   # it only casts at you from about a screen away, never across the map
const SHOT_SPEED := 650.0     # roughly how fast its bolts fly, for leading a moving target
const CLEARS := {  # the gates a wizard clears, and the spells that do it, best first: any fire burns growth and gas and melts ice, wind thins gas, stone breaks ice and walls
	"brambles": ["Ignite", "Fire Breath", "Firewall", "Volcano"],
	"gas": ["Ignite", "Fire Breath", "Firewall", "Gust", "Tornado", "Volcano"],
	"ice": ["Fire Breath", "Firewall", "Ignite", "Stonefall", "Earthquake", "Volcano"],
	"wall": ["Stonefall", "Earthquake"],
	"piranhas": ["Spark"],
}
const WAYS := {  # the spells (and chants) that get a wizard past each crossing that no one clears, the one it likes best first
	"chasm": ["Shadow Step", "Obsidian Armor"],  # (a Gust shoves a wizard too little to carry it over; the glass wades through the lava, and needs a way up the far side)
	"flood": ["Frost Bridge", "Lily Pads", "Shadow Step"],
	"piranhas": ["Frost Bridge", "Lily Pads", "Shadow Step"],
	"sentinel": ["Smoke Screen", "Eclipse", "Barrier", "Decoy"],
	"wall": ["Geyser", "Push", "Liana"],
	"gas": ["chant:deep_breath"],  # walked through with the breath held (a chant, not a spell)  # thrown up over the top of it
}
const LASTS := {"Frost Bridge": 25.0, "Lily Pads": 6.0, "Smoke Screen": 11.0, "Eclipse": 9.0, "Barrier": 5.0, "Decoy": 3.0}  # seconds that the way a spell makes lasts
const COVERS := ["Smoke Screen", "Eclipse", "Barrier", "Decoy"]  # the spells that keep a sentinel from hitting it, best first
const REST_BELOW := 20.0      # stamina: below this a wizard that is only travelling stops to get its breath back,
const REST_UNTIL := 90.0      # and walks on again when it has this much (a jump and a spell both cost stamina, and it comes back only while standing)
const SETTLE := 1.0           # seconds from drawing a way over water to its being there to walk on
const PADS_REACH := 480.0     # pixels of pit that one row of Lily Pads covers, no further apart than a wizard can step
const LEAP_STEPS := 2         # Shadow Steps at least that it makes in the air to get over a pit: a jump and two of them carry it 900 px
const LEAP_AIR_MAX := 4.0     # seconds in the air after which a leap is given up
const LEAP_DRAW := 0.15       # seconds to draw one: it falls the while
const SENTINEL_LOOKOUT := 40  # tiles of the way it looks ahead along for a sentinel
const COVER_RANGE := 780.0    # it draws its cover when it is this close to a sentinel, a little before the sentinel sees it (700)
const CLEAR_TRIES := 14       # casts at one gate before it gives up on it for a while
const STRIKE_REACH := {"Fire Breath": 5, "Ignite": 12, "Stonefall": 10, "Earthquake": 10, "Firewall": 8, "Volcano": 8, "Gust": 7, "Tornado": 6, "Spark": 40}  # tiles: how far off a spell strikes a gate
const LIFT_WAIT := 1.6         # seconds it stands on a Geyser it has drawn, waiting to be thrown, before it takes it for a miss
const SHOVE_WAIT := 1.0         # seconds it waits to be off the ground after shoving itself up, before it takes it for a miss
const VINE_SCALE := 2.4          # how much bigger than its picture it draws a vine, to grow it taller than a wall
const VINE_OVER := 70.0          # pixels over the top of the wall that it climbs before it lets go, to clear the edge when it drops
const VINE_WAIT := 8.0          # seconds it climbs before it takes the vine for a miss
const WADE_WAIT := 40.0          # seconds it spends in a pit before it takes the crossing for a miss
const BREATH_AHEAD := 60.0        # pixels short of a bank of gas that it stops to hold its breath
const GAS_WALK := 20.0            # seconds the way through gas is taken to be open after the chant (the breath is held for longer)
const LIFT_CLEARANCE := 40.0    # pixels it must be thrown above the top of a wall to get over it
const STRIKE_STAND := 4       # tiles: and it steps up to this far from it

var wizard: Wizard            # the body it plays
var skill := 0.6              # 0 to 1: how quick its reactions are and how true its aim is
var _cast_cooldown := 1.8
var _react := 0.0             # counting down to a planned reaction
var _reaction := ""
var _threat_dir := Vector2.ZERO
var _defend_cooldown := 0.0
var _strafe := 0.0
var _strafe_timer := 0.0
var _escape_time := 0.0
var _escape_dir := 0.0
var _jump_cooldown := 0.0
var _hop_timer := 1.5  # counting down to its next hop while it walks
var _pressure := 0.0          # how many shots you have thrown at it lately
var _seen_shots := {}
var _recent: Array[String] = []  # its last two attacks, which it avoids repeating
var _rng := RandomNumberGenerator.new()
var _foe: Wizard                 # the wizard it is dealing with: the nearest of the others
var _route := WizardRoute.new()
var _goal := ""                  # what it is travelling to: "page", "foe", or "" for nothing
var _goal_page: PagePickup
var _goal_timer := 0.0
var _skip := {}                  # a page (its instance id) or a gate (its name) -> seconds it stays off the list, for one that could not be had
var stuck_at: Array[String] = []  # where it has been held up, for a report
var _goal_gate := {}              # the gate it is going to clear: {"kind", "outside", "target", "entry"}
var _gate_tries := 0
var _gate_gone := 0              # how many pieces of the gate had gone when it last struck it
var _nav_version := -1           # which build of the ways its list of pages it cannot reach belongs to
var _bridged := {}               # crossing (by key) -> seconds more that the way over it, which this wizard made, will last
var _cross_run := 0.0            # the speed it goes at while it makes its way over a crossing
var _pad_walk := {}              # crossing (by key) -> {"dir", "end"}: the row of pads laid over it, and the x it walks along them to
var _settle := 0.0               # seconds it stands still while a way over water grows
var _resting := false            # it has stopped to get its breath back
var _pads := {}                  # crossing (by key) -> {"dir", "front"}: the row of Lily Pads it has made so far over a long pit
var _wade := {}                  # a walk through the lava of a pit in black glass: {"dir", "key", "span": the pit, "stage", "waited"}
var _lift := {}                  # a throw up over a wall: {"dir", "key", "span": the wall, "drawn", "thrown", "waited"}
var _leap := {}                  # a jump over a chasm: {"dir": -1 or 1, "key", "steps": Shadow Steps left to make, "span": the chasm, "jumped", "air": seconds since it left the ground}
var _cannot := {}                # crossing (by key) -> seconds more that it will not try it, having fallen in
var _replans := 0                # times in a row it has had to find its way again


func _init(body: Wizard) -> void:
	wizard = body
	_rng.randomize()
	skill = 0.65


## Called when the wizard takes damage. A real hit while it draws breaks its spell, and being badly hurt makes it
## want to get away.
func on_hurt(amount: int) -> void:
	if wizard.is_drawing() and amount >= INTERRUPT_DAMAGE:
		wizard.interrupt_cast()
		_cast_cooldown = maxf(_cast_cooldown, 0.9)
	if _knows("Shadow Step") and wizard.max_stamina < Wizard.MAX_STAMINA * 0.4 and _defend_cooldown <= 0.0 and _react <= 0.0 and _rng.randf() < 0.5:
		_plan("blink_away", 0.25)


func think(delta: float) -> void:
	_cast_cooldown -= delta
	_defend_cooldown -= delta
	_jump_cooldown -= delta
	_escape_time -= delta
	_goal_timer -= delta
	_settle -= delta
	_pressure *= exp(-delta / 3.0)
	for id in _skip.keys():
		_skip[id] -= delta
		if _skip[id] <= 0.0:
			_skip.erase(id)
	for key in _cannot.keys():
		_cannot[key] -= delta
		if _cannot[key] <= 0.0:
			_cannot.erase(key)
	for key in _bridged.keys():
		_bridged[key] -= delta
		if _bridged[key] <= 0.0:
			_bridged.erase(key)
			_pad_walk.erase(key)
	if wizard.nav != null and wizard.nav.version != _nav_version:
		_nav_version = wizard.nav.version
		_skip.clear()  # a gate has been cleared: pages that could not be reached may be reachable now
	_track_shots()
	_foe = _nearest_foe()
	if _foe == null:  # the last wizard standing
		wizard.walk(0.0)
		return
	var foe: Wizard = _foe
	var to_player: Vector2 = foe.center() - wizard.center()
	var sees := _clear_line(wizard.center(), foe.center()) and not SpellTargets.sight_blocked(wizard.get_tree(), wizard.center(), foe.center())
	var fighting := sees and to_player.length() < ENGAGE

	# Reactions.
	if _react > 0.0:
		_react -= delta
		if _react <= 0.0:
			_act(_reaction)
	elif not wizard.is_drawing():
		var shot := _incoming_shot()
		if not shot.is_empty() and _defend_cooldown <= 0.0:
			_threat_dir = shot["dir"]
			_plan(_choose_defence(shot["eta"]), _reaction_time())
		elif _in_danger(wizard.global_position + Vector2(0, -6)) or _in_danger(wizard.center()):
			_plan("escape", _reaction_time() * 0.6)
		elif _defend_cooldown <= 0.0 and not _watchers().is_empty():
			_plan("cover", _reaction_time())
		elif fighting and to_player.length() < TOO_CLOSE and _defend_cooldown <= 0.0:
			_plan(_choose_repel(), _reaction_time())

	# Footwork, or the journey.
	var run := _footwork(delta, to_player, sees) if fighting else _travel(delta)  # (both may jump: the speed is written after they have)
	wizard.walk(run)
	wizard.facing = signf(to_player.x) if fighting or wizard.is_drawing() else (signf(run) if run != 0.0 else wizard.facing)
	if not fighting:
		return

	# Attacks.
	if _cast_cooldown <= 0.0 and not wizard.is_drawing() and _react <= 0.0:
		if foe.has_shield():
			_cast_cooldown = 0.3  # nothing gets through a Barrier; wait it out
		elif _attack(to_player, sees):
			_cast_cooldown = lerpf(2.8, 1.5, skill) + _rng.randf() * 0.8
		else:
			_cast_cooldown = 0.4


func _reaction_time() -> float:
	return lerpf(0.4, 0.15, skill) + _rng.randf() * 0.12


func _plan(reaction: String, delay: float) -> void:
	_reaction = reaction
	_react = delay


# --- Travel -----------------------------------------------------------------------------------------------------


## Whether it holds the page of a spell.
func _knows(spell_name: String) -> bool:
	if spell_name.begins_with("chant:"):
		return wizard.ledger.knows_chant(spell_name.substr(6))
	return wizard.ledger.knows_spell(spell_name)


## The nearest of the other wizards still standing, or null when it is the last.
func _nearest_foe() -> Wizard:
	var best: Wizard = null
	var best_gap := INF
	for other: Wizard in SpellTargets.wizards(wizard.get_tree()):
		if other == wizard:
			continue
		var gap: float = wizard.center().distance_to(other.center())
		if gap < best_gap:
			best = other
			best_gap = gap
	return best


## Whether a wizard cannot move freely: rooted, or slowed.
func _held(foe: Wizard) -> bool:
	return foe.is_rooted() or foe.is_slowed()


## The tile a body stands in, from its feet.
func _tile_of(feet: Vector2) -> Vector2i:
	return Vector2i(floori(feet.x / WizardRoute.TILE), floori((feet.y - 1.0) / WizardRoute.TILE))


## Walks the way to what it is after, and reads a page when it stands under one. Returns the speed to walk at.
func _travel(delta: float) -> float:
	if not _leap.is_empty():
		return _leaping(delta)
	if not _wade.is_empty():
		return _wading(delta)
	if not _lift.is_empty():
		return _lifting(delta)
	if _settle > 0.0:
		return 0.0
	if wizard.is_drawing():
		return 0.0
	if _escape_time > 0.0:
		return _escape_dir * WALK_SPEED * 1.3
	if _walking_pads():
		return _cross_run
	if _resting and wizard.stamina >= REST_UNTIL:
		_resting = false
	elif not _resting and wizard.stamina < REST_BELOW and wizard.is_on_floor():
		_resting = true
	if _resting:
		return 0.0
	if wizard.nav == null:
		return 0.0
	_read_page_underfoot()
	if _goal == "page" and _route.done() and not _goal_lost():  # it has come to the place, and the page is not to be had from there
		_skip[_goal_page.get_instance_id()] = GIVE_UP
		_goal = ""
		_goal_timer = 0.0
	if _goal == "gate":
		if _goal_gate["entry"].get("open", false):
			_goal = ""
			_goal_timer = 0.0
		elif _route.done():
			_work_gate()
			return 0.0
	if (_goal == "" and _goal_timer <= 0.0) or _goal_lost() or (_goal == "foe" and (_goal_timer <= 0.0 or _route.done())):
		_choose_goal()
	if _goal != "" and not _route.done() and wizard.is_on_floor():  # (a wizard in the air cannot stop for it; after the goal is chosen, so that a gate on the way is seen before the first step towards it)
		var crossing := _crossing_ahead()
		_cross_run = 0.0
		if not crossing.is_empty() and _cross(crossing):
			return _cross_run
	var steer := _route.steer(wizard, delta)
	if steer["replan"]:
		stuck_at.append("%s %s" % [str(_tile_of(wizard.global_position)), _route.status()])
		_stuck_on_goal()
	if steer["jump"] and wizard.is_on_floor():
		wizard.request_jump()
	return steer["dir"] * steer["speed"]


## The crossing the way goes over soon, if the way over it is not made: {"kind", "key", "span", "post"}. A pit counts when it is the next few tiles
## off, a sentinel from much farther, for it sees a long way.
func _crossing_ahead() -> Dictionary:
	var world := wizard.get_tree().get_first_node_in_group(&"world")
	for moves in SENTINEL_LOOKOUT:
		var key := _toll_between(_route.ahead(moves - 1) if moves > 0 else wizard.nav.nearest(_tile_of(wizard.global_position), true), _route.ahead(moves))
		if key == "" or _bridged.has(key):
			continue
		for crossing: Dictionary in world.crossings():
			if crossing["key"] == key and (moves < 4 or crossing["kind"] == "sentinel"):
				return crossing
	return {}


## While it is on a row of pads it has laid over water, it walks along them to the end of the row rather than hopping from one to the next (a hop
## that lands a little short drops it in). True when it is walking them (or standing at the end of the row), with the speed in `_cross_run`.
func _walking_pads() -> bool:
	if _pad_walk.is_empty() or not wizard.is_on_floor():
		return false
	var world := wizard.get_tree().get_first_node_in_group(&"world")
	for crossing: Dictionary in world.crossings():
		if not _pad_walk.has(crossing["key"]):
			continue
		var span: Rect2 = crossing["span"]
		var dir: int = _pad_walk[crossing["key"]]["dir"]
		var end: float = _pad_walk[crossing["key"]]["end"]
		var x := wizard.global_position.x
		if x < span.position.x - WizardRoute.TILE or x > span.end.x + WizardRoute.TILE or (end - x) * dir < -WizardRoute.TILE:
			continue  # not on this row
		_cross_run = dir * WALK_SPEED if (end - x) * dir > 8.0 else 0.0
		return true
	return false


## The crossing whose toll lies on a move from one tile to the next, or "": a long jump over a pit passes over tiles that the path never names.
func _toll_between(from: Vector2i, to: Vector2i) -> String:
	if to.x < 0:
		return ""
	for step in range(1, absi(to.x - from.x) + 1):
		var key: String = wizard.nav.toll_at(Vector2i(from.x + step * signi(to.x - from.x), to.y if step == absi(to.x - from.x) else from.y))
		if key != "":
			return key
	return wizard.nav.toll_at(to)


## Makes the way over a crossing, a stroke at a time. True while it is at it and must stand; false when it may walk on (a sentinel too
## far off to see it yet, or nothing it can do).
func _cross(crossing: Dictionary) -> bool:
	if wizard.is_drawing() or _react > 0.0:
		return true
	var kind: String = crossing["kind"]
	if kind == "sentinel":
		if wizard.center().distance_to(crossing["post"].center()) > COVER_RANGE:
			return false
		var used := _cover(crossing["post"])
		if used == "":
			return false
		_bridged[crossing["key"]] = LASTS[used]
		return true
	var spell_name := _way(kind)
	if spell_name == "":
		return false
	var span: Rect2 = crossing["span"]
	var dir := 1 if span.get_center().x > wizard.global_position.x else -1
	if _pads.has(crossing["key"]):
		dir = _pads[crossing["key"]]["dir"]  # a row of pads is laid along the way it set out
	_cross_run = 0.0
	match spell_name:
		"Geyser", "Push", "Liana":  # it walks up to the face of the wall and stands there while the ground bubbles under it, while it shoves itself up, or while it climbs a vine
			var face := span.position.x - 36.0 if dir > 0 else span.end.x + 36.0
			if absf(face - wizard.global_position.x) > 12.0:
				_cross_run = clampf(face - wizard.global_position.x, -WALK_SPEED, WALK_SPEED)
			elif wizard.is_on_floor() and wizard.stamina >= SpellData.SPELLS[spell_name].cost and not _begin_lift(spell_name, crossing["key"], dir, span):
				return false
		"Obsidian Armor":  # it puts on black glass at the edge, wades through the lava, and gets up the far side by a lift
			var edge := span.position.x if dir > 0 else span.end.x
			if (edge - wizard.global_position.x) * dir > 20.0:
				_cross_run = dir * WALK_SPEED
			elif wizard.is_on_floor() and wizard.stamina >= SpellData.SPELLS[spell_name].cost + SpellData.SPELLS[_way_up()].cost:
				_begin_cast(spell_name, _offset(GestureTemplates.preview_points("circle"), wizard.center(), 0.8), QUICK_DRAW)
				_wade = {"dir": dir, "key": crossing["key"], "span": span, "stage": 0, "waited": 0.0}
		"chant:deep_breath":  # it walks to the edge of the gas, holds its breath, and walks through
			var edge := span.position.x if dir > 0 else span.end.x
			if (edge - wizard.global_position.x) * dir > BREATH_AHEAD:
				_cross_run = dir * WALK_SPEED
			elif wizard.holding_breath() or wizard.chant(spell_name.substr(6)):
				_bridged[crossing["key"]] = minf(wizard.deep_breath_time, GAS_WALK) if wizard.holding_breath() else GAS_WALK
				_settle = SETTLE
			else:
				_cannot[crossing["key"]] = GIVE_UP
				return false
		"Shadow Step":  # it walks to the edge, waits there until it is on the ground with strength to spare, and leaps
			var edge := span.position.x if dir > 0 else span.end.x
			if (edge - wizard.global_position.x) * dir > 20.0:
				_cross_run = dir * WALK_SPEED
			elif wizard.is_on_floor() and wizard.stamina >= 2.0 * SpellData.SPELLS[spell_name].cost:
				var steps := clampi(ceili((span.size.x - 200.0) / 300.0), LEAP_STEPS, 5)
				_leap = {"dir": dir, "key": crossing["key"], "steps": steps, "span": span, "jumped": false, "air": 0.0}
		"Lily Pads":  # a row at a time, as far as it reaches, and the next when it has come to the end of that
			if wizard.stamina >= SpellData.SPELLS[spell_name].cost:
				var reach := span.grow_individual(WizardRoute.TILE, 0.0, WizardRoute.TILE, 0.0)  # pads run a tile onto the bank at each end
				var near := reach.position.x if dir > 0 else reach.end.x
				var front: float = _pads[crossing["key"]]["front"] if _pads.has(crossing["key"]) else near
				var from_x := maxf(front, wizard.global_position.x) if dir > 0 else minf(front, wizard.global_position.x)
				var to_x := clampf(from_x + dir * PADS_REACH, reach.position.x, reach.end.x)
				var row := Rect2(minf(from_x, to_x), span.position.y, absf(to_x - from_x), span.size.y)
				_begin_cast(spell_name, _bridge_stroke(spell_name, row), ATTACK_DRAW)
				_settle = SETTLE
				var over := (to_x - (reach.end.x if dir > 0 else reach.position.x)) * dir >= 0.0
				_pads[crossing["key"]] = {"dir": dir, "front": to_x}
				_pad_walk[crossing["key"]] = {"dir": dir, "end": to_x}
				_bridged[crossing["key"]] = LASTS[spell_name] if over else SETTLE + absf(to_x - from_x) / WALK_SPEED - 0.8  # the next row goes down when it is near the end of this one
				if over:
					_pads.erase(crossing["key"])
		_:  # a bridge across the whole of it
			if wizard.stamina >= SpellData.SPELLS[spell_name].cost:
				_begin_cast(spell_name, _bridge_stroke(spell_name, span), ATTACK_DRAW)
				_settle = SETTLE
				_bridged[crossing["key"]] = LASTS[spell_name]
	return true


## Starts a lift up a wall from where it stands (see _lifting). False, and the wall is given up for a while, when rock overhead would stop it short.
func _begin_lift(spell_name: String, key: String, dir: int, span: Rect2) -> bool:
	var needed := wizard.global_position.y - (span.position.y - LIFT_CLEARANCE)
	if wizard.test_move(wizard.global_transform, Vector2(0.0, -needed)):  # rock overhead stops the water short of the top
		_cannot[key] = GIVE_UP
		return false
	_lift = {"spell": spell_name, "dir": dir, "key": key, "span": span, "drawn": false, "thrown": false, "waited": 0.0}
	return true


## A walk through the lava of a pit in black glass: it waits for the glass, wades to the foot of the far side, and is lifted out of the pit
## as it would be over a wall. Returns the speed to go at.
func _wading(delta: float) -> float:
	var span: Rect2 = _wade["span"]
	var dir: int = _wade["dir"]
	_wade["waited"] += delta
	if wizard.is_drawing():
		return 0.0
	if _wade["waited"] > WADE_WAIT or (_wade["stage"] == 0 and _wade["waited"] > 3.0 and wizard.obsidian_time <= 0.0):
		_cannot[_wade["key"]] = GIVE_UP
		_wade = {}
		return 0.0
	if _wade["stage"] == 0:
		if wizard.obsidian_time > 0.0:
			_wade["stage"] = 1
		return 0.0
	var foot := (span.end.x if dir > 0 else span.position.x) - dir * 36.0
	if (foot - wizard.global_position.x) * dir > 12.0 or not wizard.is_on_floor():
		return clampf((foot - wizard.global_position.x) * 4.0, -WALK_SPEED, WALK_SPEED)
	var floor_y := span.position.y - WizardRoute.TILE * 2.0  # the pit's lava lies two rows under the floor it was dug into
	var side := Rect2(Vector2(span.end.x if dir > 0 else span.position.x - 96.0, floor_y), Vector2(96.0, span.end.y - floor_y))
	var key: String = _wade["key"]
	_wade = {}
	_begin_lift(_way_up(), key, dir, side)
	return 0.0


## A jump over a pit: it leaps from the edge, and in the air carries itself on with Shadow Steps until it is across. Returns the speed to go at.
func _leaping(delta: float) -> float:
	var span: Rect2 = _leap["span"]
	var dir: int = _leap["dir"]
	if wizard.is_on_floor():
		if _leap["jumped"]:  # down again: over, or in the pit
			var across: bool = (wizard.global_position.x - span.get_center().x) * dir > span.size.x * 0.5
			if not across:
				_cannot[_leap["key"]] = GIVE_UP
			_bridged[_leap["key"]] = 2.0
			_leap = {}
			_goal = ""
			_goal_timer = 0.0
			return 0.0
		_leap["jumped"] = true
		wizard.request_jump()
		return dir * WizardRoute.MAX_AIR_SPEED
	_leap["air"] += delta
	if _leap["air"] > LEAP_AIR_MAX:  # held against a rock face: it lets go of the jump and falls
		_cannot[_leap["key"]] = GIVE_UP
		_leap = {}
		return 0.0
	var beyond: bool = (wizard.global_position.x - span.get_center().x) * dir > span.size.x * 0.5 - 40.0
	if _leap["steps"] > 0 and not wizard.is_drawing() and not beyond and (wizard.velocity.y > -40.0 or _leap["steps"] < LEAP_STEPS):
		_leap["steps"] -= 1
		var start: Vector2 = wizard.center()
		_begin_cast("Shadow Step", _line(start, start + Vector2(dir * SpellData.STEP_MAX, -10.0).normalized() * SpellData.STEP_MAX), LEAP_DRAW)
	return dir * WizardRoute.MAX_AIR_SPEED


## A throw over a wall: it draws a Geyser under its feet and stands while the ground bubbles, and once the water has thrown it up it goes
## on across, over the top. Returns the speed to go at.
func _lifting(delta: float) -> float:
	pass
	var span: Rect2 = _lift["span"]
	var dir: int = _lift["dir"]
	if not _lift["drawn"]:
		if wizard.is_drawing():
			return 0.0
		_lift["drawn"] = true
		var feet: Vector2 = wizard.center()
		if _lift["spell"] == "Push":
			_begin_cast("Push", _push_stroke(feet, Vector2(dir * 0.2, -1.0).normalized()), QUICK_DRAW)
		elif _lift["spell"] == "Liana":  # a vine from the ground at its feet, taller than the wall
			_begin_cast("Liana", _offset(GestureTemplates.preview_points("vine"), Vector2(feet.x, wizard.global_position.y - 75.0 * VINE_SCALE), VINE_SCALE), QUICK_DRAW)
		else:
			_begin_cast("Geyser", _offset(GestureTemplates.preview_points("geyser"), feet, 0.6), QUICK_DRAW)
		return 0.0
	if _lift["spell"] == "Liana" and not _lift["thrown"]:  # it takes hold of the vine and climbs until its feet are over the top
		_lift["waited"] += delta
		if wizard.global_position.y < span.position.y - VINE_OVER:
			_lift["thrown"] = true
			wizard.climb_up = false
		elif _lift["waited"] > VINE_WAIT:
			wizard.climb_up = false
			_cannot[_lift["key"]] = GIVE_UP
			_lift = {}
			return 0.0
		else:
			wizard.climb_up = true
			return 0.0
	if wizard.is_on_floor():
		if not _lift["thrown"] and _lift["waited"] < (LIFT_WAIT if _lift["spell"] == "Geyser" else SHOVE_WAIT):  # the ground bubbles for a moment before the burst
			_lift["waited"] += delta
			return 0.0
		var across: bool = (wizard.global_position.x - span.get_center().x) * dir > span.size.x * 0.5 or wizard.global_position.y < span.position.y + 4.0  # (or on top of the wall)
		if not across:  # down again on the near side: the water did not throw it high enough
			_cannot[_lift["key"]] = GIVE_UP
		_bridged[_lift["key"]] = 2.0
		_lift = {}
		_goal = ""
		_goal_timer = 0.0
		return 0.0
	_lift["thrown"] = true
	pass
	var clear: bool = wizard.global_position.y < span.position.y - 10.0
	return dir * WizardRoute.MAX_AIR_SPEED if clear else 0.0


## The stroke that makes a way over a pit of water, along the width of it at its surface: a wave for Frost Bridge, a row of loops for Lily Pads.
func _bridge_stroke(spell_name: String, span: Rect2) -> PackedVector2Array:
	var level := span.position.y
	var out := PackedVector2Array()
	if spell_name == "Frost Bridge":
		var steps := 80
		for i in steps + 1:
			var x := span.size.x * i / steps
			out.append(Vector2(span.position.x + x, level + 14.0 * sin(x / 22.0)))
	else:
		var loops := maxi(roundi(span.size.x / 31.0), 2)  # small loops, two to a pad, so that the pad's height is the line's own
		var steps := loops * 16
		for i in steps + 1:
			var angle := TAU * loops * i / steps
			out.append(Vector2(span.position.x + span.size.x * i / steps - 10.0 * sin(angle), level - 8.0 - 10.0 * cos(angle)))
	return _densify(out)


## Draws what keeps a sentinel from hitting it: smoke over the statue, or a Barrier, or a Decoy. The name of the spell, or "" when it can do none.
func _cover(post: Node2D) -> String:
	for spell_name: String in COVERS:
		if not _knows(spell_name) or wizard.stamina < SpellData.SPELLS[spell_name].cost:
			continue
		var around: Vector2 = wizard.center()
		match spell_name:
			"Smoke Screen":
				var base: Vector2 = post.center()
				_begin_cast(spell_name, _offset(GestureTemplates.preview_points("smoke"), base + Vector2(0, -30.0), 0.9), QUICK_DRAW)
			"Eclipse":
				_begin_cast(spell_name, _offset(GestureTemplates.preview_points("crescent"), post.center() + Vector2(0, -20.0), 1.0), QUICK_DRAW)
			"Barrier":
				_begin_cast(spell_name, _offset(GestureTemplates.preview_points("circle"), around, 0.8), QUICK_DRAW)
			"Decoy":
				_begin_cast(spell_name, _offset(GestureTemplates.preview_points("eight"), around + Vector2(-40.0 * signf(post.center().x - around.x), 0.0), 0.7), QUICK_DRAW)
		return spell_name
	return ""


## Reads the page it stands under, if it does not have it.
func _read_page_underfoot() -> void:
	for pickup: PagePickup in wizard.get_tree().get_nodes_in_group("pages"):
		if not wizard.ledger.knows(pickup.page) and pickup.is_under(wizard):
			pickup.take(wizard.ledger)
			_replans = 0
			_goal = ""
			_goal_timer = 0.0
			return


## The page it was going to has gone: someone else read it, or it has it already.
func _goal_lost() -> bool:
	return _goal == "page" and (not is_instance_valid(_goal_page) or wizard.ledger.knows(_goal_page.page))


## Picks what to go for: the page nearest by the way it must walk, and when there is none to be had, the nearest wizard.
func _choose_goal() -> void:
	_goal_timer = GOAL_EVERY
	_goal = ""
	var start: Vector2i = wizard.nav.nearest(_tile_of(wizard.global_position), true)
	if start.x < 0:
		return
	var best_page: PagePickup = null
	var best_path: Array[Vector2i] = []
	for pickup: PagePickup in wizard.get_tree().get_nodes_in_group("pages"):
		if wizard.ledger.knows(pickup.page) or _skip.has(pickup.get_instance_id()):
			continue
		var tile := _tile_of(pickup.global_position)
		var stand: Vector2i = wizard.nav.nearest(tile)
		var path: Array[Vector2i] = []
		if absi(stand.x - tile.x) + absi(stand.y - tile.y) <= PAGE_REACH:
			path = _path(start, stand)
		if path.is_empty():
			_skip[pickup.get_instance_id()] = GIVE_UP  # no way there that a wizard can walk
			continue
		if best_page == null or path.size() < best_path.size():
			best_page = pickup
			best_path = path
	if best_page != null:
		_goal = "page"
		_goal_page = best_page
		_route.set_path(best_path)
		return
	if _choose_gate(start):
		return
	if _foe != null:
		var path: Array[Vector2i] = _path(start, wizard.nav.nearest(_tile_of(_foe.global_position)))
		if not path.is_empty():
			_goal = "foe"
			_route.set_path(path)


## When no page is to be had, the nearest gate that it holds a spell for: it goes to the place short of it. True when it has set out.
func _choose_gate(start: Vector2i) -> bool:
	var world := wizard.get_tree().get_first_node_in_group(&"world")
	if world == null:
		return false
	var best := {}
	var best_path: Array[Vector2i] = []
	for gate: Dictionary in world.closed_gates():
		if _skip.has(_gate_key(gate)) or _clearing_spell(gate["kind"]) == "":
			continue
		var floor_tile: Vector2i = gate["outside"] + Vector2i(0, -1)
		var stand: Vector2i = wizard.nav.nearest(floor_tile)
		var path: Array[Vector2i] = []
		if absi(stand.x - floor_tile.x) + absi(stand.y - floor_tile.y) <= 3:
			path = _path(start, stand)
		if path.is_empty():
			_skip[_gate_key(gate)] = GIVE_UP
			continue
		if best.is_empty() or path.size() < best_path.size():
			best = gate
			best_path = path
	if best.is_empty():
		return false
	_goal = "gate"
	_goal_gate = best
	_gate_tries = 0
	_gate_gone = 0
	_route.set_path(best_path)
	return true


## The way from one tile to another that it can walk: not over a crossing it holds no spell for.
func _path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var shut := []
	var world := wizard.get_tree().get_first_node_in_group(&"world")
	if world != null:
		for crossing: Dictionary in world.crossings():
			if not _can_cross(crossing["kind"]) or _cannot.has(crossing["key"]):
				shut.append(crossing["key"])
	return wizard.nav.path(from, to, shut)


## Whether it holds a page for crossing this kind of gate.
func _can_cross(kind: String) -> bool:
	return WAYS.get(kind, []).any(_usable)


## The spell it will make its way over a crossing with, the one it likes best of those it knows, or "".
func _way(kind: String) -> String:
	for spell_name: String in WAYS.get(kind, []):
		if _usable(spell_name):
			return spell_name
	return ""


## The spell that lifts it out of a pit of lava, or "": a vine would burn in the lava.
func _way_up() -> String:
	for spell_name in ["Geyser", "Push"]:
		if _knows(spell_name):
			return spell_name
	return ""


## Whether it can cross with a spell: it holds the page, and for black glass, a way up the far side of the pit as well.
func _usable(spell_name: String) -> bool:
	return _knows(spell_name) and (spell_name != "Obsidian Armor" or _way_up() != "")


## What a gate is called on the list of what it has given up.
func _gate_key(gate: Dictionary) -> String:
	return "gate %s" % str(gate["outside"])


## At the gate: strikes it when it is near enough, and otherwise steps up to it, for the part of it that is left may lie farther in.
func _work_gate() -> void:
	var world := wizard.get_tree().get_first_node_in_group(&"world")
	var target: Vector2 = world.gate_target(_goal_gate["entry"])
	var across: float = target.x - wizard.global_position.x
	var reach: int = STRIKE_REACH.get(_clearing_spell(_goal_gate["kind"]), 5)
	if absf(across) <= reach * WizardRoute.TILE and absf(target.y - wizard.center().y) <= minf(reach, 6) * WizardRoute.TILE:
		_clear_gate(target)
		return
	var side := -1 if across > 0.0 else 1  # it stands on the side it came by
	var tile := _tile_of(target)
	var stand: Vector2i = wizard.nav.nearest(Vector2i(tile.x + side * STRIKE_STAND, tile.y))
	var path: Array[Vector2i] = _path(wizard.nav.nearest(_tile_of(wizard.global_position), true), stand)
	if path.is_empty() or absi(stand.x - tile.x) > reach + 2 or absi(stand.y - tile.y) > 6:
		_skip[_gate_key(_goal_gate)] = GIVE_UP
		_goal = ""
		_goal_timer = 0.0
	else:
		_route.set_path(path)


## The spell it will clear this kind of gate with: one it knows and can pay for, or "".
func _clearing_spell(kind: String) -> String:
	for spell_name: String in CLEARS.get(kind, []):
		if _knows(spell_name) and wizard.stamina >= SpellData.SPELLS[spell_name].cost:
			return spell_name
	return ""


## At the gate: strikes it, and again, until it is open or it has tried enough.
func _clear_gate(target: Vector2) -> void:
	if wizard.is_drawing() or _cast_cooldown > 0.0 or _react > 0.0:
		return
	var spell_name := _clearing_spell(_goal_gate["kind"])
	if spell_name == "" or _gate_tries >= CLEAR_TRIES:
		_skip[_gate_key(_goal_gate)] = GIVE_UP
		_goal = ""
		_goal_timer = 0.0
		return
	var gone: int = _goal_gate["entry"].get("gone", []).count(true)
	if gone > _gate_gone:  # a piece has gone since it last struck: it has the whole of its tries for the next
		_gate_tries = 0
	_gate_gone = gone
	_gate_tries += 1
	_cast_cooldown = 2.2
	_begin_cast(spell_name, _gate_stroke(spell_name, target), ATTACK_DRAW)


## The stroke of a spell that strikes a point.
func _gate_stroke(spell_name: String, point: Vector2) -> PackedVector2Array:
	match spell_name:
		"Ignite":
			var start: Vector2 = wizard.center() + Vector2(signf(point.x - wizard.center().x) * 12.0, -6.0)
			return _line(start, start + (point - start).normalized() * 90.0)
		"Fire Breath":
			return _breath_stroke(point)
		"Stonefall":
			return _offset(GestureTemplates.preview_points("stonefall"), Vector2(point.x, point.y - 130.0), 0.8)
		"Earthquake":
			return _offset(GestureTemplates.preview_points("earthquake"), Vector2(point.x, point.y - 120.0), 1.0)
		"Firewall":
			var ground := _ground_under(point)
			return _line(Vector2(point.x, ground - 110.0), Vector2(point.x, ground - 20.0))
		"Volcano":
			return _offset(GestureTemplates.preview_points("volcano"), Vector2(point.x, _ground_under(point) - 60.0), 0.8)
		"Tornado":
			return _offset(GestureTemplates.preview_points("tornado"), Vector2(point.x, _ground_under(point) - 90.0), 0.9)
		"Spark":
			return _offset(GestureTemplates.preview_points("zigzag"), Vector2(point.x, point.y - 90.0), 1.0)
		"Gust":
			var from: Vector2 = wizard.center()
			var cloud := point  # the wind takes a cloud by its middle, which may lie off the point struck, down a slope
			var near := INF
			for node in _goal_gate["entry"].get("nodes", []):  # (untyped: it may be a freed object)
				if is_instance_valid(node) and not node.is_queued_for_deletion() and node.global_position.distance_to(from) < near:
					near = node.global_position.distance_to(from)
					cloud = node.global_position
			return _line(from, from + (cloud - from).normalized() * 90.0)
	return PackedVector2Array()


## The height of the ground under a point (a little above it, looking down).
func _ground_under(point: Vector2) -> float:
	var query := PhysicsRayQueryParameters2D.create(point + Vector2(0, -40), point + Vector2(0, 400))
	query.collision_mask = 1
	var hit := wizard.get_world_2d().direct_space_state.intersect_ray(query)
	return hit["position"].y if not hit.is_empty() else point.y


## It is getting nowhere on its way: find the way again, and after a few tries give the page up for a while.
func _stuck_on_goal() -> void:
	_replans += 1
	if _goal == "page" and _replans >= 3 and is_instance_valid(_goal_page):
		_skip[_goal_page.get_instance_id()] = GIVE_UP
		_replans = 0
		_choose_goal()
		return
	var start: Vector2i = wizard.nav.nearest(_tile_of(wizard.global_position), true)
	var path: Array[Vector2i] = _path(start, _route.goal())
	if path.is_empty():
		_goal = ""
	else:
		_route.set_path(path)


## What it is doing, for a report.
func status() -> String:
	return "%s (%s)" % [_goal if _goal != "" else "nothing", _route.status()]


# --- Reactions --------------------------------------------------------------------------------------------------


## The nearest of your shots that will hit it soon: {"eta": seconds, "dir": its direction}, or nothing.
func _incoming_shot() -> Dictionary:
	var best := {}
	for node in wizard.get_tree().get_nodes_in_group("projectiles"):
		if node.caster == wizard:
			continue
		var velocity: Vector2 = node.velocity()
		var rel: Vector2 = wizard.center() - node.global_position
		var closing := rel.dot(velocity.normalized())
		if closing <= 0.0:
			continue
		var eta := closing / velocity.length()
		var miss := (rel - velocity.normalized() * closing).length()
		if eta < 0.9 and miss < 28.0 and (best.is_empty() or eta < best["eta"]):
			best = {"eta": eta, "dir": velocity.normalized()}
	return best


## The sentinels that have it in sight, when it holds a spell to meet them with.
func _watchers() -> Array:
	var out := []
	if not COVERS.any(_knows):
		return out
	for post: Sentinel in wizard.get_tree().get_nodes_in_group("sentinels"):
		if post.sees(wizard.center()):
			out.append(post)
	return out


## Counts how many shots you have thrown lately, so it knows when to put up walls.
func _track_shots() -> void:
	for node in wizard.get_tree().get_nodes_in_group("projectiles"):
		if node.caster != wizard and not _seen_shots.has(node.get_instance_id()):
			_seen_shots[node.get_instance_id()] = true
			_pressure += 1.0
	if _seen_shots.size() > 64:
		_seen_shots.clear()


func _choose_defence(eta: float) -> String:
	var options := {"jump": 1.0}
	if _knows("Gust") and wizard.stamina >= 15.0 and eta > QUICK_DRAW + 0.05:
		options["reflect"] = 0.6 + 1.6 * skill  # a skilled wizard sends your spells back at you
	if _knows("Barrier") and wizard.stamina >= 35.0 and eta > QUICK_DRAW + 0.05:
		options["shield"] = 0.5
	if _knows("Shadow Step") and wizard.stamina >= 10.0:
		options["blink_side"] = 0.7
	if not wizard.is_on_floor():
		options.erase("jump")
	return _pick(options) if not options.is_empty() else ""


func _choose_repel() -> String:
	var options := {}
	if _knows("Push") and wizard.stamina >= 10.0:
		options["push"] = 1.5
	if _knows("Shadow Step") and wizard.stamina >= 10.0:
		options["blink_away"] = 1.0
	if _knows("Fire Breath") and wizard.stamina >= 16.0 and _clear_line(wizard.center(), _foe.center()):
		options["breath"] = 1.3
	return _pick(options) if not options.is_empty() else "escape"


func _act(reaction: String) -> void:
	var foe: Wizard = _foe
	match reaction:
		"jump":
			if wizard.is_on_floor():
				wizard.request_jump(0.8)
			_defend_cooldown = 0.6
		"reflect":
			# A Gust blown toward where the shot came from: it turns the shot round and sends it back.
			var start: Vector2 = wizard.center() - _threat_dir * 20.0
			_begin_cast("Gust", _line(start, start - _threat_dir * 90.0), QUICK_DRAW)
			_defend_cooldown = 1.4
		"cover":
			var watchers := _watchers()
			if not watchers.is_empty():
				_cover(watchers[0])
			_defend_cooldown = 4.0
		"shield":
			_begin_cast("Barrier", _offset(GestureTemplates.preview_points("circle"), wizard.center(), 0.8), QUICK_DRAW)
			_defend_cooldown = 2.5
		"blink_side", "blink_away":
			_blink_away(foe)
			_defend_cooldown = 1.6
		"escape":
			_escape_dir = _safe_side()
			_escape_time = 0.6
			if _knows("Shadow Step") and wizard.stamina >= 12.0 and _rng.randf() < skill * 0.6:
				_blink_away(foe)
			_defend_cooldown = 0.6
		"push":
			var away: Vector2 = (foe.center() - wizard.center()).normalized()
			_begin_cast("Push", _push_stroke(foe.center(), away), QUICK_DRAW)
			_defend_cooldown = 1.5
		"breath":
			_begin_cast("Fire Breath", _breath_stroke(foe.center()), QUICK_DRAW + 0.1)
			_defend_cooldown = 1.8


## Steps away from the player along the ground, or past them if its back is to a wall.
func _blink_away(foe: Wizard) -> void:
	var away := -signf(foe.global_position.x - wizard.global_position.x)
	if away == 0.0:
		away = 1.0
	var room := (ArenaGen.right_edge() - wizard.global_position.x) if away > 0.0 else (wizard.global_position.x - ArenaGen.left_edge())
	if room < 120.0:
		away = -away  # cornered: go past the player instead
	var start: Vector2 = wizard.center()
	_begin_cast("Shadow Step", _line(start, start + Vector2(away * 240.0, -12.0)), QUICK_DRAW)


# --- Footwork ---------------------------------------------------------------------------------------------------


func _footwork(delta: float, to_player: Vector2, sees: bool) -> float:
	if wizard.is_drawing():
		return 0.0
	var speed := WALK_SPEED
	if _escape_time > 0.0:
		return _escape_dir * speed * 1.3
	var gap := absf(to_player.x)
	var toward := signf(to_player.x)
	var dir := 0.0
	if not sees:
		dir = toward  # get a clear line
	elif gap < NEAR:
		dir = -toward
	elif gap > FAR:
		dir = toward
	else:
		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_timer = _rng.randf_range(0.6, 1.4)
			_strafe = [-1.0, 0.0, 0.0, 1.0][_rng.randi() % 4]
		dir = _strafe
	# Never back into the edge of the map; it would rather stand its ground there.
	var x: float = wizard.global_position.x
	if (dir < 0.0 and x < ArenaGen.left_edge() + 60.0) or (dir > 0.0 and x > ArenaGen.right_edge() - 60.0):
		dir = 0.0
	# Never walk into something burning.
	if dir != 0.0 and _in_danger(wizard.global_position + Vector2(dir * 34.0, -10.0)):
		dir = 0.0
	if wizard.is_on_floor() and _jump_cooldown <= 0.0:
		var blocked: bool = dir != 0.0 and wizard.is_on_wall()
		# Up onto a ledge you are standing on, whether or not it can see you, or when it is blocked.
		var above: bool = to_player.y < -50.0 and absf(to_player.x) < 260.0
		# While it moves it hops every second or two, so it is never a statue on the ground.
		_hop_timer -= delta
		var hop: bool = dir != 0.0 and _hop_timer <= 0.0
		if hop:
			_hop_timer = _rng.randf_range(1.0, 2.2) - 0.3 * skill
		if blocked or above or hop:
			wizard.request_jump()
			_jump_cooldown = 0.9
	return dir * speed


## Which way is away from danger: the side with fewer dangerous spots near it.
func _safe_side() -> float:
	var left := 0
	var right := 0
	for step in [30.0, 60.0, 90.0]:
		if _in_danger(wizard.global_position + Vector2(-step, -10.0)):
			left += 1
		if _in_danger(wizard.global_position + Vector2(step, -10.0)):
			right += 1
	if left == right:
		return -signf(_foe.global_position.x - wizard.global_position.x)
	return -1.0 if left < right else 1.0


## True when anything that hurts (any spell, its own included) would reach it at this point.
func _in_danger(point: Vector2) -> bool:
	for node in wizard.get_tree().get_nodes_in_group("danger"):
		if node.danger_at(point):
			return true
	return false


func _clear_line(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1
	return wizard.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


# --- Attacks ----------------------------------------------------------------------------------------------------


## Picks an attack for the situation and starts drawing it. Returns false if nothing is worth casting now.
func _attack(to_player: Vector2, sees: bool) -> bool:
	var foe: Wizard = _foe
	if absf(to_player.x) > ATTACK_RANGE:
		return false  # too far off to aim at you: it waits for you to come within reach
	var gap := absf(to_player.x)
	var still: bool = foe.velocity.length() < 30.0
	var stuck: bool = _held(foe)
	var grounded: bool = foe.is_on_floor()
	var same_ground: bool = grounded and wizard.is_on_floor() and absf(foe.global_position.y - wizard.global_position.y) < 8.0
	var closing: bool = signf(foe.velocity.x) == signf(-to_player.x) and absf(foe.velocity.x) > 60.0
	var aim_ok := absf(to_player.normalized().x) > 0.4  # a near-vertical stroke would draw a Firewall instead
	var scores := {
		"Ignite": (2.0 if gap > 140.0 else 0.8) if sees and aim_ok else 0.0,
		"Frostbolt": (0.4 if foe.is_slowed() else 1.6) if sees else 0.0,
		"Spark": 2.2 if still or stuck else 1.0,
		"Stonefall": 3.0 if stuck else (1.8 if still else 0.5),
		"Icicles": 0.0,  # they need a ceiling, and the arenas have none yet
		"Volcano": 1.2 if gap > 160.0 and grounded else 0.2,
		"Tornado": (0.6 + _pressure * 0.5) if gap < 260.0 else 0.2,
		"Ice Prison": 1.3 if gap < 360.0 and not stuck else 0.0,
		"Mudslide": 1.1 if grounded and not stuck else 0.0,
		"Black Hole": (0.4 + _pressure * 0.4) if gap < 300.0 else 0.0,
		"Firewall": 1.6 if closing and gap < 280.0 and gap > 90.0 else 0.0,
		"Blizzard": 0.4 if grounded else 0.0,
		"Fire Breath": 1.8 if gap < 240.0 else 0.0,
		"Earthquake": 1.5 if grounded and gap < 300.0 and _own_walkers_near(300.0) < 2 else 0.0,
	}
	if _sheltered():
		# Under a platform: lightning from above cannot reach you.
		scores["Spark"] = 0.0
	if not sees:
		# Behind cover: only spells that come from above or along the ground reach you.
		for spell_name in ["Ignite", "Frostbolt", "Ice Prison", "Black Hole", "Firewall", "Fire Breath"]:
			scores[spell_name] = 0.0
	for spell_name in scores.keys():
		if not _knows(spell_name) or wizard.stamina < SpellData.SPELLS[spell_name].cost:
			scores[spell_name] = 0.0
		elif spell_name in _recent:
			scores[spell_name] *= 0.25  # it does not keep repeating itself
	var choice := _pick(scores)
	if choice == "":
		return false
	_recent.push_front(choice)
	if _recent.size() > 2:
		_recent.pop_back()
	_begin_cast(choice, _attack_stroke(choice), ATTACK_DRAW)
	return true


## True when something solid (a platform or the ground) is above you, so nothing from the sky can reach you.
func _sheltered() -> bool:
	var top: Vector2 = _foe.center() + Vector2(0, -50)
	# Cast from the sky down, the way lightning comes: a one-way platform only stops things from above.
	var query := PhysicsRayQueryParameters2D.create(top + Vector2(0, -600), top)
	query.collision_mask = 1 | 16
	return not wizard.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Where you will be by the time a spell lands, judged with the wizard's skill: a skilled wizard leads you well.
func _predict(seconds: float) -> Vector2:
	var foe: Wizard = _foe
	var lead: Vector2 = foe.velocity * seconds * skill
	lead.y = 0.0 if foe.is_on_floor() else lead.y * 0.5
	return foe.center() + lead


## The gesture for an attack, drawn where the spell should land.
func _attack_stroke(spell_name: String) -> PackedVector2Array:
	var foe: Wizard = _foe
	var feet: Vector2 = foe.global_position
	var facing := signf(foe.global_position.x - wizard.global_position.x)
	if facing == 0.0:
		facing = 1.0
	match spell_name:
		"Ignite", "Frostbolt":
			var start: Vector2 = wizard.center() + Vector2(facing * 12.0, -6.0)
			var target := _predict(start.distance_to(foe.center()) / SHOT_SPEED)
			var aim := (target - start).angle() + _rng.randfn(0.0, 0.16 * (1.0 - skill))
			return _line(start, start + Vector2.from_angle(aim) * 90.0)
		"Spark":
			var x := _predict(ATTACK_DRAW * 0.8).x
			return _offset(GestureTemplates.preview_points("zigzag"), Vector2(x, foe.center().y - 90.0), 1.0)
		"Stonefall":
			var x := _predict(ATTACK_DRAW + 0.6).x
			return _offset(GestureTemplates.preview_points("stonefall"), Vector2(x, foe.center().y - 130.0), 0.8)
		"Volcano":
			var x := _predict(ATTACK_DRAW).x
			return _offset(GestureTemplates.preview_points("volcano"), Vector2(x, feet.y - 60.0), 0.8)
		"Tornado":
			var x: float = lerpf(wizard.global_position.x, foe.global_position.x, 0.45)
			return _offset(GestureTemplates.preview_points("tornado"), Vector2(x, feet.y - 90.0), 0.9)
		"Ice Prison":
			return _offset(GestureTemplates.preview_points("circle"), _predict(ATTACK_DRAW * 0.6), 0.8)
		"Earthquake":
			# Drawn in the air above the middle of the fight, where the peaks read clearly.
			return _offset(GestureTemplates.preview_points("earthquake"), Vector2(_predict(ATTACK_DRAW * 0.6).x, foe.center().y - 120.0), 1.0)
		"Mudslide":
			var x := _predict(ATTACK_DRAW * 0.6).x
			return _offset(GestureTemplates.preview_points("pit"), Vector2(x, feet.y - 60.0), 1.0)
		"Black Hole":
			# Beyond you if you are close (it drags you away from it), between you if you keep shooting at it.
			var spot: Vector2 = foe.center() + Vector2(facing * 80.0, 0.0)
			if _pressure > 1.5:
				spot = wizard.center().lerp(foe.center(), 0.4)
			var spiral := GestureTemplates.preview_points("spiral")
			# The black hole forms where the spiral ends, so place the spiral's end on the spot.
			return _offset(spiral, spot - (spiral[spiral.size() - 1] - _centre_of(spiral)), 1.0)
		"Firewall":
			var x: float = lerpf(wizard.global_position.x, foe.global_position.x, 0.5)
			return _line(Vector2(x, feet.y - 110.0), Vector2(x, feet.y - 20.0))
		"Blizzard":
			return _offset(GestureTemplates.preview_points("snowfall"), Vector2(feet.x - 30.0, foe.center().y - 70.0), 0.8)
		"Fire Breath":
			return _breath_stroke(foe.center())
	return PackedVector2Array()


## A Fire Breath cone with its point at the wizard and its mouth toward you, a little off when it is unskilled.
## It draws the cone longer when you are farther off, so the fire reaches you.
func _breath_stroke(target: Vector2) -> PackedVector2Array:
	var gap: float = wizard.center().distance_to(target)
	var size := clampf(gap / 150.0, 1.0, 1.4)
	var aim: float = (target - wizard.center()).angle() + _rng.randfn(0.0, 0.2 * (1.0 - skill))
	var tip: Vector2 = wizard.center() + Vector2.from_angle(aim) * 20.0
	var out := PackedVector2Array()
	for p in GestureTemplates.preview_points("cone"):
		out.append(tip + p.rotated(aim) * size)
	return _densify(out)


## A Push: a circle round you, starting on its far side, then a line out of it pointing away from the wizard.
func _push_stroke(around: Vector2, away: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var start_angle := away.angle()
	for i in 33:
		pts.append(around + Vector2.from_angle(start_angle + TAU * i / 32.0) * 30.0)
	var exit := pts[pts.size() - 1]
	pts.append(exit + away * 90.0)
	return _densify(pts)


## Starts the wizard drawing a spell's gesture. The spell happens when the drawing is done, if nothing breaks it.
func _begin_cast(spell_name: String, stroke: PackedVector2Array, draw_time: float) -> void:
	if stroke.size() < 2:
		return
	var data: Spell = SpellData.SPELLS[spell_name]
	var mask: int = data.buttons
	var caster: Caster = wizard.caster
	wizard.start_drawing(stroke, SpellData.SCHOOL_COLORS[data.school], func(points: PackedVector2Array) -> void:
		caster.cast_stroke(mask, _shaken(points)), draw_time)


## While the ground shakes, each point of the wizard's stroke is nudged by the screen's shake, the same amount the
## player's stroke is nudged by the shaking view.
func _shaken(points: PackedVector2Array) -> PackedVector2Array:
	var tree := wizard.get_tree()
	if not Earthquake.is_shaking(tree):
		return points
	var px := GameCamera.shake_px(tree)
	var shaken := PackedVector2Array()
	for p in points:
		shaken.append(p + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * px)
	return shaken


# --- Shapes -----------------------------------------------------------------------------------------------------


func _line(a: Vector2, b: Vector2) -> PackedVector2Array:
	return _densify(PackedVector2Array([a, b]))


## A preview shape, scaled, with the middle of its bounding box moved to a point.
func _offset(shape: PackedVector2Array, middle: Vector2, scale: float) -> PackedVector2Array:
	var centre := _box_centre(shape)
	var out := PackedVector2Array()
	for p in shape:
		out.append(middle + (p - centre) * scale)
	return _densify(out)


func _box_centre(points: PackedVector2Array) -> Vector2:
	return GestureTemplates.bounds(points).get_center()


func _centre_of(points: PackedVector2Array) -> Vector2:
	return _box_centre(points)


## The stroke with points every two pixels, as dense as one drawn with the mouse.
func _densify(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size() - 1:
		var steps := maxi(1, int(points[i].distance_to(points[i + 1]) / 2.0))
		for k in steps:
			out.append(points[i].lerp(points[i + 1], float(k) / steps))
	out.append(points[points.size() - 1])
	return out


## Picks a key at random, weighted by its value. Returns "" when every weight is zero.
func _pick(weights: Dictionary) -> String:
	var total := 0.0
	for key in weights:
		total += maxf(weights[key], 0.0)
	if total <= 0.0:
		return ""
	var roll := _rng.randf() * total
	for key in weights:
		roll -= maxf(weights[key], 0.0)
		if roll <= 0.0 and weights[key] > 0.0:
			return key
	return ""


## How many of the wizard's own walkers stand within reach of the player: an earthquake would shake them too.
func _own_walkers_near(reach: float) -> int:
	var count := 0
	var target: Wizard = _foe
	for other in wizard.get_tree().get_nodes_in_group("mobs"):
		if other.is_dead() or other.KINDS[other.kind].role == "flyer":
			continue
		if other.center().distance_to(target.center()) < reach:
			count += 1
	return count

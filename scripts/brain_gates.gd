class_name BrainGates
extends RefCounted

## What an AI wizard does at the gates of a world: the ways over a crossing (a pit, a flood, gas, a wall, a sentinel's post) and the clearing of a gate
## that is struck open. It keeps what it has bridged, what it cannot do and the row of pads it is laying; the leap, wade and lift of a crossing are `BrainMoves`.

var goal_gate := {}              # the gate it is going to clear: {"kind", "outside", "target", "entry"}
var gate_tries := 0
var gate_gone := 0              # how many pieces of the gate had gone when it last struck it
var bridged := {}               # crossing (by key) -> seconds more that the way over it, which this wizard made, will last
var cross_run := 0.0            # the speed it goes at while it makes its way over a crossing
var pad_walk := {}              # crossing (by key) -> {"dir", "end"}: the row of pads laid over it, and the x it walks along them to
var pads := {}                  # crossing (by key) -> {"dir", "front"}: the row of Lily Pads it has made so far over a long pit
var cannot := {}                # crossing (by key) -> seconds more that it will not try it, having fallen in

var brain: WizardBrain
var wizard: Wizard


func _init(owner: WizardBrain, body: Wizard) -> void:
	brain = owner
	wizard = body


## The crossing the way goes over soon, if the way over it is not made: {"kind", "key", "span", "post"}. A pit counts when it is the next few tiles
## off, a sentinel from much farther, for it sees a long way.
func crossing_ahead() -> Dictionary:
	var world := brain.the_world()
	for tiles in WizardBrain.SENTINEL_LOOKOUT:
		var key := toll_between(brain.route.ahead(tiles - 1) if tiles > 0 else wizard.nav.nearest(brain.tile_of(wizard.global_position), true), brain.route.ahead(tiles))
		if key == "" or bridged.has(key):
			continue
		for crossing: Dictionary in world.crossings():
			if crossing["key"] == key and (tiles < 4 or crossing["kind"] == "sentinel"):
				return crossing
	return {}


## While it is on a row of pads it has laid over water, it walks along them to the end of the row rather than hopping from one to the next (a hop
## that lands a little short drops it in). True when it is walking them (or standing at the end of the row), with the speed in `cross_run`.
func walking_pads() -> bool:
	if pad_walk.is_empty() or not wizard.is_on_floor():
		return false
	var world := brain.the_world()
	for crossing: Dictionary in world.crossings():
		if not pad_walk.has(crossing["key"]):
			continue
		var span: Rect2 = crossing["span"]
		var dir: int = pad_walk[crossing["key"]]["dir"]
		var end: float = pad_walk[crossing["key"]]["end"]
		var x := wizard.global_position.x
		if x < span.position.x - WizardRoute.TILE or x > span.end.x + WizardRoute.TILE or (end - x) * dir < -WizardRoute.TILE:
			continue  # not on this row
		cross_run = dir * WizardBrain.WALK_SPEED if (end - x) * dir > 8.0 else 0.0
		return true
	return false


## The crossing whose toll lies on a move from one tile to the next, or "": a long jump over a pit passes over tiles that the path never names.
func toll_between(from: Vector2i, to: Vector2i) -> String:
	if to == WorldNav.NONE:
		return ""
	for step in range(1, absi(to.x - from.x) + 1):
		var key: String = wizard.nav.toll_at(Vector2i(from.x + step * signi(to.x - from.x), to.y if step == absi(to.x - from.x) else from.y))
		if key != "":
			return key
	return wizard.nav.toll_at(to)


## Makes the way over a crossing, a stroke at a time. True while it is at it and must stand; false when it may walk on (a sentinel too
## far off to see it yet, or nothing it can do).
func cross(crossing: Dictionary) -> bool:
	if wizard.is_drawing() or brain.react > 0.0:
		return true
	if crossing["kind"] == "sentinel":
		return cross_sentinel(crossing)
	var spell_name := way_over(crossing)
	if spell_name == "":
		return false
	var span: Rect2 = crossing["span"]
	var dir := 1 if span.get_center().x > wizard.global_position.x else -1
	if pads.has(crossing["key"]):
		dir = pads[crossing["key"]]["dir"]  # a row of pads is laid along the way it set out
	cross_run = 0.0
	match spell_name:
		"Geyser", "Rocket Jump", "Push", "Liana", "Updraft", "Great Oak", "Tornado":
			return cross_by_lift(crossing, spell_name, span, dir)
		"Obsidian Armor":
			cross_by_wading(crossing, spell_name, span, dir)
		"chant:deep_breath":
			return cross_by_breath(crossing, spell_name, span, dir)
		"Shadow Step":
			cross_by_leap(crossing, span, dir, 2.0 * SpellData.SPELLS[spell_name].cost, {"steps": clampi(ceili((span.size.x - 200.0) / 300.0), WizardBrain.LEAP_STEPS, 5)})
		"chant:double_jump":
			if at_the_edge(span, dir) and wizard.is_on_floor() and (wizard.air_jump_time > 0.0 or brain.chant.type_then_say("double_jump")):
				start_leap(crossing, span, dir, {"steps": 0, "double": true})
		"leap:air":
			cross_by_air(crossing, span, dir)
		"Lily Pads":
			cross_by_pads(crossing, spell_name, span, dir)
		_:  # a bridge across the whole of it
			if wizard.stamina >= SpellData.SPELLS[spell_name].cost:
				brain.hand.begin_cast(spell_name, brain.hand.bridge_stroke(spell_name, span), WizardBrain.ATTACK_DRAW)
				brain.settle = WizardBrain.SETTLE
				bridged[crossing["key"]] = WizardBrain.LASTS[spell_name]
	return true


## A sentinel in the way: it covers itself from the post, once near enough to see it.
func cross_sentinel(crossing: Dictionary) -> bool:
	if wizard.center().distance_to(crossing["post"].center()) > WizardBrain.COVER_RANGE:
		return false
	var used := cover(crossing["post"], int(crossing.get("posts", 1)) > 1)
	if used == "":
		return false
	bridged[crossing["key"]] = WizardBrain.LASTS[used]
	return true


## Walks toward the near edge of a crossing, and says so while it is still on the way (see cross_run). True once it stands at the edge.
func at_the_edge(span: Rect2, dir: int, ahead := 20.0) -> bool:
	var edge := span.position.x if dir > 0 else span.end.x
	if (edge - wizard.global_position.x) * dir > ahead:
		cross_run = dir * WizardBrain.WALK_SPEED
		return false
	return true


## Begins a leap across a crossing (see _leaping), with the fields that differ by the way it is made.
func start_leap(crossing: Dictionary, span: Rect2, dir: int, extra: Dictionary) -> void:
	brain.moves.start_leap(crossing["key"], span, dir, extra)


## It walks up to the face of the wall and stands there while the ground bubbles under it, while it shoves itself up, while it climbs a vine,
## a column of air or an oak, or while a whirlwind flings it.
func cross_by_lift(crossing: Dictionary, spell_name: String, span: Rect2, dir: int) -> bool:
	var face := span.position.x - 36.0 if dir > 0 else span.end.x + 36.0
	if absf(face - wizard.global_position.x) > 12.0:
		cross_run = clampf(face - wizard.global_position.x, -WizardBrain.WALK_SPEED, WizardBrain.WALK_SPEED)
	elif wizard.is_on_floor() and wizard.stamina >= SpellData.SPELLS[spell_name].cost and not brain.moves.begin_lift(spell_name, crossing["key"], dir, span):
		return false
	return true


## It puts on black glass at the edge, wades through the lava, and gets up the far side by a lift.
func cross_by_wading(crossing: Dictionary, spell_name: String, span: Rect2, dir: int) -> void:
	if not at_the_edge(span, dir):
		return
	if wizard.is_on_floor() and wizard.stamina >= SpellData.SPELLS[spell_name].cost + SpellData.SPELLS[way_up()].cost:
		brain.hand.begin_cast(spell_name, BrainStrokes.offset(GestureTemplates.preview_points("circle"), wizard.center(), 0.8), WizardBrain.QUICK_DRAW)
		brain.moves.wade = {"dir": dir, "key": crossing["key"], "span": span, "stage": 0, "waited": 0.0}


## It walks to the edge of the gas, holds its breath, and walks through.
func cross_by_breath(crossing: Dictionary, spell_name: String, span: Rect2, dir: int) -> bool:
	if not at_the_edge(span, dir, WizardBrain.BREATH_AHEAD):
		return true
	if wizard.deep_breath_time > 0.0 or brain.chant.type_then_say(spell_name.substr(6)):
		bridged[crossing["key"]] = minf(wizard.deep_breath_time, WizardBrain.GAS_WALK) if wizard.deep_breath_time > 0.0 else WizardBrain.GAS_WALK
		brain.settle = WizardBrain.SETTLE
	elif brain.chant.is_typing():
		pass  # it is typing the words, standing at the edge
	else:
		cannot[crossing["key"]] = WizardBrain.GIVE_UP
		return false
	return true


## It walks to the edge, waits there until it is on the ground with strength to spare, and leaps.
func cross_by_leap(crossing: Dictionary, span: Rect2, dir: int, needs: float, extra: Dictionary) -> void:
	if at_the_edge(span, dir) and wizard.is_on_floor() and wizard.stamina >= needs:
		start_leap(crossing, span, dir, extra)


## It jumps from the edge, and in the air a rocket throws it up and a feather lets it drift down, across.
func cross_by_air(crossing: Dictionary, span: Rect2, dir: int) -> void:
	if not at_the_edge(span, dir) or not wizard.is_on_floor():
		return
	var air: Array[String] = []
	for helper: String in ["Rocket Jump", "Featherfall"]:
		if brain.knows(helper):
			air.append(helper)
	var cost := 0.0
	for helper in air:
		cost += SpellData.SPELLS[helper].cost
	if wizard.stamina >= cost:
		start_leap(crossing, span, dir, {"steps": 0, "helpers": air})


## A row of pads at a time, as far as it reaches, and the next when it has come to the end of that.
func cross_by_pads(crossing: Dictionary, spell_name: String, span: Rect2, dir: int) -> void:
	if wizard.stamina < SpellData.SPELLS[spell_name].cost:
		return
	var reach := span.grow_individual(WizardRoute.TILE, 0.0, WizardRoute.TILE, 0.0)  # pads run a tile onto the bank at each end
	var near := reach.position.x if dir > 0 else reach.end.x
	var front: float = pads[crossing["key"]]["front"] if pads.has(crossing["key"]) else near
	var from_x := maxf(front, wizard.global_position.x) if dir > 0 else minf(front, wizard.global_position.x)
	var to_x := clampf(from_x + dir * WizardBrain.PADS_REACH, reach.position.x, reach.end.x)
	var row := Rect2(minf(from_x, to_x), span.position.y, absf(to_x - from_x), span.size.y)
	brain.hand.begin_cast(spell_name, brain.hand.bridge_stroke(spell_name, row), WizardBrain.ATTACK_DRAW)
	brain.settle = WizardBrain.SETTLE
	var over := (to_x - (reach.end.x if dir > 0 else reach.position.x)) * dir >= 0.0
	pads[crossing["key"]] = {"dir": dir, "front": to_x}
	pad_walk[crossing["key"]] = {"dir": dir, "end": to_x}
	bridged[crossing["key"]] = WizardBrain.LASTS[spell_name] if over else WizardBrain.SETTLE + absf(to_x - from_x) / WizardBrain.WALK_SPEED - 0.8  # the next row goes down when it is near the end of this one
	if over:
		pads.erase(crossing["key"])


## Draws what keeps a sentinel from hitting it: smoke over the statue, or a Barrier, or a Decoy. The name of the spell, or "" when it can do none.
func cover(post: Node2D, many := false) -> String:
	for spell_name: String in (WizardBrain.COVER_ALL if many else WizardBrain.COVERS):  # (a screen over one shooter does nothing against the rest: a shield goes with the wizard)
		if not brain.knows(spell_name) or wizard.stamina < SpellData.SPELLS[spell_name].cost:
			continue
		var around: Vector2 = wizard.center()
		match spell_name:
			"Smoke Screen":
				var base: Vector2 = post.center()
				brain.hand.begin_cast(spell_name, BrainStrokes.offset(GestureTemplates.preview_points("smoke"), base + Vector2(0, -30.0), 0.9), WizardBrain.QUICK_DRAW)
			"Eclipse":
				brain.hand.begin_cast(spell_name, BrainStrokes.offset(GestureTemplates.preview_points("eclipse"), post.center() + Vector2(0, -20.0), 1.0), WizardBrain.QUICK_DRAW)
			"Barrier":
				brain.hand.begin_cast(spell_name, BrainStrokes.offset(GestureTemplates.preview_points("circle"), around, 0.8), WizardBrain.QUICK_DRAW)
			"Decoy":
				brain.hand.begin_cast(spell_name, BrainStrokes.offset(GestureTemplates.preview_points("eight"), around + Vector2(-40.0 * signf(post.center().x - around.x), 0.0), 0.7), WizardBrain.QUICK_DRAW)
		return spell_name
	return ""


## The way it will go over this crossing, the one it likes best of those it knows and that will carry it so far, or "".
func way_over(crossing: Dictionary) -> String:
	for spell_name: String in WizardBrain.WAYS.get(crossing["kind"], []):
		if usable(spell_name) and (spell_name != "chant:double_jump" or (crossing["span"] as Rect2).size.x <= WizardBrain.DOUBLE_JUMP_REACH):
			return spell_name
	return ""


## The spell it will make its way over a crossing with, the one it likes best of those it knows, or "".
func way(kind: String) -> String:
	for spell_name: String in WizardBrain.WAYS.get(kind, []):
		if usable(spell_name):
			return spell_name
	return ""


## A crossing it fell short of: it will not try it again for a while.
func give_up_on(key: String) -> void:
	cannot[key] = WizardBrain.GIVE_UP


## A crossing it has made its way over: the way holds for a moment.
func crossed(key: String, seconds := 2.0) -> void:
	bridged[key] = seconds


## The spell that lifts it out of a pit of lava, or "": a vine would burn in the lava.
func way_up() -> String:
	for spell_name in ["Geyser", "Push"]:
		if brain.knows(spell_name):
			return spell_name
	return ""


## Whether it can cross with a spell: it holds the page, and for black glass, a way up the far side of the pit as well.
func usable(spell_name: String) -> bool:
	if spell_name == "leap:air":
		return brain.knows("Rocket Jump") or brain.knows("Featherfall")
	return brain.knows(spell_name) and (spell_name != "Obsidian Armor" or way_up() != "")


## What a gate is called on the list of what it has given up.
func gate_key(gate: Dictionary) -> String:
	return "gate %s" % str(gate["outside"])


## At the gate: strikes it when it is near enough, and otherwise steps up to it, for the part of it that is left may lie farther in.
func work_gate() -> void:
	var world := brain.the_world()
	var target: Vector2 = world.gate_target(goal_gate["entry"])
	var across: float = target.x - wizard.global_position.x
	var reach: int = WizardBrain.STRIKE_REACH.get(clearing_spell(goal_gate["kind"]), 5)
	if absf(across) <= reach * WizardRoute.TILE and absf(target.y - wizard.center().y) <= minf(reach, 6) * WizardRoute.TILE:
		clear_gate(target)
		return
	var side := -1 if across > 0.0 else 1  # it stands on the side it came by
	var tile := brain.tile_of(target)
	var stand: Vector2i = wizard.nav.nearest(Vector2i(tile.x + side * WizardBrain.STRIKE_STAND, tile.y))
	var path: Array[Vector2i] = brain.find_path(wizard.nav.nearest(brain.tile_of(wizard.global_position), true), stand)
	if path.is_empty() or absi(stand.x - tile.x) > reach + 2 or absi(stand.y - tile.y) > 6:
		brain.skip[gate_key(goal_gate)] = WizardBrain.GIVE_UP
		brain.goal = ""
		brain.goal_timer = 0.0
	else:
		brain.route.set_path(path)


## Whether a gate has been cleared: a piece of the world marks itself open; a creature in the way is cleared when it is dead or asleep.
func gate_open(entry: Dictionary) -> bool:
	if entry.get("open", false):
		return true
	if entry.has("mob"):
		var mob = entry["mob"]
		return not is_instance_valid(mob) or mob.is_dead() or mob.is_fainted()
	return false


## A creature in the way ahead that it holds a spell for: it deals with it where it stands before it walks on.
func creature_ahead() -> Dictionary:
	var world := brain.the_world()
	if world == null or not wizard.is_on_floor():
		return {}
	var toward := signf(float(brain.route.ahead(1).x - brain.tile_of(wizard.global_position).x)) if not brain.route.done() and brain.route.ahead(1) != WorldNav.NONE else wizard.facing
	for gate: Dictionary in world.closed_gates():
		if gate["kind"] != "creature" and gate["kind"] != "giant":
			continue
		var spell_name := clearing_spell(gate["kind"])
		if spell_name == "" or gate_open(gate["entry"]):
			continue
		var apart: Vector2 = gate["target"] - wizard.center()
		if signf(apart.x) == toward and absf(apart.x) < float(WizardBrain.STRIKE_REACH.get(spell_name, 8)) * WizardRoute.TILE * 0.7 and absf(apart.y) < 120.0:
			return gate
	return {}


## The spell it will clear this kind of gate with: one it knows and can pay for, or "".
func clearing_spell(kind: String) -> String:
	for spell_name: String in WizardBrain.CLEARS.get(kind, []):
		if brain.knows(spell_name) and wizard.stamina >= SpellData.SPELLS[spell_name].cost:
			return spell_name
	return ""


## At the gate: strikes it, and again, until it is open or it has tried enough.
func clear_gate(target: Vector2) -> void:
	if wizard.is_drawing() or brain.cast_cooldown > 0.0 or brain.react > 0.0:
		return
	var spell_name := clearing_spell(goal_gate["kind"])
	if spell_name == "" or gate_tries >= WizardBrain.CLEAR_TRIES:
		brain.skip[gate_key(goal_gate)] = WizardBrain.GIVE_UP
		brain.goal = ""
		brain.goal_timer = 0.0
		return
	var gone: int = goal_gate["entry"].get("gone", []).count(true)
	if gone > gate_gone:  # a piece has gone since it last struck: it has the whole of its tries for the next
		gate_tries = 0
	gate_gone = gone
	gate_tries += 1
	brain.cast_cooldown = 2.2
	brain.hand.begin_cast(spell_name, brain.hand.gate_stroke(spell_name, target), WizardBrain.ATTACK_DRAW)


## What the gate it is working on has in the way (a cloud of gas, a wall): each may be gone by now, so each is to be checked.
func gate_nodes() -> Array:
	return goal_gate["entry"].get("nodes", [])

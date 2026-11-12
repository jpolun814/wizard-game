class_name HandBrain
extends WizardBrain

## A wizard played through a person's controls and nothing else: a trained network (or the trainer, while it learns) presses the keys to walk, jump
## and drop through a platform, and chooses a spell from its book and where on the screen to cast it. The hand then draws that spell's picture there,
## with a person's speed and wobble, and the recognizer reads it as it reads anyone's (a stroke can still misfire). None of the scripted brain plays:
## no route, no reflexes, no choice of goal. What it senses is what a person sees (Senses).
##
## Its choices, every DECISION_EVERY seconds (HEADS, in this order, which is the alphabetical order of their names: Godot RL Agents sorts the heads
## by name, so any other order would put the trainer's choices, and the mask, in the wrong places):
##   aim_x, aim_y   where on the screen: a cell of an AIM_COLS x AIM_ROWS grid laid over the screen about it
##   cast   0 nothing, 1 + i the spell at Senses.SPELL_ORDER[i]: only a spell in its book, and only while its hand is free (see mask)
##   jump   0 no, 1 jump (as a press of the key)
##   move   0 stand, 1 left, 2 right
##
## Used by training/duel_arena.gd (the curriculum: training/train_duel.py) and, once trained, by any AI wizard (brain.policy).

const AIM_COLS := 32  # about 27 px a cell on the screen: finer than a wizard is wide, as a person aims with a mouse (12 x 7 missed a wizard across the lane)
const AIM_ROWS := 18
const CASTS := 1 + Senses.BOOK_SPELLS
const HEADS := {"aim_x": AIM_COLS, "aim_y": AIM_ROWS, "cast": CASTS, "jump": 2, "move": 3}
const MASK := AIM_COLS + AIM_ROWS + CASTS + 2 + 3  # one number for each choice of each head: 1 when it can be chosen now
const CAST_AT := AIM_COLS + AIM_ROWS  # where the cast head's choices begin, in the mask and the network's outputs
const SIZE := Senses.SIZE + MASK  # what the network is given: the senses, then the mask (what its hand can do now)
const DECISION_EVERY := 0.2  # seconds between choices: about the rate a person changes what they are doing
const LEAST_DRAW := 0.35     # seconds a stroke takes at the quickest, where people's own times were not recorded

var policy: PolicyNet        # plays it in a game, or as the opponent in training; while it learns the trainer chooses (training/hand_agent.gd)
var turret: Wizard           # a yardstick for the trainer, not a player: it stands, and casts its book's first spell at this wizard over and over

var move := 0
var jump := 0
var cast := 0
var aim := Vector2i.ZERO
var fresh := false           # a new choice has come, not yet acted on: a jump and a cast happen once for each choice
var _decide_in := 0.0
var _turret_wait := 1.0


## Nothing but what the controls do: the keys walk and jump, and a cast is drawn. (The scripted brain's think is not called.)
func think(delta: float) -> void:
	if wizard.dead or wizard.fainted:
		return
	if turret != null:
		_turret(delta)
		return
	if policy != null:
		_decide_in -= delta
		if _decide_in <= 0.0:
			_decide_in = DECISION_EVERY
			_decide()
	wizard.walk([0.0, -1.0, 1.0][clampi(move, 0, 2)] * Wizard.SPEED)
	if not fresh:
		return
	fresh = false
	if jump == 1:
		wizard.request_jump()
	if cast > 0 and can_cast(cast - 1):
		_cast(Senses.SPELL_ORDER[cast - 1], aim_point(aim))


## A person's hand is not stopped by the brain: a blow breaks a stroke only where the body says so.
func on_hurt(_amount: int) -> void:
	pass


func holds_still() -> bool:
	return false  # a person may walk while drawing (the stroke is dragged with the screen)


func is_typing() -> bool:
	return false


## What it senses (Senses), then the mask: SIZE numbers.
func observe() -> PackedFloat32Array:
	var obs := wizard.senses.observe()
	obs.append_array(mask())
	return obs


## For each choice of each head, 1 when it can be chosen now: every move, jump and aim; a spell only if it is in the book and the hand is free.
func mask() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(MASK)
	out.fill(1.0)
	var free := not wizard.is_drawing()
	for i in Senses.BOOK_SPELLS:
		out[CAST_AT + 1 + i] = 1.0 if free and can_cast(i) else 0.0
	return out


## Whether the spell at this place of the book order is one its hand can begin: in the book, the hand free, and nothing stopping it from casting.
func can_cast(index: int) -> bool:
	if index < 0 or index >= Senses.SPELL_ORDER.size():
		return false
	var spell_name: String = Senses.SPELL_ORDER[index]
	return wizard.ledger.knows_spell(spell_name) and SpellData.SPELLS.has(spell_name) and not wizard.is_drawing() and not wizard.silenced() \
		and wizard.rage_time <= 0.0 and not wizard.wild


## Whether a network can play a hand: it takes SIZE numbers, and if it reads lists with encoders of their own, it reads them where the senses put them.
## A network trained on another layout would read nonsense and play it, so it is refused instead.
static func fits(net: PolicyNet) -> bool:
	if net == null:
		return false
	if net.inputs() != SIZE:
		push_error("a network for %d senses cannot play a hand (%d)" % [net.inputs(), SIZE])
		return false
	var spans := net.list_spans()
	for name: String in spans:
		if Senses.list_spans().get(name) != spans[name]:
			push_error("a network reads its list %s at %s, but the senses put it at %s" % [name, spans[name], Senses.list_spans().get(name)])
			return false
	return true


## The middle of a cell of the aiming grid, in the world: the grid covers the screen as it stands about the wizard (a person aims at what they see).
func aim_point(cell: Vector2i) -> Vector2:
	var view := wizard.eyes.rect()
	var u := (clampi(cell.x, 0, AIM_COLS - 1) + 0.5) / AIM_COLS
	var v := (clampi(cell.y, 0, AIM_ROWS - 1) + 0.5) / AIM_ROWS
	return view.position + Vector2(u * view.size.x, v * view.size.y)


## The cell of the aiming grid a point of the world lies in (the other way from aim_point).
func cell_of(point: Vector2) -> Vector2i:
	var view := wizard.eyes.rect()
	var u := (point - view.position) / view.size
	return Vector2i(clampi(int(u.x * AIM_COLS), 0, AIM_COLS - 1), clampi(int(u.y * AIM_ROWS), 0, AIM_ROWS - 1))


## The network's choice, drawn by weight among what can be chosen (as it was trained).
func _decide() -> void:
	var logits := policy.forward(observe())
	var allowed := mask()
	var from := 0
	var picked := {}
	for head: String in HEADS:
		var count: int = HEADS[head]
		var ok := PackedInt32Array()
		for k in count:
			if allowed[from + k] > 0.5:
				ok.append(k)
		picked[head] = policy.choose(logits, head, true, ok)
		from += count
	move = picked["move"]
	jump = picked["jump"]
	cast = picked["cast"]
	aim = Vector2i(picked["aim_x"], picked["aim_y"])
	fresh = true


## The hand draws the spell's picture toward the point: a shot is a flick from the body toward it, anything else its shape drawn there.
func _cast(spell_name: String, point: Vector2) -> bool:
	var data: Spell = SpellData.SPELLS[spell_name]
	var stroke: PackedVector2Array
	if not is_nan(GestureTemplates.preview_ground(data.gesture)):
		stroke = _from_ground(data.gesture, point)  # (before the flicks: a Stone Wall is aimed along its line, but begun on the ground)
	elif data.targeting == "directional":
		var start := wizard.center() + Vector2(wizard.facing * 12.0, -6.0)
		var dir := (point - start).normalized() if point.distance_to(start) > 1.0 else Vector2(wizard.facing, 0.0)
		stroke = _line(start, start + dir * 90.0)
	else:
		stroke = _offset(GestureTemplates.preview_points(data.gesture), point, 1.0)
	var draw_time := maxf(_quickest_stroke(spell_name), LEAST_DRAW)
	var caster: Caster = wizard.caster
	var buttons: int = data.buttons
	return wizard.start_drawing(stroke, SpellData.SCHOOL_COLORS[data.school], func(points: PackedVector2Array) -> void:
		caster.cast_stroke(buttons, _shaken(_handed(points))), draw_time)


## A shape that must be begun on something solid (a Stone Wall): its picture's ground put on the ground under the aimed point, a little into it,
## and leaning the way the wizard faces. A person draws it from the ground at the place they want it, not around the place.
func _from_ground(gesture: String, point: Vector2) -> PackedVector2Array:
	var shape := GestureTemplates.preview_points(gesture)
	var ground := GestureTemplates.preview_ground(gesture)
	var anchor := shape[0]
	for p in shape:
		if absf(p.y - ground) < absf(anchor.y - ground):
			anchor = p
	var base := Vector2(point.x, _ground_under(point) + 4.0)
	var out := PackedVector2Array()
	for p in shape:
		out.append(base + Vector2((p.x - anchor.x) * wizard.facing, p.y - anchor.y))
	return _densify(out)


## The yardstick: it stands, and every so often casts its book's first spell straight at its mark (no leading, no dodging).
func _turret(delta: float) -> void:
	wizard.walk(0.0)
	_turret_wait -= delta
	if _turret_wait > 0.0 or not is_instance_valid(turret) or turret.dead or wizard.is_drawing() or wizard.ledger.pages.is_empty():
		return
	_turret_wait = 1.5
	wizard.facing = signf(turret.global_position.x - wizard.global_position.x) if turret.global_position.x != wizard.global_position.x else wizard.facing
	_cast(String(wizard.ledger.pages.keys()[0]), turret.center())

class_name FightOrFlight
extends Node2D

## Fight or Flight: the blood of whoever is under the sign is stirred, one way or the other, by chance. Half the time they fight: for a few
## seconds they cast spells at random, as many as they can pay for, and cannot cast the ones they would choose. The other half they flee: for
## the same few seconds they cannot move toward the one who cast it. Each spell they cast costs what it costs.
## Whichever it is, it is decided with the cast's own throw of the dice, so every machine of a network game sees the same.

const REACH := 90.0      # how close to the middle of the sign someone must be to be caught
const SECONDS := 6.0     # how long it holds
const CAST_EVERY := 0.8  # seconds between the spells of someone who fights
const FIGHT := Color("#ff3a3a")
const FLIGHT := Color("#d8ecff")
const QUESTION := preload("res://art/fx/question_mark.png")  # a question mark in pixels, made for the game (tools/make_marks.py)

var target: Wizard
var caster: Wizard
var fights := false
var _mark: Sprite2D
var _age := 0.0
var _until_cast := 0.4


## Whoever is closest to a point, if they are near enough to be under the sign.
static func nearest_under(tree: SceneTree, point: Vector2) -> Wizard:
	var best: Wizard = null
	var best_distance := REACH
	for wizard: Wizard in SpellTargets.wizards(tree):
		var distance := wizard.center().distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = wizard
	return best


func _ready() -> void:
	add_to_group("lasting")
	fights = randf() < 0.5
	z_index = 9
	var colour := FIGHT if fights else FLIGHT
	_mark = Sprite2D.new()
	_mark.texture = QUESTION
	_mark.modulate = colour  # red for the one who fights, pale for the one who flees
	_mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mark.scale = Vector2(2.0, 2.0)
	add_child(_mark)
	Fx.burst(get_parent(), target.center(), colour, 18, 160.0, 0.5, true)
	Fx.impact(get_parent(), target.center(), colour, 50.0)
	Sfx.play("heartbeat", target.center(), -2.0)
	if target.is_likeness():
		return  # the machine that plays them does the rest
	if fights:
		target.rage_time = SECONDS
	else:
		target.afraid_of = caster
		target.fear_time = SECONDS


func _physics_process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(target) or target.dead or _age >= SECONDS:
		queue_free()
		return
	global_position = target.center() + Vector2(0.0, -46.0)
	queue_redraw()
	if fights and not target.is_likeness():
		_until_cast -= delta
		if _until_cast <= 0.0:
			_until_cast = CAST_EVERY
			_cast_at_random()


## One spell from those the wizard knows, drawn at random and a little way off from them, as a frenzied hand would. It is paid for like any.
func _cast_at_random() -> void:
	if target.is_frozen() or target.fainted or target.silenced():
		return
	var known: Array[Spell] = []
	for spell: Spell in SpellData.SPELLS.values():
		if spell.spell_name != "Fight or Flight" and target.ledger.knows_spell(spell.spell_name) and target.stamina >= spell.cost:
			known.append(spell)
	if known.is_empty():
		return
	var pick: Spell = known[randi() % known.size()]
	var shape := GestureTemplates.preview_points(pick.preview if pick.preview != "" else pick.gesture)
	if shape.size() < 2:
		return
	var low := shape[0]
	var high := shape[0]
	for point in shape:
		low = low.min(point)
		high = high.max(point)
	var middle := (low + high) * 0.5
	var flip := -1.0 if randf() < 0.5 else 1.0
	var at := target.center() + Vector2(randf_range(60.0, 220.0) * flip, randf_range(-70.0, 10.0))
	var stroke := PackedVector2Array()
	for point in shape:
		stroke.append(at + Vector2((point.x - middle.x) * flip, point.y - middle.y))
	var hand := target.ensure_caster()
	hand.anchor = target.center()
	hand.cast_stroke(pick.buttons, stroke)


## The glow behind the question mark over the head, red for the one who fights and pale for the one who flees. The mark bobs.
func _draw() -> void:
	var colour := FIGHT if fights else FLIGHT
	Fx.draw_glow(self, Vector2.ZERO, 16.0, Color(colour.r, colour.g, colour.b, 0.45))
	if _mark != null:
		_mark.position.y = -12.0 + sin(_age * 9.0) * 2.0  # (the mark is big enough that it must sit higher, clear of the head)

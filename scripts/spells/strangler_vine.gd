class_name StranglerVine
extends FloraSpell

## Strangler Vine: a spiral drawn in the open, and a moment later vines burst out of the ground there and wrap whoever is in reach, holding them for a while and
## squeezing. Anyone who steps clear before it springs is spared. Fire burns the vines and sets whoever they hold free. Whoever is caught may be the caster.

const REACH := 70.0        # how far from the middle of the spot a body is caught
const RISE := 0.55         # seconds from the first shoots to the spring
const HOLD := 3.0
const SQUEEZES := 4
const HARM := 4
const GAP := 0.7
const HEIGHT := 120.0      # how high the vines stand
const LINK := 18.0
const VINES := 3

var _state := "rising"   # rising, holding, done
var _age := 0.0
var _held: Array = []
var _squeezed := 0
var _clock := 0.0
var _hang: Node2D


func _ready() -> void:
	global_position = _ground_at(global_position)
	add_to_group("danger")
	_hang = Node2D.new()
	_hang.z_index = 1
	add_child(_hang)
	for v in VINES:
		var lean := (float(v) - 1.0) * 0.28
		var stem := Node2D.new()
		stem.rotation = lean
		_hang.add_child(stem)
		for i in ceili(HEIGHT / LINK):
			var piece := Sprite2D.new()
			piece.texture = load("res://art/props/dusk_vine.png")
			piece.rotation = PI * 0.5
			piece.flip_v = (i + v) % 2 == 1
			piece.modulate = Color(0.7, 0.9, 0.55)
			piece.position = Vector2(0, -(i * LINK + LINK * 0.5))
			stem.add_child(piece)
	_hang.scale = Vector2(1.0, 0.03)
	create_tween().tween_property(_hang, "scale:y", 1.0, RISE).set_ease(Tween.EASE_OUT)
	Fx.debris(get_parent(), global_position, Color("#4a6a30"), 8, 140.0)
	Sfx.play("pickup", global_position, -4.0)


func _physics_process(delta: float) -> void:
	_age += delta
	_burn(delta, Rect2(global_position + Vector2(-REACH, -HEIGHT), Vector2(REACH * 2.0, HEIGHT + 4.0)))
	match _state:
		"rising":
			if _age >= RISE:
				_spring()
		"holding":
			_clock -= delta
			if _clock <= 0.0 and _squeezed < SQUEEZES:
				_squeeze()
			if _age >= RISE + HOLD:
				_let_go()


## The vines close on everyone in reach.
func _spring() -> void:
	_state = "holding"
	for body in SpellTargets.all(get_tree()):
		if body.is_in_group("mobs") and body.KINDS[body.kind].role == "flyer":
			continue
		var at: Vector2 = body.global_position
		if absf(at.x - global_position.x) <= REACH and at.y >= global_position.y - HEIGHT and at.y <= global_position.y + 16.0:
			_held.append(body)
			if body.is_in_group("mobs"):
				body.apply_root(HOLD)
			else:
				body.apply_debuff("root", HOLD)
	var snap := create_tween()
	snap.tween_property(_hang, "scale:x", 0.7, 0.1)
	snap.tween_property(_hang, "scale:x", 1.0, 0.2)
	Sfx.play("chomp", global_position, -4.0)
	_clock = 0.3


func _squeeze() -> void:
	_squeezed += 1
	_clock = GAP
	for body in _held:
		if is_instance_valid(body) and SpellTargets.affects(body):
			SpellTargets.hurt(body, HARM, "Flora", false, false, self)
			Fx.burst(get_parent(), SpellTargets.center_of(body), Color("#6fcf6a"), 5, 70.0, 0.3)


## Nothing is held any more: the vines wither.
func _let_go() -> void:
	_state = "done"
	_held.clear()
	var wither := create_tween()
	wither.tween_property(_hang, "modulate:a", 0.0, 0.6)
	wither.tween_callback(queue_free)


## Burnt down: whoever it held is let go at once.
func _burned_down() -> void:
	for body in _held:
		if is_instance_valid(body):
			if body.is_in_group("mobs"):
				body.free_from_root()
			else:
				body.root_time = 0.0
	queue_free()


func danger_at(point: Vector2) -> bool:
	return _state == "rising" and absf(point.x - global_position.x) <= REACH and absf(point.y - global_position.y) < HEIGHT

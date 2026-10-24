class_name Decoy
extends Node2D

## Decoy: a shadow of the wizard, standing where the eight was drawn. Enemies that can see it go for it instead of the
## wizard. It takes the hits meant for you until it is worn through or its time runs out.

const SECONDS := 8.0
const HEALTH := 40
const PLAYER := preload("res://scripts/player.gd")

var hp := HEALTH
var _age := 0.0
var _dead := false
var _body: AnimatedSprite2D
var _flash := 0.0


## The decoy that is nearest to a point and close enough to be noticed, or null.
static func nearest(tree: SceneTree, point: Vector2, within: float) -> Decoy:
	var best: Decoy = null
	var best_distance := within
	for decoy in tree.get_nodes_in_group("decoys"):
		var distance: float = decoy.center().distance_to(point)
		if not decoy.is_dead() and distance < best_distance:
			best_distance = distance
			best = decoy
	return best


func _ready() -> void:
	add_to_group("decoys")
	add_to_group("lasting")
	_body = AnimatedSprite2D.new()
	_body.sprite_frames = CharFrames.build("res://art/chars/wizard_wand", PLAYER.ANIMATIONS)
	_body.offset = Vector2(0, -PixelArt.CHARACTERS["wizard"]["size"].y * 0.5)
	_body.modulate = Color(0.5, 0.35, 0.75, 0.0)
	_body.play("idle")
	add_child(_body)
	Fx.burst(get_parent(), center(), Color("#9a70d0"), 14, 110.0, 0.5, true)
	Sfx.play("gravity", global_position, -4.0)


func center() -> Vector2:
	return global_position + Vector2(0, -PLAYER.BODY_HEIGHT * 0.5)


func is_dead() -> bool:
	return _dead


## An enemy hits the decoy. It shows no blood: it flickers, and fades when it has had enough.
func take_damage(amount: int, _school := "") -> void:
	if _dead:
		return
	hp -= amount
	_flash = 0.25
	FloatText.spawn(get_parent(), center() + Vector2(0, -50), "%d" % amount, Color("#c8a8ff"), 0.9)
	if hp <= 0:
		_vanish()


func _physics_process(delta: float) -> void:
	_age += delta
	_flash = maxf(_flash - delta, 0.0)
	var alpha := clampf(_age / 0.3, 0.0, 1.0) * clampf((SECONDS - _age) / 0.8, 0.0, 1.0)
	_body.modulate = Color(1.0, 1.0, 1.0, 0.9) if _flash > 0.0 else Color(0.5, 0.35, 0.75, 0.75 * alpha)
	if _age >= SECONDS:
		_vanish()


func _vanish() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("decoys")
	Fx.burst(get_parent(), center(), Color("#9a70d0"), 14, 110.0, 0.5, true)
	queue_free()

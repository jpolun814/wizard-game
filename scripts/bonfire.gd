class_name Bonfire
extends Node2D

## A bonfire that burns for a while on the ground. Standing near it slowly restores health.
## Its flames are the pixel-art fire column; a warm halo glows round them.

const LIFE := 30.0
const REACH := 90.0          # how close the player must stand to be warmed
const HEAL_PER_SECOND := 4.0
const FLAME_BASE := 14.0     # how high up the pile the flames start

## What each kind of world does to the logs, so that they are of the place: the wood is of that ground's trees, and wet, frosted, charred or old.
const LOG_FILTERS := {
	"graveyard": Color(0.78, 0.72, 0.95),
	"jungle": Color(0.78, 1.0, 0.7),
	"mountains": Color(0.72, 0.85, 1.0),
	"ashlands": Color(0.8, 0.5, 0.42),
	"castle": Color(1.0, 0.88, 0.7),
	"underground": Color(0.66, 0.74, 0.95),
	"portals": Color(0.92, 0.74, 1.0),
}

var power := 1.0             # set from the chant's accuracy: a truer chant warms more
var _age := 0.0
var _heal_carry := {}        # wizard -> fractional healing kept between frames
var _flames: Node2D


func _ready() -> void:
	add_to_group("fires")  # it lights the dark and shows up to fire-sensitive things like any other fire
	var logs := Sprite2D.new()  # the fire burns on a pile of logs, seen from the side
	logs.texture = load("res://art/props/bonfire_logs.png")
	var grade := get_tree().get_first_node_in_group("grade") as Grade
	logs.modulate = LOG_FILTERS.get(grade.biome if grade != null else "", Color.WHITE)
	logs.scale = Vector2.ONE
	logs.offset = Vector2(0, -logs.texture.get_height() * 0.5 + 1.0)
	add_child(logs)
	_flames = Node2D.new()
	_flames.material = Fx.additive()
	add_child(_flames)
	_flames.draw.connect(_draw_flames)
	for i in 3:
		var fire := PixelFx.sprite("fire_puff", 12.0 + i * 2.0, true, 1)  # the same flame as the fire breath and the volcano
		fire.scale = Vector2.ONE * (1.2 if i == 1 else 0.9)
		fire.offset = Vector2(0, -PixelArt.FX["fire_puff"]["size"].y * 0.5)
		fire.position = Vector2(-4 + i * 6, -FLAME_BASE + (4.0 if i != 1 else 0.0))
		fire.flip_h = i == 1
		fire.frame = i * 2
		add_child(fire)


func _process(delta: float) -> void:
	_age += delta
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):  # it warms whoever stands by it, like any fire: no one's own
		if wizard.dead or wizard.is_likeness() or wizard.max_stamina >= Wizard.MAX_STAMINA or wizard.global_position.distance_to(global_position) > REACH:
			continue
		var carried: float = float(_heal_carry.get(wizard, 0.0)) + HEAL_PER_SECOND * power * delta
		var whole := int(carried)
		if whole > 0:
			wizard.heal(whole)
			carried -= whole
		_heal_carry[wizard] = carried
	modulate.a = _fade()
	_flames.queue_redraw()
	if _age >= LIFE:
		queue_free()


## Put out by water or cold.
func quench() -> void:
	queue_free()


func _fade() -> float:
	return clampf((LIFE - _age) / 1.5, 0.0, 1.0)


func _draw_flames() -> void:
	var fade := _fade()
	var warm := 1.0 + 0.08 * sin(_age * 5.0)
	# A warm halo that breathes, behind the flames.
	Fx.draw_glow(_flames, Vector2(0, -28), 64.0 * warm, Color(1.0, 0.45, 0.12, 0.05 * fade))
	Fx.draw_glow(_flames, Vector2(0, -28), 40.0 * warm, Color(1.0, 0.55, 0.18, 0.08 * fade))
	# Embers rising off the fire and fading as they climb.
	for i in 9:
		var k := fmod(_age * 0.55 + i / 9.0, 1.0)
		var drift := sin(i * 2.3 + _age * 2.0) * 12.0 * k
		var ember := roundf(2.0 * (1.0 - k)) + 1.0  # a pixel square, smaller as it climbs
		_flames.draw_rect(Rect2(Vector2(roundf(drift), roundf(-34.0 - k * 50.0)), Vector2(ember, ember)), Color(1.0, 0.7, 0.3, 0.9 * (1.0 - k) * fade))


class_name Earthquake
extends Node

## An earthquake that shakes the whole arena for several seconds. The screen shakes harder than a blow shakes it (GameCamera.QUAKE_GAIN), and everything on the ground is
## knocked from side to side on a beat. While it lasts, strokes drawn on the ground are nudged by
## the same shake as the screen, and ranged enemies aim wide.

const SECONDS := 6.0
const BEAT := 0.4
const KNOCK := 160.0
const AIM_DEGREES := 6.0
const QUAKE_BLOW := 12.0     # what each beat takes off it
const WALLS_FALL_AT := 1.0   # seconds in, when the walls raised anywhere in the world come down

var caster: Wizard  # who cast it
var _age := 0.0
var _beat := 0.0
var _side := 1.0
var _walls_fallen := false


func _ready() -> void:
	add_to_group("earthquakes")
	GameCamera.shake_scene(get_tree(), 0.6)
	Sfx.cue("Earthquake", "rumble", null, 0.0)


## True while an earthquake is shaking the ground.
static func is_shaking(tree: SceneTree) -> bool:
	return tree.get_first_node_in_group("earthquakes") != null


func _physics_process(delta: float) -> void:
	_age += delta
	_beat -= delta
	GameCamera.shake_scene(get_tree(), 0.05)
	if not _walls_fallen and _age >= WALLS_FALL_AT:
		_walls_fallen = true  # the whole world shakes, so a slab of stone raised on any of it comes down, wherever it stands
		for wall: StoneWall in get_tree().get_nodes_in_group("walls"):
			if not wall.is_queued_for_deletion():
				wall.crumble()
	if _beat <= 0.0:
		_beat = BEAT
		_side = -_side
		for mob in get_tree().get_nodes_in_group("mobs"):
			if not mob.is_dead():
				mob.knock_back(Vector2(_side * KNOCK, 0.0))
		for thing in get_tree().get_nodes_in_group("breakables"):  # the whole world shakes: a wall of brick or a plug of ice is worn down wherever it stands
			if thing is IcePlug or thing is RockWall:
				thing.take_blow_near(thing.covers_center(), QUAKE_BLOW)
		for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
			if not wizard.dead and wizard.is_on_floor():
				wizard.push(Vector2(_side * KNOCK, 0.0))
	if _age >= SECONDS:
		queue_free()

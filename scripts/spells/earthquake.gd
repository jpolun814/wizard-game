class_name Earthquake
extends Node

## An earthquake that shakes the whole arena for several seconds. The screen shakes, and everything on the ground is
## knocked from side to side on a beat. Flyers are untouched. While it lasts, strokes drawn on the ground are nudged by
## the same shake as the screen, and ranged enemies aim wide.

const SECONDS := 6.0
const BEAT := 0.4
const KNOCK := 160.0
const AIM_DEGREES := 6.0
const QUAKE_REACH := 500.0  # how near the wizard a wall or a plug of ice has to be to be shaken
const QUAKE_BLOW := 12.0     # what each beat takes off it

var _age := 0.0
var _beat := 0.0
var _side := 1.0


func _ready() -> void:
	add_to_group("earthquakes")
	GameCamera.shake_scene(get_tree(), 0.6)
	Sfx.play("quake", null, 0.0)


## True while an earthquake is shaking the ground.
static func is_shaking(tree: SceneTree) -> bool:
	return tree.get_first_node_in_group("earthquakes") != null


func _physics_process(delta: float) -> void:
	_age += delta
	_beat -= delta
	GameCamera.shake_scene(get_tree(), 0.05)
	if _beat <= 0.0:
		_beat = BEAT
		_side = -_side
		for mob in get_tree().get_nodes_in_group("mobs"):
			if not mob.is_dead() and mob.KINDS[mob.kind].role != "flyer":
				mob.knock_back(Vector2(_side * KNOCK, 0.0))
		var player := get_tree().get_first_node_in_group("player")
		if player != null:  # a quake brings down the wall or the plug of ice near the wizard
			for thing in get_tree().get_nodes_in_group("breakables"):
				if thing is IcePlug or thing is RockWall:
					thing.shake(player.global_position, QUAKE_REACH, QUAKE_BLOW)
		if player and not player.dead and player.is_on_floor():
			player.push(Vector2(_side * KNOCK, 0.0))
	if _age >= SECONDS:
		queue_free()

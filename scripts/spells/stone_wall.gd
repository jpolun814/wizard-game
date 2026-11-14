class_name StoneWall
extends SpellEffect

## A slab of the level's earth that grows along the stroke out of the ground, a platform or another wall. It is solid,
## as long as the stroke, and stays until shots wear it down; its face crumbles as it is struck. It is cut from the same earth as
## what it grows from (see RockArt), lumpy and rough at its far end, and it is drawn growing out from its foot.

const LENGTH := 140.0  # a wall drawn without a length of its own
const MIN_LENGTH := 60.0
const MAX_LENGTH := 240.0
const THICKNESS := 22.0

var wall_length := 0.0  # the length of the drawn stroke, set by the arena (0 for the default)
var wall_texture: Texture2D  # the level's earth, set by the arena
var _length := LENGTH
var _stages: Array[Texture2D] = []  # the face whole, part crumbled and mostly crumbled
var _health := 0.0
var _grow := 0.05  # how much of its length has grown, 0 to 1
var _slab: StaticBody2D
var _max_health := 0.0


func _begin(origin: Vector2, aim_angle: float) -> void:
	_life = INF
	add_to_group("walls")
	add_to_group("breakables")
	rotation = aim_angle
	_length = clampf(wall_length, MIN_LENGTH, MAX_LENGTH) if wall_length > 0.0 else LENGTH
	global_position = origin  # the node sits at the foot of the wall; its body lies along local x
	_max_health = _length * 0.45
	_health = _max_health
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cut_faces()
	# The wall's own area catches shots that reach it; the slab inside it is what is solid.
	var reach := RectangleShape2D.new()
	reach.size = Vector2(_length, THICKNESS)
	_add_shape(reach, Vector2(_length * 0.5, 0.0))
	collision_mask = 1  # shots live on layer 1
	area_entered.connect(_on_struck)
	_add_slab()
	Sfx.play("stones", origin, -2.0)  # pebbles shifting under the slab
	Sfx.play("quake", origin)  # and the ground heaving under it
	Fx.debris(get_parent(), origin, Color("#a08060"), 10, 200.0)
	GameCamera.shake_scene(get_tree(), 0.2)


## True where a point lies in the wall once it has grown, so that liquid (which reads the ground by points) is stopped by it.
func holds(point: Vector2) -> bool:
	var local := to_local(point)
	return local.x >= 0.0 and local.x <= _length and absf(local.y) <= THICKNESS * 0.5


## The box that surrounds the wall, in the world.
func footprint() -> Rect2:
	return global_transform * Rect2(0.0, -THICKNESS * 0.5, _length, THICKNESS)


## The solid slab. Enemies and shots collide with it, and a wall can be grown from it.
func _add_slab() -> void:
	var solid := RectangleShape2D.new()
	solid.size = Vector2(_length, THICKNESS)
	var block := CollisionShape2D.new()
	block.shape = solid
	block.position = Vector2(_length * 0.5, 0.0)
	_slab = StaticBody2D.new()
	_slab.add_to_group("stone_walls")
	_slab.add_child(block)
	_slab.scale = Vector2(_grow, 1.0)  # the slab is solid only as far as it has grown
	add_child(_slab)
	var growing := create_tween().set_parallel()
	growing.tween_property(self, "_grow", 1.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	growing.tween_property(_slab, "scale:x", 1.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## Three faces cut from the earth: whole, then with a fifth and with half of it knocked out.
func _cut_faces() -> void:
	var seed_value := int(global_position.x * 7.0 + global_position.y * 13.0)
	for share in [0.0, 0.2, 0.5]:
		_stages.append(RockArt.slab(wall_texture, _length, THICKNESS, share, seed_value, global_position))


## A shot that reaches the wall takes some of its health; the wall crumbles away when it has none left.
func _on_struck(area: Area2D) -> void:
	var damage := SpellTargets.shot_damage(area)
	if damage <= 0:
		return
	_take_blow(damage, area.global_position)


## A club swung near the wall (within reach of its face) takes its blow. True when the swing reached the wall.
func take_blow_near(point: Vector2, damage: float) -> bool:
	var local := to_local(point)
	if local.x < -12.0 or local.x > _length + 12.0 or absf(local.y) > THICKNESS + 20.0:
		return false
	_take_blow(damage, point)
	return true


## Whoever raised a wall can bring it down again: the wall under a point, if there is one, crumbles at once. True if one did.
static func crumble_at(tree: SceneTree, point: Vector2) -> bool:
	for wall: StoneWall in tree.get_nodes_in_group("walls"):
		if wall.holds(point) or wall.to_local(point).distance_to(Vector2(clampf(wall.to_local(point).x, 0.0, wall._length), 0.0)) <= THICKNESS:
			wall._take_blow(wall._health + 1.0, point)
			return true
	return false


func _take_blow(damage: float, at: Vector2) -> void:
	_health -= damage
	if _health <= 0.0:
		Fx.debris(get_parent(), to_global(Vector2(_length * 0.5, 0.0)), Color("#6b5a48"), 16, 220.0)
		Sfx.play("stones", global_position)
		GameCamera.shake_scene(get_tree(), 0.15)
		queue_free()
		return
	Fx.debris(get_parent(), at, Color("#6b5a48"), 5, 120.0)
	Sfx.play("stones", global_position, -6.0)


## The slab's face: the level's earth, crumbling as its health falls, drawn out from its foot as far as it has grown.
func _draw() -> void:
	var ratio := _health / maxf(_max_health, 1.0)
	var picture := _stages[0 if ratio > 0.66 else (1 if ratio > 0.33 else 2)]
	var size := picture.get_size()
	var shown := maxf(floorf(size.x * _grow), 1.0)
	var rect := Rect2(0.0, -size.y * RockArt.BLOCK * 0.5, shown * RockArt.BLOCK, size.y * RockArt.BLOCK)
	draw_texture_rect_region(picture, rect, Rect2(0.0, 0.0, shown, size.y))

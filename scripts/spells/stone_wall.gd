class_name StoneWall
extends SpellEffect

## A slab of the level's earth that rises along the stroke from the ground, a platform or another wall. It is solid,
## as long as the stroke, and stays until shots wear it down; its face crumbles as it is struck.

const LENGTH := 140.0  # a wall drawn without a length of its own
const MIN_LENGTH := 60.0
const MAX_LENGTH := 240.0
const THICKNESS := 22.0

var wall_length := 0.0  # the length of the drawn stroke, set by the arena (0 for the default)
var wall_texture: Texture2D  # the level's earth, set by the arena
var _length := LENGTH
var _stages: Array[Texture2D] = []  # the face whole, part crumbled and mostly crumbled
var _health := 0.0
var _max_health := 0.0


func _begin(origin: Vector2, aim_angle: float) -> void:
	_life = INF
	rotation = aim_angle
	_length = clampf(wall_length, MIN_LENGTH, MAX_LENGTH) if wall_length > 0.0 else LENGTH
	global_position = origin + Vector2.from_angle(aim_angle) * _length * 0.5
	_max_health = _length * 0.45
	_health = _max_health
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_cut_faces()
	# The wall's own area catches shots that reach it; the slab inside it is what is solid.
	var reach := RectangleShape2D.new()
	reach.size = Vector2(_length, THICKNESS)
	_add_shape(reach)
	collision_mask = 1  # shots live on layer 1
	area_entered.connect(_on_struck)
	_add_slab()
	Sfx.play("stones", origin, -2.0)  # pebbles shifting under the slab
	Sfx.play("quake", origin)  # and the ground heaving under it
	Fx.debris(get_parent(), origin, Color("#a08060"), 10, 200.0)
	GameCamera.shake_scene(get_tree(), 0.2)


## The solid slab. Enemies and shots collide with it, and a wall can be grown from it.
func _add_slab() -> void:
	var solid := RectangleShape2D.new()
	solid.size = Vector2(_length, THICKNESS)
	var block := CollisionShape2D.new()
	block.shape = solid
	var slab := StaticBody2D.new()
	slab.set_meta("stone_wall", true)
	slab.add_child(block)
	add_child(slab)
	# It rises out of the ground rather than appearing.
	scale = Vector2(0.2, 1.0)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Three faces cut from the earth texture: whole, then with a fifth and with half of it knocked out.
func _cut_faces() -> void:
	var source := wall_texture.get_image()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for share in [0.0, 0.2, 0.5]:
		var face := source.duplicate()
		for i in int(share * face.get_width() * face.get_height() / 16.0):
			face.fill_rect(Rect2i(rng.randi_range(0, face.get_width() - 4), rng.randi_range(0, face.get_height() - 4), 4, 4), Color(0, 0, 0, 0))
		_stages.append(ImageTexture.create_from_image(face))


## A shot that reaches the wall takes some of its health; the wall crumbles away when it has none left.
func _on_struck(area: Area2D) -> void:
	var damage := SpellTargets.shot_damage(area)
	if damage <= 0:
		return
	_health -= damage
	if _health <= 0.0:
		Fx.debris(get_parent(), global_position, Color("#6b5a48"), 16, 220.0)
		Sfx.play("stones", global_position)
		GameCamera.shake_scene(get_tree(), 0.15)
		queue_free()
		return
	Fx.debris(get_parent(), area.global_position, Color("#6b5a48"), 5, 120.0)
	Sfx.play("stones", global_position, -6.0)


## The slab's face: the level's earth at the ground's own scale, crumbling as its health falls.
func _draw() -> void:
	var ratio := _health / maxf(_max_health, 1.0)
	var stage := 0 if ratio > 0.66 else (1 if ratio > 0.33 else 2)
	var half := _length * 0.5
	var t := THICKNESS * 0.5
	var corners := PackedVector2Array([Vector2(-half, -t), Vector2(half, -t), Vector2(half, t), Vector2(-half, t)])
	var uvs := PackedVector2Array()
	for corner in corners:
		uvs.append(corner / float(ArenaGen.TILE))
	draw_polygon(corners, PackedColorArray([Color("#2a1f1a")]))  # the dark earth behind the face
	draw_polygon(corners, PackedColorArray([Color.WHITE]), uvs, _stages[stage])

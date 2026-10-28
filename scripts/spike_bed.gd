class_name SpikeBed
extends Area2D

## Strips of rock spikes standing on a passage's floor, in the dark: nobody sees them until a light (a flare, a fire) falls on them,
## and then they are seen for a while. Whoever touches them is cut, and a jump clears them.

const DAMAGE := 30
const HEIGHT := 30.0     # how high the spikes stand, which is how high you have to jump
const REMEMBER := 8.0    # seconds they stay in view after the light has gone
const GAP := 0.8         # seconds before the same body is cut again
const SPRITES := ["rock_spike_1", "rock_spike_2", "rock_spike_3"]

var strips: Array = []  # {"x": first column, "width": columns, "floors": the floor's row in each of them}
var _seen := 0.0
var _hurt := {}  # body -> seconds until it can be cut again
var _sprites: Array[Sprite2D] = []
var _boxes: Array[Rect2] = []


func _ready() -> void:
	collision_mask = 6  # the player and enemies
	var t := float(ArenaGen.TILE)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(strips[0]["x"]) if not strips.is_empty() else 1
	for strip: Dictionary in strips:
		var floors: PackedInt32Array = strip["floors"]
		var low := floors[0]
		var high := floors[0]
		for row in floors:
			low = mini(low, row)
			high = maxi(high, row)
		var box := Rect2(strip["x"] * t, low * t - HEIGHT, strip["width"] * t, (high - low) * t + HEIGHT + 4.0)
		_boxes.append(box)
		for k in floors.size():  # a shape for each column, so the spikes follow a slope
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(t, HEIGHT + 4.0)
			shape.shape = rect
			shape.position = Vector2((strip["x"] + k + 0.5) * t, floors[k] * t - HEIGHT * 0.5 + 2.0)
			add_child(shape)
		var x := box.position.x + 8.0
		while x < box.end.x - 4.0:
			var row: int = floors[clampi(int((x - box.position.x) / t), 0, floors.size() - 1)]
			var sprite := Sprite2D.new()
			sprite.texture = load("res://art/props/%s.png" % SPRITES[rng.randi() % SPRITES.size()])
			sprite.offset = Vector2(0, -sprite.texture.get_height() * 0.5 + 2.0)  # it stands on the floor
			sprite.scale = Vector2.ONE * 2.2
			sprite.flip_h = rng.randf() < 0.5
			sprite.position = Vector2(x, row * t)
			sprite.modulate = Color(0.62, 0.6, 0.68, 0.0)
			sprite.z_index = 1
			add_child(sprite)
			_sprites.append(sprite)
			x += 26.0


func _physics_process(delta: float) -> void:
	if _lit():
		_seen = REMEMBER
	else:
		_seen = maxf(_seen - delta, 0.0)
	var alpha := clampf(_seen / 0.6, 0.0, 1.0)
	for sprite in _sprites:
		sprite.modulate.a = alpha
	for body in _hurt.keys():
		_hurt[body] -= delta
		if _hurt[body] <= 0.0 or not is_instance_valid(body):
			_hurt.erase(body)
	for body in get_overlapping_bodies():
		if SpellTargets.affects(body) and not _hurt.has(body) and not (body.is_in_group("mobs") and body.KINDS[body.kind].role == "flyer"):
			_hurt[body] = GAP
			SpellTargets.hurt(body, DAMAGE, "Earth")
			Fx.burst(get_parent(), SpellTargets.center_of(body), Color("#b04040"), 6, 90.0, 0.3)


## True when a light is close to one of the strips.
func _lit() -> bool:
	var tree := get_tree()
	for box in _boxes:
		if SpellTargets.lit_near(tree, box.get_center(), box.size.x * 0.5 + 40.0):
			return true
	return false


## Is the strip of spikes at this point in view now.
func shown() -> bool:
	return _seen > 0.0

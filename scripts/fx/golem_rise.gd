class_name GolemRise
extends Node2D

## The ground growing up around a wizard who is becoming a Golem: spires of the world's own stone climb out of the earth in a ring (some in front of the wizard,
## some behind), close over them, and then, while the golem gets to its feet inside, crumble back into the ground. Pure scenery: it hurts nothing and
## the wizard's own timers (GolemForm) decide when it is over.

const SPIRES := 9
const BLOCK := 2

var _spires: Array[Sprite2D] = []
var _heights: Array[float] = []
var _age := 0.0
var _grow := 0.55
var _total := 1.15


## Raises the stone at `at`, of `earth`, for `total` seconds (the first part growing, the rest falling away).
static func spawn(parent: Node, at: Vector2, earth: Texture2D, total: float) -> void:
	if parent == null:
		return
	var rise := GolemRise.new()
	rise.position = at
	rise._total = total
	rise._build(earth)
	parent.add_child(rise)


func _build(earth: Texture2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x) * 31 + 7
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in SPIRES:
		var side := -1.0 if i % 2 == 0 else 1.0
		var spread := 8.0 + float(i / 2) * 9.0
		var width := rng.randf_range(20.0, 30.0)
		var tall := rng.randf_range(54.0, 92.0) - float(i / 2) * 3.0
		var picture := RockArt.spike(earth, width, tall, true, false, int(position.x) + i * 13)
		var rect := RockArt.spike_rect(picture, true, tall)
		var sprite := Sprite2D.new()
		sprite.texture = picture
		sprite.centered = false
		sprite.offset = rect.position / BLOCK
		sprite.position = Vector2(side * spread + rng.randf_range(-3.0, 3.0), 0.0)
		sprite.scale = Vector2(BLOCK, 0.0)
		sprite.z_index = 1 if i % 3 != 0 else -1  # most stand in front of the wizard, so they are covered
		add_child(sprite)
		_spires.append(sprite)
		_heights.append(rng.randf_range(0.0, 0.12))  # each starts a moment apart


func _process(delta: float) -> void:
	_age += delta
	for i in _spires.size():
		var sprite := _spires[i]
		var t := clampf((_age - _heights[i]) / _grow, 0.0, 1.0)
		var up := 1.0 - pow(1.0 - t, 3.0)
		var fall := clampf((_age - _grow) / maxf(_total - _grow, 0.05), 0.0, 1.0)
		sprite.scale = Vector2(BLOCK, BLOCK * up * (1.0 - fall * fall))
		sprite.modulate.a = 1.0 - maxf(fall - 0.6, 0.0) * 2.5
	if _age >= _total:
		queue_free()

class_name EmberRain
extends Node

## During an ash storm of the ashlands, lumps of glowing rock fall out of the sky here and there and burn where they land (they are the
## volcanoes' own LavaBall). They fall within sight of the player this machine plays, from places the world's seed and age pick.

const SLOT := 1.1       # seconds between one fall and the next
const NEAR := 600.0     # how far each way from the player a fall is made
const SKY := 480.0      # how far above the ground it starts

var squall: Squall
var seed_value := 0
var player: Node2D
var floors := PackedInt32Array()

var _slot := -1


func _physics_process(_delta: float) -> void:
	if squall == null or squall.level() < 0.4 or player == null:
		return
	var slot := int(squall.seconds / SLOT)
	if slot == _slot:
		return
	_slot = slot
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + slot * 331
	var tile := float(ArenaGen.TILE)
	for k in 2:
		var x := player.global_position.x + rng.randf_range(-NEAR, NEAR)
		var column := clampi(int(x / tile), SurfaceGen.MARGIN + 4, floors.size() - SurfaceGen.MARGIN - 4)
		LavaBall.throw(get_parent(), Vector2(x, floors[column] * tile - SKY), Vector2(rng.randf_range(-40.0, 40.0), 60.0))

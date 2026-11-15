class_name LevelCrystal
extends StaticBody2D

## One light of the wall that sets the level of the AI wizards (LevelWall): a cave crystal that a shot can hit. It stands on a layer of its own (bit 2, the one
## enemies use) so a shot stops on it but a wizard walks past it.

signal shot

const ART := preload("res://art/props/crystal_3.png")
const SCALE := 2.0  # whole numbers only for pixel art


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(ART.get_width(), ART.get_height()) * SCALE
	shape.shape = rect
	shape.position = Vector2(0.0, -rect.size.y * 0.5)
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = ART
	sprite.scale = Vector2.ONE * SCALE
	sprite.offset = Vector2(0.0, -ART.get_height() * 0.5)
	add_child(sprite)


## A shot has hit it (see Projectile). Only a person's shot counts: the sparring partner's misses must not change the level.
func struck(by: Wizard) -> void:
	if by != null and by.human:
		shot.emit()

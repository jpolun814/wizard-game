class_name ForceWall
extends SpellEffect

## A brief flick of force along the stroke that bats away shots. It touches nothing else: characters pass through.

const LIFE := 1.3  # long enough to be seen; the timing is the challenge


func _begin(origin: Vector2, aim_angle: float) -> void:
	_life = LIFE
	rotation = aim_angle
	var rect := RectangleShape2D.new()
	rect.size = Vector2(124, 26)  # long along the stroke, so it deflects along its angle
	_add_shape(rect)
	collision_mask = 1  # shots live on layer 1; characters (layers 2 and 4) are never touched
	area_entered.connect(_on_shot)
	# A bolt of arcane light streaks forward through the wall and fades.
	var flick := PixelFx.sprite("magic_bolt", 18.0, false)
	flick.scale = Vector2.ONE * 2.0
	flick.modulate = Color(1.0, 0.75, 1.0)
	flick.material = Fx.additive()
	flick.position = Vector2(-30.0, 0)
	add_child(flick)
	var streak := create_tween()
	streak.tween_property(flick, "position", Vector2(30.0, 0), 0.3)
	streak.parallel().tween_property(flick, "modulate:a", 0.0, 0.3)
	Sfx.play("force", origin)


## A shot that touches the wall is turned back, as a mirror would send it, and from then on it can hit whoever sent it.
func _on_shot(area: Area2D) -> void:
	if not area.is_in_group("shots"):
		return
	var normal := Vector2(-sin(rotation), cos(rotation))
	var incoming: Vector2 = area.heading()
	area.reflect(incoming - 2.0 * incoming.dot(normal) * normal)


func _draw() -> void:
	Fx.draw_glow(self, Vector2.ZERO, 50.0, Color(0.7, 0.5, 1.0, 0.25 * _fade()))

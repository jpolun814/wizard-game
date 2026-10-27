class_name FloraSpell
extends Node2D

## What every plant spell shares: it is flammable. Fire that touches it sets it alight, and after a moment of burning
## it is gone. Plants are in the "flora" group, and in "lasting".

const BURN_SECONDS := 1.4

var burn_seconds := BURN_SECONDS  # a bigger plant takes longer to burn down
var _burning := 0.0  # counts up from zero once the plant is on fire
var _gone := false   # it has burned away


func _enter_tree() -> void:
	add_to_group("flora")
	add_to_group("lasting")


## Call every physics frame with the box the plant fills. Fire in the box lights it, and it burns away after a moment.
func _burn(delta: float, box: Rect2) -> void:
	if _gone:
		return
	if _burning <= 0.0:
		if SpellTargets.fire_touching(get_tree(), box):
			_ignite(box)
		return
	_burning += delta
	if _burning >= burn_seconds:
		_gone = true
		Fx.smoke(get_parent(), box.get_center(), Color(0.2, 0.2, 0.2, 0.5), 6, 24.0, 40.0)
		_burned_down()


func is_burning() -> bool:
	return _burning > 0.0


## Sets the plant alight: flames of the Firewall's pixel fire along its bottom edge and up its height, and the sound of it catching.
func _ignite(box: Rect2) -> void:
	_burning = 0.001
	var across := clampi(int(box.size.x / 30.0), 1, 6)
	var up := clampi(int(box.size.y / 60.0) + 1, 1, 3)
	for row in up:
		for i in across:
			var flame := PixelFx.sprite("fire_puff", 13.0 + (i + row) % 3 * 2.0, true, 1)
			flame.offset = Vector2(0, -PixelArt.FX["fire_puff"]["size"].y * 0.5)
			flame.frame = (i * 2 + row * 3) % 7
			flame.flip_h = (i + row) % 2 == 1
			flame.scale = Vector2.ONE * (1.4 if row > 0 else 1.7)
			var along := box.position.x + box.size.x * (i + 0.5) / across
			flame.position = to_local(Vector2(along, box.end.y - row * box.size.y / up * 0.8))
			flame.z_index = 4
			add_child(flame)
	Sfx.play("fire_hit", box.get_center(), -4.0)


## What happens when the plant has burned away. Most simply vanish.
func _burned_down() -> void:
	queue_free()


## The ground a plant stands on at a point: a point inside the earth (a line drawn on a slope) is lifted to the surface,
## and one in the air drops to the ground below it.
func _ground_at(point: Vector2) -> Vector2:
	return SpellTargets.surface_over(get_world_2d(), point)

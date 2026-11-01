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


## Sets the plant alight: a fire scattered over it (see Flames), and the sound of it catching.
func _ignite(box: Rect2) -> void:
	_burning = 0.001
	Flames.lay(self, box, int(box.position.x * 3.0 + box.position.y), box.size.y * 0.5)
	Sfx.play("fire_hit", box.get_center(), -4.0)


## What happens when the plant has burned away. Most simply vanish.
func _burned_down() -> void:
	queue_free()


## The ground a plant stands on at a point: a point inside the earth (a line drawn on a slope) is lifted to the surface,
## and one in the air drops to the ground below it.
func _ground_at(point: Vector2) -> Vector2:
	return SpellTargets.surface_over(get_world_2d(), point)

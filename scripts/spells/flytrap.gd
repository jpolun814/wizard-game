class_name Flytrap
extends FloraSpell

## Flytrap: a plant grows on the ground where the jaws were drawn and waits, up to a minute. Whoever steps on it is
## snapped up and held, you included. Flyers pass over, and so does anyone who jumps. Fire burns it.

const WAIT_SECONDS := 60.0
const REACH := 28.0       # how close to its middle a foot has to come
const HOLD_SECONDS := 3.0
const BITES := 3
const BITE_DAMAGE := 8
const BITE_GAP := 0.9
const PLANT := preload("res://art/props/bush_large.png")

var _state := "growing"  # growing, waiting, holding
var _age := 0.0
var _victim: Node2D
var _bites := 0
var _bite_clock := 0.0
var _hold := 0.0
var _picture: Sprite2D


func _ready() -> void:
	global_position = SpellTargets.surface_over(get_world_2d(), global_position)
	add_to_group("danger")
	_picture = Sprite2D.new()
	_picture.texture = PLANT
	_picture.offset = Vector2(0, -PLANT.get_height() * 0.5 + 2.0)
	_picture.modulate = Color(1.0, 0.6, 0.7)  # a dark red plant, so it reads as something to avoid
	_picture.z_index = 1
	_picture.scale = Vector2(1.0, 0.05)
	add_child(_picture)
	create_tween().tween_property(_picture, "scale:y", 1.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	Sfx.play("earth", global_position, -4.0)


func _physics_process(delta: float) -> void:
	_age += delta
	_burn(delta, Rect2(global_position + Vector2(-34, -60), Vector2(68, 64)))
	match _state:
		"growing":
			if _age >= 0.5:
				_state = "waiting"
		"waiting":
			var prey := _prey()
			if prey != null:
				_snap(prey)
			elif _age >= WAIT_SECONDS:
				queue_free()
		"holding":
			_hold += delta
			_bite_clock -= delta
			if not is_instance_valid(_victim) or _victim.global_position.distance_to(global_position) > 70.0:
				_release()  # whoever it held was flung away, or is gone
			elif _bite_clock <= 0.0 and _bites < BITES:
				_bite()
			if _hold >= HOLD_SECONDS:
				_release()


## Who is standing on the plant: a walker on the ground within reach. Flyers never are, and neither is anyone in the air.
func _prey() -> Node2D:
	for body in SpellTargets.all(get_tree()):
		if body.is_in_group("mobs") and body.KINDS[body.kind]["role"] == "flyer":
			continue
		var feet: Vector2 = body.global_position
		if absf(feet.x - global_position.x) <= REACH and feet.y >= global_position.y - 20.0 and feet.y <= global_position.y + 12.0:
			return body
	return null


func _snap(prey: Node2D) -> void:
	_state = "holding"
	_victim = prey
	_hold = 0.0
	_bites = 0
	_bite_clock = 0.0
	if prey.is_in_group("mobs"):
		prey.apply_root(HOLD_SECONDS)
	else:
		prey.apply_debuff("root", HOLD_SECONDS)
	_picture.scale = Vector2(1.15, 0.7)  # the jaws shut
	Sfx.play("earth", global_position)


func _bite() -> void:
	_bites += 1
	_bite_clock = BITE_GAP
	SpellTargets.hurt(_victim, BITE_DAMAGE, "Flora")
	Fx.burst(get_parent(), global_position + Vector2(0, -20), Color("#c04050"), 8, 90.0, 0.4)
	Sfx.play("stones", global_position, -4.0)
	var chomp := create_tween()
	chomp.tween_property(_picture, "scale", Vector2(1.25, 0.55), 0.08)
	chomp.tween_property(_picture, "scale", Vector2(1.15, 0.7), 0.15)


## It has had its fill: it lets go and withers.
func _release() -> void:
	_victim = null
	_state = "withered"
	var wither := create_tween()
	wither.tween_property(_picture, "modulate:a", 0.0, 0.8)
	wither.tween_callback(queue_free)


func danger_at(point: Vector2) -> bool:
	return _state == "waiting" and absf(point.x - global_position.x) < REACH + 12.0 and absf(point.y - global_position.y) < 30.0

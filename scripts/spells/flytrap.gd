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
const PLANT := preload("res://art/props/flytrap.png")  # six frames of 64 px: three of the open mouth swaying, three of the lunge that shuts it
const FRAME := 64
const SIZE := 2.0   # drawn at twice its size, like the other props
const LURKING := 0.22  # how much of its height shows while it lies in wait: it crouches in the ground, just its tips above it
const LURKING_TINT := Color(0.4, 0.46, 0.38, 0.62)  # and takes on the colour of the ground and leaves round it, dim and half seen through
const SOIL := 51.0  # the row of a frame the plant's foot stands on

var _state := "growing"  # growing, waiting, holding
var _age := 0.0
var _victim: Node2D
var _bites := 0
var _bite_clock := 0.0
var _hold := 0.0
var _picture: AnimatedSprite2D


func _ready() -> void:
	global_position = SpellTargets.surface_over(get_world_2d(), global_position)
	add_to_group("danger")
	_picture = AnimatedSprite2D.new()
	_picture.sprite_frames = _frames()
	_picture.offset = Vector2(0, FRAME * 0.5 - SOIL)
	_picture.flip_h = int(global_position.x / 32.0) % 2 == 0  # the art faces left; which way each plant faces comes from where it stands, so it is the same on every machine
	_picture.z_index = 1
	_picture.scale = Vector2(SIZE, SIZE * 0.05)
	_picture.modulate = LURKING_TINT
	_picture.play("waiting")
	_picture.speed_scale = 0.0  # it does not sway while it hides: nothing moving would give it away
	add_child(_picture)
	create_tween().tween_property(_picture, "scale:y", SIZE * LURKING, 0.5).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	_age += delta
	_burn(delta, Rect2(global_position + Vector2(-40, -90), Vector2(80, 94)))
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
		if body.is_in_group("mobs") and body.KINDS[body.kind].role == "flyer":
			continue
		var feet: Vector2 = body.global_position
		if absf(feet.x - global_position.x) <= REACH and feet.y >= global_position.y - 20.0 and feet.y <= global_position.y + 12.0:
			return body
	return null


## The plant's frames, cut from the strip: the mouth open and swaying while it waits, and the lunge that shuts it, which stays shut.
func _frames() -> SpriteFrames:
	var out := SpriteFrames.new()
	out.remove_animation("default")
	for part: Array in [["waiting", 0, 3, true, 5.0], ["snap", 3, 3, false, 14.0]]:
		out.add_animation(part[0])
		out.set_animation_loop(part[0], part[3])
		out.set_animation_speed(part[0], part[4])
		for k in part[2]:
			var frame := AtlasTexture.new()
			frame.atlas = PLANT
			frame.region = Rect2((part[1] + k) * FRAME, 0, FRAME, FRAME)
			out.add_frame(part[0], frame)
	return out


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
	_picture.speed_scale = 1.0
	_picture.play("snap")  # the jaws shut
	_bite_clock = 0.2
	var rise := create_tween().set_parallel()  # and it shoots up out of its hiding place
	rise.tween_property(_picture, "scale:y", SIZE, 0.08)
	rise.tween_property(_picture, "modulate", Color.WHITE, 0.08)
	Sfx.play("jaw_snap", global_position)


func _bite() -> void:
	_bites += 1
	_bite_clock = BITE_GAP
	SpellTargets.hurt(_victim, BITE_DAMAGE, "Flora")
	Fx.burst(get_parent(), global_position + Vector2(0, -20), Color("#c04050"), 8, 90.0, 0.4)
	Sfx.play("chomp", global_position, -4.0)
	var chomp := create_tween()
	chomp.tween_property(_picture, "scale", Vector2(SIZE * 1.1, SIZE * 0.9), 0.08)
	chomp.tween_property(_picture, "scale", Vector2(SIZE, SIZE), 0.15)


## It has had its fill: it lets go and withers.
func _release() -> void:
	_victim = null
	_state = "withered"
	var wither := create_tween()
	wither.tween_property(_picture, "modulate:a", 0.0, 0.8)
	wither.tween_callback(queue_free)


func danger_at(point: Vector2) -> bool:
	return _state == "waiting" and absf(point.x - global_position.x) < REACH + 12.0 and absf(point.y - global_position.y) < 30.0

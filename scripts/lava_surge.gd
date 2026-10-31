class_name LavaSurge
extends Node2D

## A lake of lava in the ashlands does not lie still: on a rhythm it bubbles, then swells up in a wall of flame above its surface for a few
## seconds, and sinks back. The rhythm is made from the world's age, so every machine of a match sees the same swell. It burns whoever is
## in the flame. Its origin is the left end of the lake's surface.

const PERIOD := 13.0
const BUBBLING := 2.2  # seconds of bubbling before the swell
const SWELL := 2.6     # seconds the flame stands
const HEIGHT := 90.0   # how high the flame stands over the surface
const DAMAGE := 8
const TICK := 0.5

var width := 160.0
var phase := 0.0     # seconds this lake is behind the others, so they do not all swell together
var seconds := 0.0   # the world's age: the world sets it each frame

var _flames: Array[AnimatedSprite2D] = []
var _tick := 0.0
var _bubble := 0.0


func _ready() -> void:
	add_to_group("danger")
	add_to_group("fires")
	var count := maxi(1, int(width / 56.0))
	for k in count:
		var flame := PixelFx.sprite("fire_puff", 14.0, true, 1)
		flame.scale = Vector2(2.0, 2.0)
		flame.offset = Vector2(0, -PixelArt.FX["fire_puff"]["size"].y * 0.5)
		flame.position = Vector2((k + 0.5) * width / count, 4.0)
		flame.z_index = 1
		flame.visible = false
		add_child(flame)
		_flames.append(flame)


## How far through its rhythm the lake is, in seconds.
func _into() -> float:
	return fmod(seconds + phase, PERIOD)


## How high the flame stands now, from 0 to 1.
func rise() -> float:
	var into := _into() - BUBBLING
	if into < 0.0 or into > SWELL:
		return 0.0
	return clampf(minf(into, SWELL - into) / 0.6, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	var into := _into()
	var up := rise()
	for flame in _flames:
		flame.visible = up > 0.0
		flame.scale = Vector2(2.0, 2.0 * up)
	_bubble -= delta
	if into < BUBBLING and into > BUBBLING - 1.6 and _bubble <= 0.0:  # it bubbles before it swells
		_bubble = 0.2
		Fx.burst(get_parent(), global_position + Vector2(randf() * width, 0.0), Color(1.0, 0.5, 0.15), 4, 60.0, 0.5, true)
	_tick -= delta
	if up > 0.5 and _tick <= 0.0:
		_tick = TICK
		var zone := Rect2(global_position + Vector2(0.0, -HEIGHT * up), Vector2(width, HEIGHT * up + 10.0))
		for body: Node2D in SpellTargets.all(get_tree()):
			if zone.has_point(SpellTargets.center_of(body)) and not (body is Wizard and body.is_likeness()):
				SpellTargets.hurt(body, DAMAGE, "Fire", false, true)


## True over the lake while it bubbles up to a swell, and while the flame stands.
func danger_at(point: Vector2) -> bool:
	var into := _into()
	if into < BUBBLING - 1.0 or into > BUBBLING + SWELL:
		return false
	return point.x > global_position.x - 8.0 and point.x < global_position.x + width + 8.0 and point.y > global_position.y - HEIGHT - 8.0 and point.y < global_position.y + 20.0

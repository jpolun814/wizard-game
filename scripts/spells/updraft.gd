class_name Updraft
extends Node2D

## Updraft: a column of rising air that stands where it was drawn for the rest of the world. Anyone who walks into it is carried up, and
## the wind lets go of them at the top. Any number can be raised. Flyers are not troubled by it.

const WIDTH := 70.0
const HEIGHT := 520.0
const LIFT := 2700.0    # pixels a second, each second, the air adds to a body on its way up (gravity pulls back)
const MAX_RISE := 420.0 # the fastest it carries anyone up

const STREAKS := 7
var _streaks: Array[AnimatedSprite2D] = []  # gusts of the same pale wind as a Gust and a Push, climbing the column


func _ready() -> void:
	add_to_group("lasting")
	add_to_group("updrafts")
	global_position = SpellTargets.ground_below(get_world_2d(), global_position + Vector2(0.0, -30.0))
	z_index = 2
	for i in STREAKS:
		var gust := PixelFx.sprite("wind_bolt", 14.0)
		gust.scale = Vector2.ONE * 2.0
		gust.rotation = -PI * 0.5  # the wind stands on end
		gust.frame = i
		add_child(gust)
		_streaks.append(gust)
	Sfx.play("tornado", global_position, -14.0)
	Fx.smoke(get_parent(), global_position, Color(0.85, 0.9, 0.95, 0.5), 5, 24.0, 40.0)


func _physics_process(delta: float) -> void:
	for i in _streaks.size():
		var rise := fmod(Time.get_ticks_msec() * 0.00035 * HEIGHT + i * HEIGHT / STREAKS, HEIGHT)
		_streaks[i].position = Vector2(((i * 37) % int(WIDTH * 0.8)) - WIDTH * 0.4, -rise)
		_streaks[i].modulate = Color(SpellData.SCHOOL_COLORS["Air"], 0.8 * (1.0 - rise / HEIGHT))
	for body: Node2D in SpellTargets.all(get_tree()):
		if not _holds(body):
			continue
		if body.is_in_group("mobs") and body.KINDS[body.kind].role == "flyer":
			continue
		if body is Wizard and body.is_likeness():
			continue  # the machine that plays them lifts them
		body.velocity.y = maxf(body.velocity.y - LIFT * delta, -MAX_RISE)
		if body is Wizard:
			body.free_from_ground()


## True for a body standing in the column.
func _holds(body: Node2D) -> bool:
	var at := SpellTargets.center_of(body) - global_position
	return absf(at.x) <= WIDTH * 0.5 and at.y <= 30.0 and at.y >= -HEIGHT


func danger_at(_point: Vector2) -> bool:
	return false

class_name Updraft
extends Node2D

## Updraft: a column of rising air that stands where it was drawn for the rest of the world. Anyone who walks into it is carried up, and
## the wind lets go of them at the top. Any number can be raised. Flyers are not troubled by it.

const WIDTH := 70.0
const HEIGHT := 520.0
const LIFT := 2700.0    # pixels a second, each second, the air adds to a body on its way up (gravity pulls back)
const MAX_RISE := 420.0 # the fastest it carries anyone up

var _streaks: CPUParticles2D


func _ready() -> void:
	add_to_group("lasting")
	add_to_group("updrafts")
	global_position = SpellTargets.ground_below(get_world_2d(), global_position + Vector2(0.0, -30.0))
	z_index = 2
	_streaks = CPUParticles2D.new()
	_streaks.amount = 26
	_streaks.lifetime = 1.4
	_streaks.position = Vector2(0.0, -4.0)
	_streaks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_streaks.emission_rect_extents = Vector2(WIDTH * 0.45, 2.0)
	_streaks.direction = Vector2.UP
	_streaks.spread = 4.0
	_streaks.initial_velocity_min = 260.0
	_streaks.initial_velocity_max = 380.0
	_streaks.gravity = Vector2.ZERO
	_streaks.texture = load("res://art/particles/rain_streak.png")
	_streaks.particle_flag_align_y = true  # a streak points the way it travels, as the rain's do
	_streaks.scale_amount_min = 1.0
	_streaks.scale_amount_max = 1.6
	_streaks.color = Color(0.85, 0.93, 1.0, 0.55)
	_streaks.local_coords = false
	_streaks.preprocess = 1.4
	add_child(_streaks)
	Sfx.play("tornado", global_position, -14.0)
	Fx.smoke(get_parent(), global_position, Color(0.85, 0.9, 0.95, 0.5), 5, 24.0, 40.0)


func _physics_process(delta: float) -> void:
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

class_name SnowCloud
extends Node2D

## A cloud of the snowy peaks, drifting past on the wind. It passes in front of whoever is in it, so they cannot be seen until it has gone by. Snow
## falls from it, and where it falls on the ground, drifts of it settle and lie for a while (see SnowDrift).

const LAY_EVERY := 26.0   # pixels the cloud moves between one drift and the next
const NEAR := 1500.0      # a cloud farther than this from a wizard lays no snow: nobody is there to see it, and the ground is not made there yet

const PICTURES := [preload("res://art/props/cloud_snow_big.png"), preload("res://art/props/cloud_snow_small_1.png"), preload("res://art/props/cloud_snow_small_2.png")]

var drift := 30.0      # pixels a second, to the right
var left := 0.0        # where it comes back round to, at the world's edges
var right := 0.0
var _laid_at := 0.0
var _flakes: CPUParticles2D


func _ready() -> void:
	z_index = 5
	var sprite := Sprite2D.new()
	sprite.texture = PICTURES[int(absf(position.x)) % PICTURES.size()]
	sprite.scale = Vector2.ONE * (6.0 if sprite.texture == PICTURES[0] else 5.0)  # whole-number scales only
	sprite.modulate = Color(0.82, 0.88, 1.0, 0.93)
	add_child(sprite)
	var half := sprite.texture.get_width() * sprite.scale.x * 0.4
	_flakes = CPUParticles2D.new()  # snow falling out of the cloud, slanting with the wind
	_flakes.amount = 36
	_flakes.lifetime = 3.0
	_flakes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_flakes.emission_rect_extents = Vector2(half, 4.0)
	_flakes.position = Vector2(0.0, sprite.texture.get_height() * sprite.scale.y * 0.3)
	_flakes.direction = Vector2(0.25, 1.0)
	_flakes.spread = 12.0
	_flakes.initial_velocity_min = 50.0
	_flakes.initial_velocity_max = 90.0
	_flakes.gravity = Vector2(20.0, 60.0)
	_flakes.texture = Fx.tex("circle_05")
	_flakes.scale_amount_min = 2.0 / Fx.TEX_SIZE
	_flakes.scale_amount_max = 5.0 / Fx.TEX_SIZE
	_flakes.color = Color(0.95, 0.98, 1.0, 0.85)
	_flakes.z_index = -1
	add_child(_flakes)
	_laid_at = position.x


func _process(delta: float) -> void:
	position.x += drift * delta
	if absf(position.x - _laid_at) >= LAY_EVERY:
		_laid_at = position.x
		_lay_snow()
	if position.x > right:
		position.x = left


## Lets a drift of snow settle on the ground under the cloud, if there is ground to be seen there and the cloud is near a wizard.
func _lay_snow() -> void:
	if SnowDrift.count(get_tree()) >= SnowDrift.MOST:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or absf(player.global_position.x - global_position.x) > NEAR:
		return
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0.0, 1400.0))
	query.collision_mask = 1  # the ground
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or absf(hit["normal"].x) > 0.5:  # not on a steep slope, where snow would not lie
		return
	var drift := SnowDrift.new()
	drift.width = randf_range(36.0, 60.0)
	drift.height = randf_range(6.0, 11.0)
	drift.position = hit["position"]
	get_parent().add_child(drift)

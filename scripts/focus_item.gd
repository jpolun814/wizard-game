class_name FocusItem
extends Area2D

## A casting focus lying on the floor. The player holds one focus at a time.
## Tolerance is how exact a gesture has to be: looser focuses forgive sloppy strokes.

const FOCI := {
	"wand": {"name": "Wand", "tolerance": 0.70, "color": Color(0.6, 0.4, 0.2), "length": 26.0,
		"note": "Forgiving gestures. Good for learning."},
	"staff": {"name": "Staff", "tolerance": 0.90, "color": Color(0.35, 0.22, 0.1), "length": 40.0,
		"note": "Needs precise gestures."},
}

var focus_id := "wand"
var _velocity := Vector2.ZERO  # a focus that Push has shoved slides and falls until it lands


func setup(id: String, pos: Vector2) -> void:
	set_physics_process(false)
	focus_id = id
	position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 40)
	shape.shape = rect
	add_child(shape)
	add_to_group("items")
	var label := Label.new()
	label.text = FOCI[id]["name"]
	label.position = Vector2(-22, -48)
	add_child(label)
	queue_redraw()


func _draw() -> void:
	var data: Dictionary = FOCI[focus_id]
	var length: float = data["length"]
	draw_line(Vector2(0, length * 0.5), Vector2(0, -length * 0.5), data["color"], 4.0)
	draw_circle(Vector2(0, -length * 0.5), 3.0, Color(0.7, 0.9, 1.0))


## Push shoves a focus: it slides along the floor and drops onto whatever is below it.
func knock(impulse: Vector2) -> void:
	_velocity = impulse
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
	position += _velocity * delta
	var half_length: float = FOCI[focus_id]["length"] * 0.5
	var below := PhysicsRayQueryParameters2D.create(position, position + Vector2(0, 600))
	var hit := get_world_2d().direct_space_state.intersect_ray(below)
	if not hit.is_empty() and position.y + half_length >= hit["position"].y:
		position.y = hit["position"].y - half_length
		_velocity.y = 0.0
		_velocity.x = move_toward(_velocity.x, 0.0, 900.0 * delta)
		if _velocity.x == 0.0:
			set_physics_process(false)

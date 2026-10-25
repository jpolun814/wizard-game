class_name FocusItem
extends Area2D

## A casting focus lying on the floor. The player holds one focus at a time.
## Tolerance is how exact a gesture has to be: looser focuses forgive sloppy strokes.
## Its origin is the point on the ground it stands on; it hovers a little above it, glowing.

const WAND := preload("res://art/props/wand.png")
const STAFF := preload("res://art/props/staff.png")
## The focus the player carries from one map to the next.
static var held_focus := "wand"

const FOCI := {
	"wand": {"name": "Wand", "tolerance": 0.70, "color": Color(0.6, 0.4, 0.2), "length": 26.0,
		"note": "Use it to learn: gestures are forgiving."},
	"staff": {"name": "Staff", "tolerance": 0.90, "color": Color(0.35, 0.22, 0.1), "length": 40.0,
		"note": "Draw precisely to cast spells for a quarter less stamina."},
}
const HOVER := 8.0

var focus_id := "wand"
var _velocity := Vector2.ZERO  # a focus that Push has shoved slides and falls until it lands
var _t := 0.0


func setup(id: String, pos: Vector2) -> void:
	set_physics_process(false)
	focus_id = id
	position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 40)
	shape.shape = rect
	shape.position = Vector2(0, -20)
	add_child(shape)
	add_to_group("items")
	var label := Label.new()
	label.text = FOCI[id]["name"]
	label.add_theme_font_override("font", FloatText.font())
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.12))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(120, 30)
	label.scale = Vector2.ONE * 0.5
	label.position = Vector2(-30, -FOCI[id]["length"] - HOVER - 24.0)
	add_child(label)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## A shadow on the ground, a soft glow, and the focus itself, a pixel-art wand or staff, floating upright.
func _draw() -> void:
	var lift := roundf(HOVER + sin(_t * 2.5) * 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var texture: Texture2D = WAND if focus_id == "wand" else STAFF
	var size := texture.get_size() * 2.0
	Fx.draw_glow(self, Vector2(0, -lift - size.y + 4.0), 14.0 + sin(_t * 4.0) * 2.0, Color(0.6, 0.85, 1.0, 0.6))
	draw_texture_rect(texture, Rect2(Vector2(-size.x * 0.5, -lift - size.y), size), false)


## Push shoves a focus: it slides along the floor and drops onto whatever is below it.
func knock(impulse: Vector2) -> void:
	_velocity = impulse
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
	var before := position
	position += _velocity * delta
	var query := PhysicsRayQueryParameters2D.create(before + Vector2(0, -4), position + Vector2(0, 1))
	query.collision_mask = 1 | 16
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and _velocity.y >= 0.0:
		position.y = hit["position"].y
		_velocity.y = 0.0
		_velocity.x = move_toward(_velocity.x, 0.0, 900.0 * delta)
		if _velocity.x == 0.0:
			set_physics_process(false)
	position.x = clampf(position.x, ArenaGen.left_edge() + 10.0, ArenaGen.right_edge() - 10.0)

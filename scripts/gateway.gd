class_name Gateway
extends Portal

## One end of a pair of portals opened by the Incantation of the Return. Anyone who steps into one comes out of the other.
## They stay open for good, each pair in a colour of its own.

const COOLDOWN := 1.0  # seconds before whoever came out may go in again, so nobody bounces back and forth

var partner: Gateway
var tint := Color.WHITE
var _recent := {}  # body -> seconds left before it may go in again


func _ready() -> void:
	super()
	collision_mask = 6  # the player and the foes
	_ring.modulate = Color(tint.r, tint.g, tint.b) * 1.5
	body_entered.connect(_on_body_entered)
	add_to_group("gateways")


func _process(delta: float) -> void:
	super(delta)
	for body in _recent.keys():
		_recent[body] -= delta
		if _recent[body] <= 0.0 or not is_instance_valid(body):
			_recent.erase(body)


func _on_body_entered(body: Node2D) -> void:
	if partner == null or not is_instance_valid(partner) or _recent.has(body):
		return
	partner._recent[body] = COOLDOWN  # it comes out of the other end, which must not send it straight back
	_recent[body] = COOLDOWN
	body.global_position = partner.global_position + Vector2(0.0, RY)
	if body.has_method("reset_physics_interpolation"):
		body.reset_physics_interpolation()
	if body.get("velocity") != null:
		body.velocity = Vector2.ZERO
	Sfx.play("portal_open", global_position, -6.0)
	Sfx.play("portal_open", partner.global_position, -6.0)

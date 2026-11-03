class_name ArrivalPortal
extends Node2D

## The portal a wizard comes into the first world by: it tears open in the air over where the wizard will stand, the wizard drops out of it, and it
## shuts behind them. It lives only a moment.

const GROW := 0.35   # seconds to open
const STAY := 1.1    # seconds it stays open
const SHRINK := 0.4  # seconds to close

var _portal: Portal


func _ready() -> void:
	_portal = Portal.new()
	_portal.scale = Vector2.ONE * 0.2
	_portal.z_index = 5  # over the sky and anything in it
	_portal.rotation = PI * 0.5  # lying flat in the air, so the wizard falls out of its underside
	_portal.collision_mask = 0  # nobody walks into this one
	add_child(_portal)
	_portal.open()
	Sfx.play("portal_open", global_position, -8.0)
	var tween := create_tween()
	tween.tween_property(_portal, "scale", Vector2.ONE * 1.5, GROW).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(STAY)
	tween.tween_property(_portal, "scale", Vector2.ONE * 0.1, SHRINK)
	tween.tween_callback(queue_free)

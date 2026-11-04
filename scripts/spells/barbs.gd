class_name Barbs
extends SpellEffect

## Barbs: a volley of thorns flung along the drawn line, fanned out a little. This only throws them: each Thorn is a shot of its own.

const COUNT := 5
const FAN := 0.5  # the angle the volley spreads across, in radians


func _begin(origin: Vector2, aim_angle: float) -> void:
	_life = 0.05
	Sfx.play("push", origin, -6.0)
	for k in COUNT:
		var thorn := Thorn.new()
		thorn.caster = caster
		get_parent().add_child(thorn)
		var spread := (float(k) / (COUNT - 1) - 0.5) * FAN
		thorn.setup("Barbs", origin + Vector2.from_angle(aim_angle) * 10.0, aim_angle + spread)

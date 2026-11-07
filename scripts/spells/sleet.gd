class_name Sleet
extends SpellEffect

## Sleet: a spray of ice shards flung along the drawn line, fanned wide. This only throws them: each shard is a shot of its own.

const COUNT := 7
const FAN := 0.9  # the angle the spray spreads across, in radians


func _begin(origin: Vector2, aim_angle: float) -> void:
	_life = 0.05
	Sfx.play("cast_ice", origin, -4.0)
	for k in COUNT:
		var shard := SleetShard.new()
		shard.caster = caster
		get_parent().add_child(shard)
		var spread := (float(k) / (COUNT - 1) - 0.5) * FAN
		shard.setup("Sleet", origin + Vector2.from_angle(aim_angle) * 10.0, aim_angle + spread)

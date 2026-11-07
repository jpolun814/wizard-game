extends Node

## Pictures of the eight attacking spells (Wind Cutter, Shadow Bolt, Sandblast, Sleet, Meteor, Strangler Vine, Hemorrhage, Steam Burst), each cast at a dummy in the
## waiting room, to judge how they look.
##
##     godot --path . tests/attacks_look.tscn -- out=DIR     (needs a window)

var out_dir := "user://attacks_look"
var _lab: Node
var _player: Wizard
var _feet := Vector2.ZERO


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out_dir = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_lab = load("res://scenes/lab.tscn").instantiate()
	add_child(_lab)
	for k in 40:
		await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	_feet = _player.global_position
	_player.facing = 1.0
	var dummy: Mob = _lab._add_mob("dummy", _feet + Vector2(220.0, 0.0))
	dummy.max_hp = 5000
	dummy.hp = 5000
	await get_tree().create_timer(1.8).timeout
	var from := _player.center()
	_cast("Wind Cutter", "directional", from, 0.0, {})
	await _shots("wind_cutter", [0.12, 0.2])
	_cast("Shadow Bolt", "directional", from, 0.0, {})
	await _shots("shadow_bolt", [0.4, 0.8])
	_cast("Sandblast", "cone", from, 0.0, {"aim": 0.0, "spread": 0.7, "reach": 220.0})
	await _shots("sandblast", [0.15, 0.3])
	_cast("Sleet", "positional", from, 0.0, {})
	await _shots("sleet", [0.1, 0.25])
	_cast("Meteor", "positional", _feet + Vector2(220.0, -40.0), 0.0, {})
	await _shots("meteor", [0.6, 1.5, 1.8])
	_cast("Strangler Vine", "positional", _feet + Vector2(220.0, -10.0), 0.0, {})
	await _shots("vine", [0.3, 1.2])
	_cast("Hemorrhage", "positional", dummy.center(), 0.0, {})
	await _shots("hemorrhage", [1.2, 2.2])
	_cast("Steam Burst", "positional", _feet + Vector2(220.0, -10.0), 0.0, {})
	await _shots("steam", [0.5, 1.5])
	get_tree().quit()


func _cast(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary) -> void:
	var data := {"length": 90.0, "accuracy": 0.9}
	data.merge(info)
	_lab.spawn_spell(spell, targeting, origin, aim, data, _player)


## Pictures at these times, in seconds, after the cast; then a pause for it to finish.
func _shots(name: String, times: Array) -> void:
	var last := 0.0
	for t: float in times:
		await get_tree().create_timer(t - last).timeout
		last = t
		get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [out_dir, name, int(t * 100.0)])
	await get_tree().create_timer(2.0).timeout

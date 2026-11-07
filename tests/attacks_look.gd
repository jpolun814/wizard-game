extends Node

## Pictures of the attacking spells (Shadow Bolt, Hemorrhage), each cast at a dummy in the
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
	_cast("Shadow Bolt", "directional", from, 0.0, {})
	await _shots("shadow_bolt", [0.4, 0.8])
	_cast("Hemorrhage", "positional", dummy.center(), 0.0, {})
	await _shots("hemorrhage", [1.2, 2.2])
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

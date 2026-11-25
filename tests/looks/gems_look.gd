extends Node

## Where the gem of each weapon is found, marked on a picture of the wizard in the pose a spell is cast from. `-- out=DIR` (needs a window).

const WEAPONS := ["wand", "bone_wand", "rose_wand", "scepter", "staff_orb", "staff_crystal", "staff_flower", "staff_lantern", "staff_moon", "staff_skull", "staff_branch", "crook", "book", "orb_hand", "classic_wand", "cane", "athame", "rapier", "scythe", "ankh", "tarot_fan", "skull_hand", "broom", "trident", "lightsaber"]


class Mark:
	extends Node2D
	var wizard: Wizard

	func _draw() -> void:
		var at := to_local(wizard.launch_tip())
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 2)), Color(1, 0, 0))


func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	var lab: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 30:
		await get_tree().process_frame
	var player: Wizard = lab.player
	player.facing = 1.0
	var mark := Mark.new()
	mark.wizard = player
	mark.z_index = 100
	player.add_child(mark)
	DirAccess.make_dir_recursive_absolute(out)
	for weapon in WEAPONS:
		player.look = PartsLook.with_option(player.look, "weapon", weapon)
		player.dress()
		for k in 6:
			await get_tree().process_frame
		var tip := player.launch_tip()
		print(weapon, " launch_tip offset from feet: ", tip - player.global_position)
		player.set_process(false)
		player.set_physics_process(false)
		var body: AnimatedSprite2D = player.get("_sprite")
		body.animation = "release"
		body.frame = 1
		body.pause()
		player._magic.mirror(body)
		mark.queue_redraw()
		await get_tree().process_frame
		var shot := get_viewport().get_texture().get_image()
		var at := get_viewport().get_canvas_transform() * tip
		shot.get_region(Rect2i(Vector2i(at) - Vector2i(50, 40), Vector2i(100, 80)).intersection(Rect2i(Vector2i.ZERO, shot.get_size()))).save_png(out + "/gem_%s.png" % weapon)
		player.set_process(true)
		player.set_physics_process(true)
	get_tree().quit()

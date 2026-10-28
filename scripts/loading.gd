class_name Loading
extends Control

## Shown while the world builds, which takes a few seconds and stops the window drawing: the screen is drawn first, then the world is
## loaded, so the wait shows the seed's incantation on a dark page and not a blank window.

const WORLD := "res://scenes/world.tscn"


func _ready() -> void:
	var words: Label = $Box/Words
	words.text = Incantation.words_for(World.next_seed) if World.next_seed >= 0 else ""
	await get_tree().process_frame  # two frames, so the screen is on the display before the world blocks it
	await get_tree().process_frame
	get_tree().change_scene_to_file(WORLD)

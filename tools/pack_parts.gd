extends SceneTree

## Packs the character creator's part sheets (art_source/parts_sheets, 203 big PNGs, one per variant of each slot) into the files the game reads
## (art/parts/<slot>/<variant>.parts). Run: godot --headless --path . -s tools/pack_parts.gd [-- slot slot ...]
##
## Why not use the sheets as they are: every sheet is 2286 x 3726 and nearly all empty, 34 MB of memory to draw one person's one layer, and
## a custom wizard is sixteen of them. A packed file holds each animation of one sheet as its own compressed strip, so the game unpacks only
## the animations a wizard plays (a few thousandths of a second each) and keeps nothing else. The layout of a file:
##   u32 animation count, then for each animation (in the order of manifest.json) u32 offset, u32 packed size, u32 raw size, and the box of the strip
##   that is not empty as four u16 (x, y, width, height), then the packed strips. A strip is count frames of 254 x 138, side by side, RGBA8, packed with
##   Zstandard. A raw size of 0 is an empty strip. (The game lays down only the box, which is a quarter of the picture or less.)

const SOURCE := "res://art_source/parts_sheets/"
const OUT := "res://art/parts/"


func _init() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE + "manifest.json"))
	var only := PackedStringArray()
	var args := OS.get_cmdline_user_args()
	for arg in args:
		only.append(arg)
	var width: int = manifest["frame_size"][0]
	var height: int = manifest["frame_size"][1]
	var columns: int = manifest["columns"]
	var animations: Dictionary = manifest["animations"]
	var total_raw := 0
	var total_packed := 0
	var files := 0
	for slot: Dictionary in manifest["slots"]:
		if not only.is_empty() and not only.has(slot["name"]):
			continue
		DirAccess.make_dir_recursive_absolute(OUT + slot["name"])
		for variant: String in slot["variants"]:
			var sheet := Image.load_from_file(SOURCE + slot["name"] + "/" + variant + ".png")
			sheet.convert(Image.FORMAT_RGBA8)
			var blobs: Array[PackedByteArray] = []
			var raws: Array[int] = []
			var boxes: Array[Rect2i] = []
			for anim: String in animations:
				var spec: Dictionary = animations[anim]
				var count: int = spec["count"]
				var strip := Image.create(width * count, height, false, Image.FORMAT_RGBA8)
				for k in count:
					var frame: int = int(spec["start"]) + k
					strip.blit_rect(sheet, Rect2i((frame % columns) * width, (frame / columns) * height, width, height), Vector2i(k * width, 0))
				if strip.is_invisible():
					blobs.append(PackedByteArray())
					raws.append(0)
					boxes.append(Rect2i())
				else:
					var raw := strip.get_data()
					blobs.append(raw.compress(FileAccess.COMPRESSION_ZSTD))
					raws.append(raw.size())
					boxes.append(strip.get_used_rect())
			var file := FileAccess.open(OUT + slot["name"] + "/" + variant + ".parts", FileAccess.WRITE)
			file.store_32(blobs.size())
			var offset := 4 + blobs.size() * 20
			for k in blobs.size():
				file.store_32(offset)
				file.store_32(blobs[k].size())
				file.store_32(raws[k])
				file.store_16(boxes[k].position.x)
				file.store_16(boxes[k].position.y)
				file.store_16(boxes[k].size.x)
				file.store_16(boxes[k].size.y)
				offset += blobs[k].size()
				total_raw += raws[k]
				total_packed += blobs[k].size()
			for blob in blobs:
				file.store_buffer(blob)
			file.close()
			files += 1
		print("packed ", slot["name"])
	print("%d files, %.1f MB raw -> %.1f MB packed" % [files, total_raw / 1048576.0, total_packed / 1048576.0])
	quit()

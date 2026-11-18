class_name PartFrames
extends RefCounted

## Builds a custom wizard's animations by stacking the layers in res://art/parts (see manifest.json there, and tools/pack_parts.gd for the files).
## Everyone wearing the same look shares one set of frames. An animation is stacked the first time it is played (a few thousandths of a second:
## each layer's strip of it is unpacked, laid over the ones before it and put away), so a wizard holds in memory only the animations it has
## really played. The core ones are made when the wizard is dressed, so that the match does not pay for them in the middle of a fight.

const DIR := "res://art/parts/"
const CORE := ["idle", "run", "cast", "release", "hit", "death", "jump", "fall"]  # the eight every wizard plays
## Where a frame is drawn from the wizard's feet: its middle is half a frame up, less the one row under the boots that the art leaves empty (the first wizard's boots
## were on the bottom row, these are on the one above), so the boots stand on the ground and not over it.
const OFFSET := Vector2(0.0, -68.0)
const LITE := ["idle", "run", "release", "hit", "death"]  # what a cut-scene plays
const FAMILIAR := ["walk", "knockback", "climb", "climb_hang", "swim", "frozen"]  # nearly every match plays these too: made with the core, while loading

static var _manifest: Dictionary
static var _bodies := {}    # look -> a WeakRef to its SpriteFrames: they are kept for as long as a wizard (or a picture) wears them, and no longer
static var _magics := {}    # weapon -> a WeakRef to the SpriteFrames of its magic layer
static var _indexes := {}   # path of a packed file -> [[offset, packed size, raw size, box] per animation]
static var _last_ms := 0.0  # how long the last animation took to make, for the tests


static func manifest() -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(DIR + "manifest.json"))
	return _manifest


## The packed file for a slot under a choice of parts, or "" where that choice draws nothing in the slot.
static func layer_path(slot: Dictionary, config: Dictionary) -> String:
	var name: String = slot["name"]
	var values := PackedStringArray()
	for option: String in slot["depends_on"]:
		values.append(config[option])
	var key := "-".join(values)
	key = (slot.get("alias", {}) as Dictionary).get(key, key)  # choices that draw the same picture share a file
	if not (slot["variants"] as Array).has(key):
		return ""
	return DIR + name + "/" + key + ".parts"


## The animations of a look, with the common ones made and the rest made when asked for (see ensure). `lite` makes only the few a cut-scene plays (a picture
## of a wizard that is never in a match need not pay for the rest); a later call for the same look makes the rest.
static func body(look: String, lite := false) -> SpriteFrames:
	var frames := _kept(_bodies, look)
	if frames == null:
		frames = _empty()
		frames.set_meta("look", look)
		_bodies[look] = weakref(frames)
	for anim: String in LITE if lite else CORE + FAMILIAR:
		ensure(frames, anim)
	return frames


## The magic layer of a weapon: the gem, its glow and every effect, in key grays (see magic_ramp.gdshader).
static func magic(weapon: String) -> SpriteFrames:
	var frames := _kept(_magics, weapon)
	if frames == null:
		frames = _empty()
		frames.set_meta("weapon", weapon)
		_magics[weapon] = weakref(frames)
	for anim: String in CORE + FAMILIAR:
		ensure(frames, anim)
	return frames


## The frames in a cache that someone still holds, or null.
static func _kept(cache: Dictionary, key: String) -> SpriteFrames:
	var ref: WeakRef = cache.get(key)
	return ref.get_ref() as SpriteFrames if ref != null else null


## Makes an animation of a set of frames from body() or magic() if it is not there yet. True when the animation exists after this.
static func ensure(frames: SpriteFrames, anim: String) -> bool:
	if frames.has_animation(anim):
		return true
	if not (frames.has_meta("look") or frames.has_meta("weapon")):
		return false  # frames of an older figure: they have what they have
	var spec: Dictionary = manifest()["animations"].get(anim, {})
	if spec.is_empty():
		return false
	var started := Time.get_ticks_usec()
	var width: int = manifest()["frame_size"][0]
	var height: int = manifest()["frame_size"][1]
	var count: int = spec["count"]
	var strip := Image.create(width * count, height, false, Image.FORMAT_RGBA8)
	for path: String in _layers(frames):
		var layer := _unpack(path, anim, width * count, height)
		if layer != null:
			strip.blend_rect(layer, layer.get_meta("box"), layer.get_meta("box").position)
	var texture := ImageTexture.create_from_image(strip)
	frames.add_animation(anim)
	frames.set_animation_speed(anim, spec["fps"])
	frames.set_animation_loop(anim, spec["loop"])
	for k in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(k * width, 0, width, height)
		frames.add_frame(anim, atlas)
	_last_ms = (Time.get_ticks_usec() - started) / 1000.0
	return true


## Makes the next animation a set of frames does not have yet, if any: called a few times a second for the wizard the person plays, so that nothing it ever plays is made in the
## middle of a fight. True while there is more to make.
static func warm_next(frames: SpriteFrames) -> bool:
	for anim: String in manifest()["animations"]:
		if not frames.has_animation(anim):
			ensure(frames, anim)
			return true
	return false


static func _empty() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	return frames


## The packed files to lay over each other for a set of frames, back to front.
static func _layers(frames: SpriteFrames) -> PackedStringArray:
	var paths := PackedStringArray()
	if frames.has_meta("weapon"):
		paths.append(DIR + "magic/" + str(frames.get_meta("weapon")) + ".parts")
		return paths
	var config := PartsLook.decode(str(frames.get_meta("look")))
	for slot: Dictionary in manifest()["slots"]:
		if slot["name"] == manifest()["magic"]["slot"]:
			continue
		var path := layer_path(slot, config)
		if path != "":
			paths.append(path)
	return paths


## One layer's strip of one animation, or null where the layer draws nothing in it.
static func _unpack(path: String, anim: String, width: int, height: int) -> Image:
	var number := (manifest()["animations"] as Dictionary).keys().find(anim)
	if not _indexes.has(path):
		var head := FileAccess.open(path, FileAccess.READ)
		if head == null:
			push_error("PartFrames: no file " + path)
			return null
		var rows: Array = []
		for k in head.get_32():
			var row := [head.get_32(), head.get_32(), head.get_32()]
			row.append(Rect2i(head.get_16(), head.get_16(), head.get_16(), head.get_16()))
			rows.append(row)
		_indexes[path] = rows
	var row: Array = _indexes[path][number]
	if int(row[2]) == 0:
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	file.seek(row[0])
	var raw := file.get_buffer(row[1]).decompress(row[2], FileAccess.COMPRESSION_ZSTD)
	var image := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, raw)
	image.set_meta("box", row[3])
	return image


## The ramp of four colors that turns the magic layer's key grays into a color: nearly white at the heart of a glow, down to a deep shade at its edge.
## (The one formula the art was made with: see docs/handoff/19_character_creator.md.)
static func ramp(color: Color) -> Array[Color]:
	return [color.lerp(Color.WHITE, 0.75), color.lerp(Color.WHITE, 0.35), color, Color(color.r * 0.5, color.g * 0.5, color.b * 0.5)]

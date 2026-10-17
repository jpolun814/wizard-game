class_name CharFrames

## Builds a character's animations from its frames in art/chars or art/mobs (cut by tools/prepare_gothic_art.py,
## named <animation>_<n>.png). Built once per character and shared by everyone using it.

static var _cache := {}


## animations: name -> {"from": the frames' file prefix (defaults to the name), "fps", "loop", and optionally
## "first" and "last", to use only some of the frames}.
static func build(dir: String, animations: Dictionary) -> SpriteFrames:
	if _cache.has(dir):
		return _cache[dir]
	var files := Array(ResourceLoader.list_directory(dir))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim_name in animations:
		var spec: Dictionary = animations[anim_name]
		var prefix: String = spec.get("from", anim_name) + "_"
		var count := 0
		while files.has(prefix + str(count) + ".png"):
			count += 1
		if count == 0:
			continue
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, spec.get("fps", 10.0))
		frames.set_animation_loop(anim_name, spec.get("loop", true))
		for i in range(spec.get("first", 0), mini(spec.get("last", count - 1), count - 1) + 1):
			frames.add_frame(anim_name, load(dir + "/" + prefix + str(i) + ".png"))
	_cache[dir] = frames
	return frames

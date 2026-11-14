extends SceneTree

## Measures how far each spell's stroke can be dragged before it stops being read as that spell.
##
## A stroke is recorded in the world, and the camera follows the wizard, so a person who walks, jumps or falls while drawing
## has their stroke smeared along the way they went, though their hand drew the shape cleanly on the screen. This draws
## every spell's picture at an even pace while the view slides a given distance (left, right, up or down), and finds the
## largest slide each spell survives. The answer is a distance in world pixels over the whole stroke, so it holds for any
## drawing speed: a walk of 300 px/s during a 0.8 s stroke is a slide of 240 px.
##
## Run from the project folder:
##     godot --headless -s tests/measure_drift.gd [-- out=data/ai/stroke_drift.json]
## It prints one line a spell and writes the table as JSON for the brains to read.

const GROUND_Y := 0.0
const STEP := 4.0       # how finely the slide is searched, in px
const LIMIT := 480.0    # no spell needs to survive more than this; a stroke that does is marked with it
const DIRECTIONS := {"right": Vector2(1, 0), "left": Vector2(-1, 0), "up": Vector2(0, -1), "down": Vector2(0, 1)}

var _caster: Caster
var _cast := ""


func _initialize() -> void:
	_caster = Caster.new()
	root.add_child(_caster)
	_caster.set_process(false)
	_caster.ground_check = func(p: Vector2) -> bool: return p.y >= GROUND_Y - 16.0 and p.y <= GROUND_Y + 32.0
	_caster.anchor = Vector2(-400, -40)
	_caster.cast_resolved.connect(func(spell: String, _t: String, _o: Vector2, _a: float, _i: Dictionary) -> void: _cast = spell)


func _process(_delta: float) -> bool:
	var out_path := "res://data/ai/stroke_drift.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out_path = arg.substr(4)
	var table := {}
	var names: Array = SpellData.SPELLS.keys()
	names.sort()
	for spell_name: String in names:
		var s: Spell = SpellData.SPELLS[spell_name]
		var shape := _densify(GestureTemplates.preview_points(s.gesture))
		var row := {"size": GestureTemplates.bounds(shape).size.length()}
		if not _reads(spell_name, s, shape, Vector2.ZERO):
			row["clean"] = false  # the picture itself is not read here (it needs a world: a ceiling, water); no figure for it
			table[spell_name] = row
			print("%-16s  (not read without a world)" % spell_name)
			continue
		var line := "%-16s" % spell_name
		for dir_name: String in DIRECTIONS:
			var slide := 0.0
			while slide + STEP <= LIMIT and _reads(spell_name, s, shape, DIRECTIONS[dir_name] * (slide + STEP)):
				slide += STEP
			row[dir_name] = slide
			line += "  %s %3.0f" % [dir_name, slide]
		table[spell_name] = row
		print(line)
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(table, "\t", false))
	print("wrote ", out_path)
	quit(0)
	return true


## True when the stroke, dragged this far in all by the time it ends, is still read as the spell.
func _reads(spell_name: String, s: Spell, shape: PackedVector2Array, slide: Vector2) -> bool:
	var offset := Vector2(0, -260)
	if s.gesture == "stone_wall":
		offset = Vector2(0, GROUND_Y - shape[0].y - 4.0)
	var length := 0.0
	for i in range(1, shape.size()):
		length += shape[i].distance_to(shape[i - 1])
	var world := PackedVector2Array()
	var walked := 0.0
	for i in shape.size():
		if i > 0:
			walked += shape[i].distance_to(shape[i - 1])
		var t := walked / maxf(length, 1.0)  # the hand moves at an even pace, so the view has slid this share of the way
		world.append(shape[i] + offset + slide * t)
	_cast = ""
	_caster.cast_stroke(s.buttons, world)
	return _cast == spell_name


func _densify(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size() - 1:
		var steps := maxi(1, int(points[i].distance_to(points[i + 1]) / 2.0))
		for k in steps:
			out.append(points[i].lerp(points[i + 1], float(k) / steps))
	out.append(points[points.size() - 1])
	return out

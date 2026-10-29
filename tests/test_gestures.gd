extends SceneTree

## Checks that every spell's gesture is recognised as that spell. Each spell's spellbook picture is drawn through
## the real caster, at several sizes and with a shaky hand, and must come out as the right spell. The dark wizard
## draws its spells from the same pictures, so this also checks that it can cast everything it tries to.
##
## Run from the project folder:
##     godot --headless -s tests/test_gestures.gd
## It prints each failure and exits with code 1 if anything failed.

const GROUND_Y := 0.0  # in this test the ground is the line y = 0; everything below it is solid
## The gestures that mean the same drawn backwards or mirrored.
const MIRRORED := ["circle", "flick", "pit", "icicles", "spiral", "cone", "smoke", "flare", "wave", "geyser",
	"vine", "tsunami", "tornado", "bramble", "jaws", "pads", "tree", "eight", "crescent", "pentagram"]

var _caster: Caster
var _cast := ""
var _failures := 0
var _checks := 0
var _aim := 0.0


func _initialize() -> void:
	_caster = Caster.new()
	root.add_child(_caster)
	_caster.set_process(false)
	_caster.ground_check = func(p: Vector2) -> bool: return p.y >= GROUND_Y - 16.0 and p.y <= GROUND_Y + 32.0
	_caster.anchor = Vector2(-400, -40)
	_caster.cast_resolved.connect(func(spell: String, _t: String, _o: Vector2, a: float, _i: Dictionary) -> void:
		_cast = spell
		_aim = a)


## The caster is ready (its templates loaded) from the first frame, so the checks run then.
func _process(_delta: float) -> bool:
	for spell_name in SpellData.SPELLS:
		var s: Spell = SpellData.SPELLS[spell_name]
		var shape := GestureTemplates.preview_points(s.preview if s.preview != "" else s.gesture)
		for size in [0.7, 1.0, 1.6]:
			for shaky in [false, true]:
				_check(spell_name, s.buttons, shape, size, shaky, false)
		# Directions that should not matter: a circle drawn the other way, a flick to the left.
		if s.gesture in MIRRORED:
			_check(spell_name, s.buttons, shape, 1.0, false, true)
		# Real hands tilt and squash what they draw: every shape must survive a tilt and a stretch, with a shaky hand.
		for tilt in [-10.0, 10.0]:
			for stretch in [Vector2(0.88, 1.14), Vector2(1.14, 0.88)]:
				var warp := Transform2D(deg_to_rad(tilt), Vector2.ONE).scaled_local(stretch)
				_check(spell_name, s.buttons, shape, 1.0, true, false, warp)
	# A single V is an icicle too: the ceiling check is what limits where it can be cast.
	var single_v := PackedVector2Array([Vector2(-30, -40), Vector2(0, 30), Vector2(30, -40)])
	for size in [0.7, 1.0, 1.6]:
		for shaky in [false, true]:
			_check("Icicles", SpellData.SPELLS["Icicles"].buttons, single_v, size, shaky, false)
	# A Bramble row need not have five teeth: two, three or four are thorns too.
	for teeth in [2, 3, 4]:
		for size in [0.8, 1.0, 1.5]:
			_checks += 1
			var row := PackedVector2Array()
			for p in GestureTemplates.sawtooth(teeth, 55.0, 24.0):
				row.append(p * size + Vector2(0, -260))
			_cast = ""
			_caster.cast_stroke(SpellData.LEFT | SpellData.MIDDLE, _densify(row))
			if _cast != "Bramble":
				_failures += 1
				print("FAIL Bramble with %d teeth at %.1f: cast %s" % [teeth, size, _cast])
	# A Fire Breath cone can point any way, and the fire must go toward its open end.
	for angle in [0.0, PI * 0.5, PI, -PI * 0.5, PI * 0.25]:
		_checks += 1
		var cone := PackedVector2Array()
		for p in GestureTemplates.preview_points("cone"):
			cone.append(p.rotated(angle) + Vector2(0, -260))
		_cast = ""
		_caster.cast_stroke(SpellData.LEFT, _densify(cone))
		if _cast != "Fire Breath" or absf(angle_difference(_aim, angle)) > 0.2:
			_failures += 1
			print("FAIL Fire Breath pointing %.2f: cast %s aimed %.2f" % [angle, _cast, _aim])
	print("%d of %d gesture checks passed" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)
	return true


## Draws one gesture and checks what it casts. mirror flips it left to right.
func _check(spell_name: String, buttons: int, shape: PackedVector2Array, size: float, shaky: bool, mirror: bool, warp := Transform2D.IDENTITY) -> void:
	_checks += 1
	var gesture: String = SpellData.SPELLS[spell_name].gesture
	var points := PackedVector2Array()
	for p in shape:
		points.append(warp * (Vector2(-p.x if mirror else p.x, p.y) * size))
	points = _densify(points)
	# Strokes that must start on the ground are placed there; everything else is drawn in the air.
	var offset := Vector2(0, -260)
	if gesture == "stone_wall":
		offset = Vector2(0, GROUND_Y - points[0].y - 4.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(spell_name) + int(size * 10.0)
	var world := PackedVector2Array()
	# A shaky hand drifts slowly off the line and back, with a little pixel noise on top.
	var phase := rng.randf() * TAU
	for i in points.size():
		var wobble := Vector2.ZERO
		if shaky:
			var t := float(i) * 0.05 + phase
			wobble = Vector2(sin(t * 1.3) * 4.0, cos(t * 1.7) * 4.0) + Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.7, 0.7))
		world.append(points[i] + offset + wobble)
	_cast = ""
	_caster.cast_stroke(buttons, world)
	if _cast != spell_name:
		_failures += 1
		print("FAIL %s (size %.1f%s%s%s): cast %s" % [spell_name, size, ", shaky" if shaky else "", ", mirrored" if mirror else "", ", warped %s" % warp if warp != Transform2D.IDENTITY else "", _cast if _cast != "" else "nothing"])


## The stroke with points every two pixels, as dense as one drawn with the mouse.
func _densify(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size() - 1:
		var steps := maxi(1, int(points[i].distance_to(points[i + 1]) / 2.0))
		for k in steps:
			out.append(points[i].lerp(points[i + 1], float(k) / steps))
	out.append(points[points.size() - 1])
	return out

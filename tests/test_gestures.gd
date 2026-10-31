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
	"vine", "tsunami", "tornado", "bramble", "jaws", "pads", "tree", "eight", "crescent", "pentagram", "lungs", "silence", "question", "arrow", "earthquake"]

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
	# Lungs (an infinity sign) can be started at an edge or a little way round, either loop first, and turned half way round: all are a Vacuum.
	for template_name: String in GestureTemplates.recognizer_templates():
		if template_name.begins_with("lungs_"):
			for size in [0.8, 1.2]:
				for warp in [Transform2D.IDENTITY, Transform2D(Vector2(1, 0), Vector2(0, -1), Vector2.ZERO), Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2.ZERO)]:
					_check("Vacuum", SpellData.SPELLS["Vacuum"].buttons, GestureTemplates.recognizer_templates()[template_name], size, true, false, warp)
	# Silence (a ring with a slash through it) and Black Hole (a spiral wound inward) share a button pair and both wind round: whichever way round,
	# wherever started and however long the slash, each must come out as itself.
	for start in [-135.0, -90.0, -45.0, 0.0, 90.0, 180.0]:
		for direction in [1.0, -1.0]:
			for slash in [70.0, 100.0, 130.0]:
				var sign_stroke := PackedVector2Array()
				for i in 33:
					sign_stroke.append(Vector2.from_angle(deg_to_rad(start) + direction * TAU * i / 32.0) * 45.0)
				var inward := -sign_stroke[sign_stroke.size() - 1].normalized()
				for i in range(1, 9):
					sign_stroke.append(sign_stroke[32] + inward * slash * i / 8.0)
				_check("Silence", SpellData.SPELLS["Silence"].buttons, sign_stroke, 1.0, false, false)
	for turns in [2.0, 2.5, 3.0]:
		for start in [-90.0, 0.0, 90.0, 180.0]:
			for direction in [1.0, -1.0]:
				var winding := PackedVector2Array()
				var steps := int(turns * 32.0)
				for i in steps + 1:
					var t := float(i) / steps
					winding.append(Vector2.from_angle(deg_to_rad(start) + direction * t * turns * TAU) * 60.0 * (1.0 - t * 0.8))
				_check("Black Hole", SpellData.SPELLS["Black Hole"].buttons, winding, 1.0, false, false)
	# Strokes that wind but are not a spiral wound in twice must not be a Black Hole: a ring, a loop and a half, two rings of one size, and a ring
	# with a line to its middle.
	var not_spirals := {}
	var ring := PackedVector2Array()
	for i in 33:
		ring.append(Vector2.from_angle(TAU * i / 32.0) * 50.0)
	not_spirals["a ring"] = ring
	var loop_and_half := PackedVector2Array()
	for i in 49:
		loop_and_half.append(Vector2.from_angle(TAU * 1.5 * i / 48.0) * 60.0 * (1.0 - 0.6 * i / 48.0))
	not_spirals["a loop and a half"] = loop_and_half
	var two_rings := PackedVector2Array()
	for i in 65:
		two_rings.append(Vector2.from_angle(TAU * 2.0 * i / 64.0) * 50.0)
	not_spirals["two rings of one size"] = two_rings
	var ring_to_middle := ring.duplicate()
	for i in range(1, 9):
		ring_to_middle.append(ring[32].lerp(Vector2.ZERO, i / 8.0))
	not_spirals["a ring with a line to its middle"] = ring_to_middle
	for label: String in not_spirals:
		_checks += 1
		var drawn := PackedVector2Array()
		for p in _densify(not_spirals[label]):
			drawn.append(p + Vector2(0, -260))
		_cast = ""
		_caster.cast_stroke(SpellData.RIGHT | SpellData.MIDDLE, drawn)
		if _cast == "Black Hole":
			_failures += 1
			print("FAIL %s was read as a Black Hole" % label)
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

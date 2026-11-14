extends Node

## The mouse cursor is a wand (art/ui/wand_cursor.png). The tip is the point of the cursor. The wand is held by the wizard: its handle is toward
## the wizard and its tip points away, so it turns to follow the cursor all the way round them (cursor above their middle, the tip is up; below,
## the tip is down). Where there is no wizard, on the home screen or while the game is paused, it points up and to the left as an ordinary mouse cursor does. While a spell is
## being drawn, the jewel at the tip takes the colour of the school whose buttons are held. Only the wand's own pixels are used, turned in steps.
## Every turn of every colour is made once, ahead of time, into one sheet (TURNS, by tools/bake_wand_cursor.gd: a row for each set of buttons held, a
## column for each step), and cut from it here: made as they were wanted, each took about 70 ms and stalled the first seconds of the waiting room
## (owner, 2026-11-12). Without the sheet they are made as before.

const SCALE := 1.25            # each art pixel of the wand is drawn this many pixels across, so it is easy to see
const CANVAS := 160             # a square the wand can turn about its tip inside, in pixels
const TIP := Vector2(80, 80)    # where the tip sits in that square, and so the cursor's point
const SOURCE_TIP := Vector2(5.0, 0.5)  # the tip in the wand's own picture
const TIP_ROWS := 10            # the jewel is the top five art pixels, drawn twice as large
const STEPS := 24               # the turns it comes in, all the way round
const DEAD_ZONE := 24.0         # pixels from the wizard's middle inside which the wand keeps its angle
const FOLLOW := 20.0            # how quickly it turns to the cursor, a second
const POINTER := -45.0          # degrees: tip up and to the left, as a mouse cursor points
const TURNS := "res://art/ui/wand_turns.png"

var _plain: Image
var _sheet: Image      # every turn, made ahead of time (see TURNS), or null
var _held := 0         # every button held at any point since the last time none was
var _shown_mask := -1
var _shown_step := -1
var _cache := {}
var _angle := POINTER  # degrees, 0 is the tip straight up and a turn to the right is positive
var _target := POINTER


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # it must go on turning while a game alone is stopped, to go back to the pointer
	_plain = (load("res://art/ui/wand_cursor.png") as Texture2D).get_image()
	_plain.convert(Image.FORMAT_RGBA8)
	if ResourceLoader.exists(TURNS):
		_sheet = (load(TURNS) as Texture2D).get_image()
		if _sheet.is_compressed():
			_sheet.decompress()
		_sheet.convert(Image.FORMAT_RGBA8)
	_apply(0, _step_of(_angle))


func _process(delta: float) -> void:
	var now := 0
	if Input.is_action_pressed("school_left"):
		now |= SpellData.LEFT
	if Input.is_action_pressed("school_right"):
		now |= SpellData.RIGHT
	if Input.is_action_pressed("school_middle"):
		now |= SpellData.MIDDLE
	_held = 0 if now == 0 else (_held | now)
	var wizard := _player()
	var menu := get_tree().get_first_node_in_group(&"hud") as Hud
	if wizard == null or (menu != null and menu.is_paused()):  # the pause menu is the home screen's kind of place: an ordinary pointer
		_target = POINTER
	else:
		var middle: Vector2 = get_viewport().get_canvas_transform() * wizard.center()
		var away: Vector2 = get_viewport().get_mouse_position() - middle
		if away.length() > DEAD_ZONE:
			_target = rad_to_deg(atan2(away.x, -away.y))
	_angle = rad_to_deg(lerp_angle(deg_to_rad(_angle), deg_to_rad(_target), minf(delta * FOLLOW, 1.0)))
	var step := _step_of(_angle)
	if _held != _shown_mask or step != _shown_step:
		_apply(_held, step)


## The wand turned to a step, with its jewel in the colour of a set of buttons: what the sheet holds (see tools/bake_wand_cursor.gd).
func picture_of(mask: int, step: int) -> Image:
	return _outlined(_turned(_tinted(mask), float(step) * 360.0 / float(STEPS)))


## Sets the plain wand without the node being in a tree, for making the sheet.
func use_plain(picture: Image) -> void:
	_plain = picture
	_plain.convert(Image.FORMAT_RGBA8)


func _step_of(degrees: float) -> int:
	return posmod(roundi(degrees / (360.0 / float(STEPS))), STEPS)


func _apply(mask: int, step: int) -> void:
	_shown_mask = mask
	_shown_step = step
	var key := mask * 1000 + step
	if not _cache.has(key):
		var picture := _sheet.get_region(Rect2i(step * CANVAS, mask * CANVAS, CANVAS, CANVAS)) if _sheet != null else picture_of(mask, step)
		_cache[key] = ImageTexture.create_from_image(picture)
	Input.set_custom_mouse_cursor(_cache[key], Input.CURSOR_ARROW, TIP)


## The wand with its jewel recoloured: the jewel's own light-to-dark steps are kept, laid over the school's colour.
func _tinted(mask: int) -> Image:
	var image := _plain.duplicate() as Image
	for school: String in SpellData.SCHOOL_BUTTONS:
		if SpellData.SCHOOL_BUTTONS[school] != mask:
			continue
		var colour: Color = SpellData.SCHOOL_COLORS[school]
		for y in TIP_ROWS:
			for x in image.get_width():
				var pixel := image.get_pixel(x, y)
				if pixel.a > 0.0 and pixel.v > 0.3:
					image.set_pixel(x, y, colour.lightened(0.6) if pixel.v > 0.95 and pixel.s < 0.2 else colour.darkened(0.25) if pixel.h < 0.08 else colour)
	return image


## The wand turned about its tip by an angle, onto a square canvas, a pixel at a time (no smoothing, so it stays pixel art).
func _turned(wand: Image, degrees: float) -> Image:
	var out := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	var angle := deg_to_rad(degrees)
	var cosine := cos(angle)
	var sine := sin(angle)
	for y in CANVAS:
		for x in CANVAS:
			var from := Vector2(x + 0.5, y + 0.5) - TIP
			var back := Vector2(from.x * cosine + from.y * sine, -from.x * sine + from.y * cosine) / SCALE + SOURCE_TIP
			var sx := floori(back.x)
			var sy := floori(back.y)
			if sx >= 0 and sy >= 0 and sx < wand.get_width() and sy < wand.get_height():
				out.set_pixel(x, y, wand.get_pixel(sx, sy))
	return out


## The wand with a slight outline all round it: a dark line next to it, and a pale one outside that, so that it shows against any background, dark or light.
func _outlined(wand: Image) -> Image:
	var out := wand.duplicate() as Image
	var width := wand.get_width()
	var height := wand.get_height()
	for ring in 2:
		var source := out.duplicate() as Image
		var colour := Color(0.05, 0.03, 0.03, 0.95) if ring == 0 else Color(0.93, 0.9, 0.82, 0.7)
		for y in height:
			for x in width:
				if source.get_pixel(x, y).a > 0.0:
					continue
				for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + step.x
					var ny: int = y + step.y
					if nx >= 0 and ny >= 0 and nx < width and ny < height and source.get_pixel(nx, ny).a > 0.5 and (ring == 0 or source.get_pixel(nx, ny).r < 0.2):
						out.set_pixel(x, y, colour)
						break
	return out


## The wizard a person plays, if there is one.
func _player() -> Wizard:
	for node in get_tree().get_nodes_in_group("wizards"):
		if node is Wizard and node.brain == null and is_instance_valid(node):
			return node
	return null

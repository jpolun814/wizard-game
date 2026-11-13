class_name PagePickup
extends Node2D

## A page of the spellbook that floats and bobs a little above the floor, outlined in the glow of its school. Standing under it and pressing
## Tab reads it into the spellbook, and the page is gone; a page the book already has is not taken, but the book opens at it. Its origin is
## the floor beneath it.

const REACH_X := 36.0
const REACH_Y := 220.0
const FLOAT := 112.0  # how high it floats over the floor
const PAGE := preload("res://art/props/page.png")  # a page of the spellbook
const BOOK := preload("res://art/props/spellbook.png")  # the whole book, closed: what a fallen wizard leaves
const OUTLINE := preload("res://scripts/page_outline.gdshader")
const CHANT_COLOR := Color("#ffe9a0")
const CHIME_NEAR := 500.0  # a page chimes once when the wizard comes this close
const CHIME_FAR := 720.0   # and again only after they have gone this far from it

var page := ""
var spoils: Array[String] = []  # a dead wizard's whole book, lying together: reading it reads every page in it, and `page` is the first of them
var fan := false  # the pages in `spoils` lie fanned out like cards, not shut in a book: one read takes them all
var _t := 0.0
var _sprite: Sprite2D
var _hint: Label
var _color := CHANT_COLOR  # the outline
var _glow := CHANT_COLOR   # the light, in the school's own colour
var _chimed := false
var _cards: Array[Sprite2D] = []  # the pages of a fan


func _ready() -> void:
	add_to_group("pages")
	z_index = 3
	if SpellData.SPELLS.has(page) and (spoils.is_empty() or fan):
		_glow = SpellData.SCHOOL_COLORS[SpellData.SPELLS[page].school]
		_color = _glow.lightened(0.2)
	_t = randf() * TAU
	_sprite = Sprite2D.new()
	_sprite.texture = BOOK if not spoils.is_empty() and not fan else PAGE
	_sprite.material = _outlined(_color)
	add_child(_sprite)
	if fan:
		_fan_out()
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color("#ffe9a0"))
	_hint.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.08))
	_hint.add_theme_constant_override("outline_size", 5)
	_hint.position = Vector2(-90.0, -FLOAT - 70.0)
	_hint.size = Vector2(180.0, 20.0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.visible = false
	add_child(_hint)
	material = Fx.additive()  # the halo below adds light to what is behind it
	var light := PointLight2D.new()  # and lights the dark round it, in the school's colour
	light.texture = Fx.tex("light_01")
	light.texture_scale = 420.0 / Fx.TEX_SIZE
	light.color = _glow
	light.energy = 0.9
	light.position = Vector2(0, -FLOAT)
	add_child(light)
	var sparks := Fx.trail(_glow, 14, 1.4, 25.0, Vector2(0, -18), "star_04", 9.0)  # motes of its colour drifting up off it
	sparks.local_coords = true
	sparks.position = Vector2(0, -FLOAT)
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 22.0
	sparks.material = Fx.additive()
	add_child(sparks)
	sparks.emitting = true


## A material that outlines a page in a colour.
func _outlined(colour: Color) -> ShaderMaterial:
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	outline.set_shader_parameter("outline_color", colour)
	return outline


## The pages of a fan lie spread like a hand of cards, each leaning a little more than the one before and outlined in the colour of its own school.
## `_sprite` is only the holder that bobs and sways, with the cards hanging from it.
func _fan_out() -> void:
	_sprite.texture = null
	var count := spoils.size()
	var middle := float(count - 1) * 0.5
	for k in count:
		var lean := (float(k) - middle) * 0.24  # in radians, leaning left to right
		var card := Sprite2D.new()
		card.texture = PAGE
		card.rotation = lean
		card.position = Vector2(lean * 90.0, lean * lean * 70.0)  # the outer cards sit a little lower, as a hand of cards does
		card.z_index = k  # later cards over earlier ones
		var school_colour: Color = SpellData.SCHOOL_COLORS[SpellData.SPELLS[spoils[k]].school] if SpellData.SPELLS.has(spoils[k]) else CHANT_COLOR
		card.material = _outlined(school_colour.lightened(0.2))
		_sprite.add_child(card)
		_cards.append(card)


func _physics_process(delta: float) -> void:
	_t += delta
	_sprite.position = Vector2(0.0, -FLOAT + sin(_t * 2.0) * 6.0)
	_sprite.rotation = sin(_t * 1.3) * 0.06
	var strength := 0.75 + 0.25 * sin(_t * 3.0)
	if _cards.is_empty():
		(_sprite.material as ShaderMaterial).set_shader_parameter("strength", strength)
	else:
		for card in _cards:
			(card.material as ShaderMaterial).set_shader_parameter("strength", strength)
	_chime()
	var wizard := get_tree().get_first_node_in_group("player") as Node2D
	_hint.visible = is_underfoot()
	_hint.text = "Press Tab to read" if wizard == null or gives(wizard.ledger) else "Press Tab to read it again"
	queue_redraw()


## A soft chime as the wizard comes near, so a page is not walked past unheard.
func _chime() -> void:
	var wizard := get_tree().get_first_node_in_group("player") as Node2D
	if wizard == null or wizard.dead or wizard.ledger.knows(page):
		return
	var far := SpellTargets.center_of(wizard).distance_to(global_position + Vector2(0, -FLOAT))
	if not _chimed and far < CHIME_NEAR:
		_chimed = true
		Sfx.play("pickup", global_position + Vector2(0, -FLOAT), -12.0)
	elif _chimed and far > CHIME_FAR:
		_chimed = false


## True while the player's wizard stands under the page.
func is_underfoot() -> bool:
	var wizard := get_tree().get_first_node_in_group("player") as Node2D
	return wizard != null and not wizard.dead and is_under(wizard)


## True while this wizard stands under the page.
func is_under(wizard: Node2D) -> bool:
	var at := SpellTargets.center_of(wizard)
	return absf(at.x - global_position.x) < REACH_X and at.y > global_position.y - REACH_Y and at.y < global_position.y + 30.0


## The pages here that a ledger does not hold yet.
func new_pages(ledger: Ledger) -> Array[String]:
	var out: Array[String] = []
	for each: String in (spoils if not spoils.is_empty() else [page]):
		if not ledger.knows(each):
			out.append(each)
	return out


## True when there is something here for the ledger to read.
func gives(ledger: Ledger) -> bool:
	return not new_pages(ledger).is_empty()


## Reads the pages into a wizard's ledger and takes them off the ground, unless the book had them already. Returns the first page
## that was new, or this one when none was.
func take(ledger: Ledger) -> String:
	var fresh := new_pages(ledger)
	if not fresh.is_empty():
		var reader := get_tree().get_first_node_in_group("player") as Wizard
		for each in fresh:
			ledger.learn(each)
			if reader != null and reader.ledger == ledger:
				Library.record_page(each)  # a page the person at this machine found
		Fx.burst(get_parent(), global_position + Vector2(0, -FLOAT), _color, 14, 130.0, 0.5, true)
		queue_free()
		return fresh[0]
	return page


## The page the wizard stands under, or null. Where several lie within reach (a dropped book beside a page, a fan beside another) the one that gives them
## something comes first, a page that is really there before a mirage, so a page already read never stands between the wizard and a new one.
static func underfoot(tree: SceneTree) -> PagePickup:
	var wizard := tree.get_first_node_in_group("player") as Wizard
	var best: PagePickup = null
	var best_rank := -1
	for pickup: PagePickup in tree.get_nodes_in_group("pages"):
		if pickup.is_queued_for_deletion() or not pickup.is_underfoot():
			continue
		var rank := 0
		if wizard != null and pickup.gives(wizard.ledger):
			rank = 1 if pickup is Mirage else 2
		if rank > best_rank:
			best = pickup
			best_rank = rank
	return best


func _draw() -> void:
	Fx.draw_glow(self, Vector2(0, -FLOAT), 150.0 + sin(_t * 2.0) * 10.0, Color(_glow.r, _glow.g, _glow.b, 0.22))  # the light seen from afar
	Fx.draw_glow(self, Vector2(0, -FLOAT), 70.0 + sin(_t * 2.6) * 6.0, Color(_glow.r, _glow.g, _glow.b, 0.3))
	Fx.draw_glow(self, Vector2(0, -FLOAT), 34.0 + sin(_t * 3.0) * 3.0, Color(_glow.r, _glow.g, _glow.b, 0.5))

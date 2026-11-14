class_name InsightTip
extends RefCounted

## While Insight is on, hovering an enemy or a wizard shows its health, weaknesses and resistances in a small tooltip. Reached as `arena.insight`.

const REACH := 40.0  # how close the pointer must be to an enemy for Insight to show it
const HOODED_WIZARD := "Hooded Wizard"  # what Insight calls the wizard in the player's own look

var arena: Arena
var _tip: PanelContainer
var _text: RichTextLabel


func _init(owner_arena: Arena) -> void:
	arena = owner_arena


## The tooltip is a small panel on the screen's own layer.
func build(hud: Node) -> void:
	_tip = PanelContainer.new()
	_tip.visible = false
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.custom_minimum_size = Vector2(260, 0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(_text)
	hud.add_child(_tip)


## Whether the tooltip is showing, and what it says.
func shown() -> bool:
	return _tip.visible


func says() -> String:
	return _text.text


func update() -> void:
	var body: Node2D = _body_under_pointer() if arena.revealed["insight"] else null
	_tip.visible = body != null
	if body == null:
		return
	_text.text = _about_wizard(body) if body is Wizard else _about_creature(body)
	var screen := arena.get_viewport().get_visible_rect().size
	var tip_size := _tip.get_combined_minimum_size()
	_tip.position = (arena.get_viewport().get_mouse_position() + Vector2(18, 18)).min(screen - tip_size - Vector2(8, 8)).max(Vector2(8, 8))  # kept on the screen, even with a long list


## A rival wizard's stamina is shown nowhere else, and the spells it has pages for, each in the color of its school.
func _about_wizard(wizard: Wizard) -> String:
	var title := HOODED_WIZARD  # the hooded look has no MobKind: only a person wears it, and in a network game another may
	var desc: String = Mob.KINDS["dark_wizard"].desc
	if Mob.KINDS.has(wizard.look):
		title = Mob.KINDS[wizard.look].display_name
		desc = Mob.KINDS[wizard.look].desc
	var out := "[b]%s[/b]   Stamina %d / %d\n[i]%s[/i]" % [title, wizard.stamina, wizard.max_stamina, desc]
	var lines := ""
	for spell_name: String in SpellData.SPELLS:
		if wizard.ledger.knows_spell(spell_name):
			var color: Color = SpellData.SCHOOL_COLORS[SpellData.SPELLS[spell_name].school]
			lines += "\n[color=#%s]%s[/color]" % [color.lightened(0.15).to_html(false), spell_name]
	return out + "\n\nKnows:" + lines


func _about_creature(mob: Mob) -> String:
	var data: MobKind = Mob.KINDS[mob.kind]
	var weak := _school(data.weak) if data.weak != "" else "nothing"
	var resist := _school(data.resist) if data.resist != "" else "nothing"
	return "[b]%s[/b]   Stamina %d / %d\nWeak to %s\nResists %s\n[i]%s[/i]" % [data.display_name, mob.hp, mob.max_hp, weak, resist, data.desc]


## The enemy or the other wizard closest to the pointer, if it is within reach.
func _body_under_pointer() -> Node2D:
	var pointer := arena.get_global_mouse_position()
	var others := (arena.get_tree().get_nodes_in_group("mobs") + arena.get_tree().get_nodes_in_group("wizards")).filter(
		func(body: Node2D) -> bool: return body != arena.player and not (body is Wizard and body.is_unseen()))
	return SpellTargets.nearest_to(others, pointer, REACH)


func _school(school: String) -> String:
	return "[color=#%s]%s[/color]" % [SpellData.SCHOOL_COLORS[school].to_html(false), school]
